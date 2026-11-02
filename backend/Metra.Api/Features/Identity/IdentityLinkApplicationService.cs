namespace Metra.Api.Features.Identity;

/// <summary>
/// Trusted account context resolved by the server from the authenticated session.
/// Implementations must not accept account identifiers from request payloads.
/// </summary>
public sealed record IdentityLinkActorContext(
    string UserId,
    string IdentityToLinkIssuer,
    string IdentityToLinkSubject,
    DateTimeOffset SessionAuthenticatedAt,
    DateTimeOffset IdentityProofVerifiedAt,
    bool IsAccountActive);

public interface IIdentityLinkActorContextProvider
{
    Task<IdentityLinkActorContext?> GetCurrentAsync(CancellationToken cancellationToken);
}

public enum IdentityLinkCommitResult
{
    Linked = 0,
    AlreadyLinkedToSameAccount = 1,
    IdentityLinkedToDifferentAccount = 2,
    AccountUnavailable = 3,
    Conflict = 4
}

/// <summary>
/// Atomic persistence boundary. Implementations must enforce a database unique
/// constraint on the normalized (issuer, subject) pair and write the identity
/// link plus its audit event in the same transaction.
/// </summary>
public interface IIdentityLinkStore
{
    Task<IdentityLinkCommitResult> TryLinkAsync(
        string metraUserId,
        string issuer,
        string subject,
        DateTimeOffset linkedAt,
        string auditActorUserId,
        CancellationToken cancellationToken);
}

public sealed record IdentityLinkApplicationResult(
    bool Succeeded,
    string Code,
    string Message);

/// <summary>
/// Links a separately re-authenticated external identity to the METRA account
/// already resolved for the current session. The actor context provider must
/// verify proof-of-possession for the identity being linked and bind it to the
/// active account session. The caller cannot choose a target account.
/// </summary>
public sealed class IdentityLinkApplicationService(
    IIdentityLinkActorContextProvider actorContextProvider,
    IIdentityLinkStore store,
    TimeProvider timeProvider)
{
    private static readonly TimeSpan MaximumAuthenticationAge = TimeSpan.FromMinutes(5);

    public async Task<IdentityLinkApplicationResult> LinkCurrentIdentityAsync(
        CancellationToken cancellationToken = default)
    {
        var actor = await actorContextProvider.GetCurrentAsync(cancellationToken);
        if (actor is null ||
            string.IsNullOrWhiteSpace(actor.UserId) ||
            string.IsNullOrWhiteSpace(actor.IdentityToLinkIssuer) ||
            string.IsNullOrWhiteSpace(actor.IdentityToLinkSubject))
        {
            return Failure("unauthenticated", "يلزم وجود جلسة هوية موثّقة.");
        }

        if (!actor.IsAccountActive)
            return Failure("account_not_active", "لا يمكن ربط هوية بحساب METRA غير نشط.");

        if (!IsValidIdentityKey(actor.IdentityToLinkIssuer, actor.IdentityToLinkSubject))
            return Failure("invalid_identity", "بيانات الهوية الخارجية غير صالحة.");

        var now = timeProvider.GetUtcNow();
        var sessionAuthenticationAge = now - actor.SessionAuthenticatedAt;
        var identityProofAge = now - actor.IdentityProofVerifiedAt;
        if (!IsRecent(sessionAuthenticationAge) || !IsRecent(identityProofAge))
        {
            return Failure("recent_authentication_required",
                "يلزم إعادة التحقق من الهوية قبل ربط حساب خارجي.");
        }

        var commit = await store.TryLinkAsync(
            actor.UserId,
            actor.IdentityToLinkIssuer,
            actor.IdentityToLinkSubject,
            now,
            actor.UserId,
            cancellationToken);

        return commit switch
        {
            IdentityLinkCommitResult.Linked => new(
                true, "identity_linked", "تم ربط الهوية بالحساب."),
            IdentityLinkCommitResult.AlreadyLinkedToSameAccount => new(
                true, "identity_already_linked", "هذه الهوية مرتبطة بالحساب بالفعل."),
            IdentityLinkCommitResult.IdentityLinkedToDifferentAccount => Failure(
                "identity_already_in_use", "هذه الهوية مرتبطة بحساب METRA آخر."),
            IdentityLinkCommitResult.AccountUnavailable => Failure(
                "account_unavailable", "حساب METRA غير متاح لعملية الربط."),
            IdentityLinkCommitResult.Conflict => Failure(
                "identity_link_conflict", "تعذر إتمام الربط بسبب تعارض متزامن. أعد المحاولة."),
            _ => Failure("identity_link_failed", "تعذر إتمام عملية ربط الهوية.")
        };
    }

    private static bool IsRecent(TimeSpan age)
        => age >= TimeSpan.Zero && age <= MaximumAuthenticationAge;

    // OIDC issuer comparison is exact: do not lowercase, trim, or remove a
    // trailing slash. Subject is opaque and case-sensitive.
    private static bool IsValidIdentityKey(string issuer, string subject)
        => issuer.Length <= 512 &&
           Uri.TryCreate(issuer, UriKind.Absolute, out var issuerUri) &&
           issuerUri.Scheme == Uri.UriSchemeHttps &&
           string.IsNullOrEmpty(issuerUri.UserInfo) &&
           string.IsNullOrEmpty(issuerUri.Query) &&
           string.IsNullOrEmpty(issuerUri.Fragment) &&
           !issuer.Any(char.IsControl) &&
           subject.Length <= 255 &&
           !subject.Any(char.IsControl) &&
           !string.IsNullOrWhiteSpace(subject);

    private static IdentityLinkApplicationResult Failure(string code, string message)
        => new(false, code, message);
}
