using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Resolves the acting account from the authenticated server request.
/// Implementations must not accept actor IDs from command bodies or headers.
/// </summary>
public interface IAccountLifecycleActorContextProvider
{
    Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken);
}

public sealed record MetraAccountLifecycleSnapshot(
    string AccountId,
    MetraAccountAccessState State,
    long Version);

public enum MetraAccountLifecycleCommitResult
{
    Committed = 0,
    NotFound = 1,
    Conflict = 2
}

/// <summary>
/// The implementation must reload and lock target + actor authorization facts,
/// verify the required explicit permission, compare state and version, update
/// account state, and append a validated MetraAdministrativeAuditEvent in one
/// transaction. The event must be created from trusted transaction context and
/// pass MetraAdministrativeAuditEventPolicy. Restore must not modify grants
/// or station assignments.
/// </summary>
public interface IAccountLifecycleStore
{
    Task<MetraAccountLifecycleSnapshot?> FindAccountAsync(
        string accountId,
        CancellationToken cancellationToken);

    Task<MetraAccountLifecycleCommitResult> TryCommitAsync(
        string accountId,
        long expectedVersion,
        MetraAccountAccessState expectedState,
        MetraAccountLifecycleTransition transition,
        string actorUserId,
        string reason,
        CancellationToken cancellationToken);
}

public sealed record ChangeMetraAccountLifecycleCommand(
    string AccountId,
    MetraAccountLifecycleCommand Command,
    string? Reason);

public sealed record MetraAccountLifecycleApplicationResult(
    bool Succeeded,
    string Code,
    string Message,
    MetraAccountAccessState? CurrentState = null);

/// <summary>
/// Coordinates account lifecycle validation and transactional persistence.
/// Authorization is repeated by the store inside the commit transaction to
/// prevent time-of-check/time-of-use permission races.
/// </summary>
public sealed class MetraAccountLifecycleApplicationService(
    IAccountLifecycleActorContextProvider actorContextProvider,
    IAccountLifecycleStore store)
{
    private const int MaximumReasonLength = 2000;

    public async Task<MetraAccountLifecycleApplicationResult> ExecuteAsync(
        ChangeMetraAccountLifecycleCommand command,
        CancellationToken cancellationToken = default)
    {
        if (command is null || string.IsNullOrWhiteSpace(command.AccountId))
            return Failure("account_id_required");

        if (!Enum.IsDefined(command.Command))
            return Failure("account_lifecycle_command_invalid");

        var reason = command.Reason?.Trim();
        if (command.Command is MetraAccountLifecycleCommand.Suspend or MetraAccountLifecycleCommand.Disable &&
            string.IsNullOrWhiteSpace(reason))
            return Failure("account_lifecycle_reason_required");

        if (reason?.Length > MaximumReasonLength)
            return Failure("account_lifecycle_reason_too_long");

        var actorUserId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorUserId))
            return Failure("unauthenticated");

        var account = await store.FindAccountAsync(command.AccountId.Trim(), cancellationToken);
        if (account is null)
            return Failure("account_not_found");

        var transition = MetraAccountLifecyclePolicy.Apply(account.State, command.Command);
        if (!transition.Succeeded || transition.Transition is null)
            return Failure(transition.Code, account.State);

        var commit = await store.TryCommitAsync(
            account.AccountId,
            account.Version,
            account.State,
            transition.Transition,
            actorUserId,
            reason ?? string.Empty,
            cancellationToken);

        return commit switch
        {
            MetraAccountLifecycleCommitResult.Committed => new(
                true, "account_lifecycle_changed", "تم تحديث حالة الحساب.", transition.CurrentState),
            MetraAccountLifecycleCommitResult.NotFound => Failure("account_not_found"),
            MetraAccountLifecycleCommitResult.Conflict => Failure("account_lifecycle_conflict", account.State),
            _ => Failure("account_lifecycle_commit_failed", account.State)
        };
    }

    private static MetraAccountLifecycleApplicationResult Failure(
        string code,
        MetraAccountAccessState? state = null)
        => new(false, code, "تعذر تنفيذ تغيير حالة الحساب.", state);
}
