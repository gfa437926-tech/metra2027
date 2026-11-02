using Metra.Api.Security;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Canonical METRA account lifecycle. Unknown provider claims must never be
/// mapped to Active; account state is loaded from METRA's authoritative store.
/// </summary>
public enum MetraAccountState
{
    PendingStationApproval = 0,
    PendingSystemApproval = 1,
    Active = 2,
    Suspended = 3,
    Rejected = 4
}

/// <summary>
/// One consistent, authoritative snapshot resolved from a validated external
/// identity subject. The provider subject is a lookup key, not a METRA user ID.
/// </summary>
public sealed record CurrentUserAccountFacts(
    string UserId,
    MetraAccountState AccountState,
    CurrentUserProfileFacts Profile,
    IReadOnlyList<CurrentUserStationAssignmentFacts> Assignments,
    IReadOnlyList<CurrentUserPermissionGrantFacts> PermissionGrants);

public sealed record CurrentUserProfileFacts(
    string FirstName,
    string? FatherName,
    string LastName,
    string? Email,
    string? Phone);

public sealed record CurrentUserStationAssignmentFacts(
    string StationId,
    string StationName,
    string RoleCode,
    DateTimeOffset ValidFrom,
    DateTimeOffset? ValidTo,
    DateTimeOffset? RevokedAt);

public sealed record CurrentUserPermissionGrantFacts(
    string Permission,
    DateTimeOffset ValidFrom,
    DateTimeOffset? ValidTo,
    DateTimeOffset? RevokedAt);

/// <summary>
/// Implementations must resolve the exact issuer+subject pair to one METRA
/// account and return account, assignments and grants from one consistent
/// database snapshot. Do not key by email or accept a METRA user ID from a client.
/// </summary>
public interface ICurrentUserContextDataSource
{
    Task<CurrentUserAccountFacts?> FindByIdentitySubjectAsync(
        string issuer,
        string subject,
        CancellationToken cancellationToken);
}

/// <summary>
/// Provider-neutral application service. The HTTP layer may call this only with
/// issuer and subject from a cryptographically validated server principal.
/// </summary>
public sealed class CurrentUserContextApplicationService(
    ICurrentUserContextDataSource dataSource,
    TimeProvider timeProvider)
{
    public async Task<CurrentUserContextResponse?> GetAsync(
        string issuer,
        string subject,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(subject))
            return null;

        var facts = await dataSource.FindByIdentitySubjectAsync(
            issuer, subject, cancellationToken);

        if (facts is null || string.IsNullOrWhiteSpace(facts.UserId))
            return null;

        var now = timeProvider.GetUtcNow();
        var activeAccount = facts.AccountState == MetraAccountState.Active;

        var assignments = activeAccount
            ? facts.Assignments
                .Where(x => IsEffective(x.ValidFrom, x.ValidTo, x.RevokedAt, now))
                .Select(x => new CurrentUserStationAssignmentResponse(
                    x.StationId,
                    x.StationName,
                    x.RoleCode,
                    x.ValidFrom,
                    x.ValidTo,
                    true))
                .ToArray()
            : [];

        var permissions = activeAccount
            ? facts.PermissionGrants
                .Where(x => MetraPermissions.All.Contains(x.Permission, StringComparer.Ordinal))
                .Where(x => IsEffective(x.ValidFrom, x.ValidTo, x.RevokedAt, now))
                .Select(x => x.Permission)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.Ordinal)
                .Order(StringComparer.Ordinal)
                .ToArray()
            : [];

        return new CurrentUserContextResponse(
            facts.UserId,
            new CurrentUserProfileResponse(
                facts.Profile.FirstName,
                facts.Profile.FatherName,
                facts.Profile.LastName,
                facts.Profile.Email,
                facts.Profile.Phone),
            facts.AccountState.ToString(),
            assignments,
            permissions);
    }

    private static bool IsEffective(
        DateTimeOffset validFrom,
        DateTimeOffset? validTo,
        DateTimeOffset? revokedAt,
        DateTimeOffset now)
        => validFrom <= now &&
           (validTo is null || now < validTo.Value) &&
           (revokedAt is null || now < revokedAt.Value);
}
