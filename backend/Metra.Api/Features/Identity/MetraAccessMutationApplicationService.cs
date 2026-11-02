using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

public enum MetraAccessMutationKind
{
    GrantPermission = 0,
    RevokePermission = 1,
    AssignStation = 2,
    RevokeStationAssignment = 3
}

public sealed record ChangeMetraAccessCommand(
    string AccountId,
    MetraAccessMutationKind Kind,
    string? RecordId,
    MetraPermissionGrant? PermissionGrant,
    MetraStationAssignment? StationAssignment,
    string? Reason);

public sealed record MetraAccessMutationSnapshot(
    string AccountId,
    MetraAccountAccessState AccountState,
    long Version);

public enum MetraAccessMutationCommitResult
{
    Committed = 0,
    NotFound = 1,
    Conflict = 2,
    TargetAccountNotActive = 3,
    StationNotActiveOrUnknown = 4,
    PermissionUnknownOrDisabled = 5,
    RecordNotFound = 6,
    AlreadyRevoked = 7,
    ActorNotAuthorized = 8
}

public sealed record MetraAccessMutationResult(bool Succeeded, string Code, string Message);

/// <summary>
/// The store is the security boundary: within one transaction it must reload
/// and lock actor/target/catalogue facts, require an active target for new
/// access but allow authorized revocation on inactive targets, authorize the
/// actor for this exact operation and scope, validate active station and
/// permission catalogue entries, compare the expected version, persist the
/// mutation and append an immutable audit event. Revocation preserves history.
/// </summary>
public interface IMetraAccessMutationStore
{
    Task<MetraAccessMutationSnapshot?> FindTargetAsync(
        string accountId, CancellationToken cancellationToken);

    Task<MetraAccessMutationCommitResult> TryCommitAsync(
        string accountId, long expectedVersion, string actorUserId,
        ChangeMetraAccessCommand command, CancellationToken cancellationToken);
}

/// <summary>
/// Coordinates station assignments and explicit permission grants. Actor
/// identity comes only from the authenticated server context.
/// </summary>
public sealed class MetraAccessMutationApplicationService(
    IAccountLifecycleActorContextProvider actorContextProvider,
    IMetraAccessMutationStore store)
{
    private const int MaximumReasonLength = 2000;

    public async Task<MetraAccessMutationResult> ExecuteAsync(
        ChangeMetraAccessCommand command,
        CancellationToken cancellationToken = default)
    {
        if (command is null || string.IsNullOrWhiteSpace(command.AccountId))
            return Failure("account_id_required");

        if (command.AccountId.Any(char.IsControl))
            return Failure("account_id_invalid");

        var accountId = command.AccountId.Trim();
        if (accountId.Length > 128)
            return Failure("account_id_invalid");
        if (!Enum.IsDefined(command.Kind))
            return Failure("access_mutation_kind_invalid");

        var reason = command.Reason?.Trim();
        if (string.IsNullOrWhiteSpace(reason))
            return Failure("access_mutation_reason_required");
        if (reason.Length > MaximumReasonLength)
            return Failure("access_mutation_reason_too_long");
        if (reason.Any(char.IsControl))
            return Failure("access_mutation_reason_invalid");

        var shapeError = ValidateCommandShape(command);
        if (shapeError is not null)
            return Failure(shapeError);

        var actorId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorId))
            return Failure("unauthenticated");
        if (actorId != actorId.Trim() || actorId.Length > 128 || actorId.Any(char.IsControl))
            return Failure("actor_context_invalid");

        var target = await store.FindTargetAsync(accountId, cancellationToken);
        if (target is null)
            return Failure("account_not_found");
        if (string.IsNullOrWhiteSpace(target.AccountId) ||
            target.AccountId != accountId || target.Version <= 0)
            return Failure("account_snapshot_invalid");
        var createsAccess = command.Kind is
            MetraAccessMutationKind.GrantPermission or MetraAccessMutationKind.AssignStation;
        if (createsAccess && target.AccountState != MetraAccountAccessState.Active)
            return Failure("target_account_not_active");

        var commit = await store.TryCommitAsync(
            target.AccountId, target.Version, actorId,
            command with { AccountId = target.AccountId, Reason = reason },
            cancellationToken);

        return commit switch
        {
            MetraAccessMutationCommitResult.Committed =>
                new(true, "access_mutation_committed", "تم تنفيذ تغيير الصلاحيات أو إسناد المحطة."),
            MetraAccessMutationCommitResult.NotFound => Failure("account_not_found"),
            MetraAccessMutationCommitResult.Conflict => Failure("access_mutation_conflict"),
            MetraAccessMutationCommitResult.TargetAccountNotActive => Failure("target_account_not_active"),
            MetraAccessMutationCommitResult.StationNotActiveOrUnknown => Failure("station_not_active_or_unknown"),
            MetraAccessMutationCommitResult.PermissionUnknownOrDisabled => Failure("permission_unknown_or_disabled"),
            MetraAccessMutationCommitResult.RecordNotFound => Failure("access_record_not_found"),
            MetraAccessMutationCommitResult.AlreadyRevoked => Failure("access_record_already_revoked"),
            MetraAccessMutationCommitResult.ActorNotAuthorized => Failure("actor_not_authorized"),
            _ => Failure("access_mutation_commit_failed")
        };
    }

    private static string? ValidateCommandShape(ChangeMetraAccessCommand command)
    {
        var hasGrant = command.PermissionGrant is not null;
        var hasAssignment = command.StationAssignment is not null;
        var hasRecordId = !string.IsNullOrWhiteSpace(command.RecordId);

        switch (command.Kind)
        {
            case MetraAccessMutationKind.GrantPermission:
                if (!hasGrant || hasAssignment || hasRecordId)
                    return "access_mutation_payload_invalid";
                var grant = MetraAccessRecordPolicy.ValidateGrant(command.PermissionGrant);
                return grant.IsValid ? null : grant.Code;

            case MetraAccessMutationKind.AssignStation:
                if (!hasAssignment || hasGrant || hasRecordId)
                    return "access_mutation_payload_invalid";
                var assignment = MetraAccessRecordPolicy.ValidateAssignment(command.StationAssignment);
                return assignment.IsValid ? null : assignment.Code;

            case MetraAccessMutationKind.RevokePermission:
            case MetraAccessMutationKind.RevokeStationAssignment:
                return hasRecordId && !hasGrant && !hasAssignment &&
                       command.RecordId!.Trim() == command.RecordId &&
                       command.RecordId.Length <= 128 &&
                       !command.RecordId.Any(char.IsControl)
                    ? null
                    : "access_mutation_payload_invalid";

            default:
                return "access_mutation_kind_invalid";
        }
    }

    private static MetraAccessMutationResult Failure(string code)
        => new(false, code, "تعذر تنفيذ تغيير الصلاحيات أو إسناد المحطة.");
}
