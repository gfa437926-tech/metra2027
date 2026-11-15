namespace Metra.Api.Features.Records;

/// <summary>
/// Authenticated identity supplied by the API boundary after token validation.
/// Never construct this value from request-body actor identifiers.
/// </summary>
public sealed record RecorderDigitizationActor(Guid SubjectId);

public sealed record RecorderDigitizationSubmission(
    Guid CaptureId,
    Guid AcceptedAssetId,
    string AlgorithmProfile,
    string IdempotencyKey);

public enum RecorderDigitizationOutboxWriteStatus
{
    Created,
    ExistingSameRequest,
    IdempotencyConflict
}

public sealed record RecorderDigitizationOutboxWriteResult(
    RecorderDigitizationOutboxWriteStatus Status,
    Guid? JobId);

public sealed record RecorderDigitizationSubmissionResult(
    bool IsAccepted,
    Guid? JobId,
    bool WasPreviouslySubmitted,
    string? ErrorCode)
{
    public static RecorderDigitizationSubmissionResult Rejected(string code) =>
        new(false, null, false, code);

    public static RecorderDigitizationSubmissionResult Accepted(Guid jobId, bool existing) =>
        new(true, jobId, existing, null);
}

/// <summary>
/// Must authorize the actor against both the capture's station scope and the
/// specific asset-to-capture relationship. Implementations must derive station
/// scope from trusted persisted records, never client-supplied station IDs.
/// </summary>
public interface IRecorderDigitizationSubmissionAuthorizer
{
    Task<bool> CanDigitizeCaptureAssetAsync(
        Guid actorSubjectId,
        Guid captureId,
        Guid assetId,
        CancellationToken cancellationToken);
}

/// <summary>
/// Reads authoritative asset lifecycle state after actor authorization.
/// </summary>
public interface IRecorderAssetStatusReader
{
    Task<RecordImageAssetStatus?> GetStatusAsync(
        Guid assetId,
        CancellationToken cancellationToken);
}

/// <summary>
/// Durable transactional outbox boundary. Implementations must atomically claim
/// (actor, idempotency key), compare the complete request fingerprint, and insert
/// the pending job/outbox message in one transaction. A dispatcher publishes
/// committed outbox rows later; do not enqueue directly to a remote broker here.
/// </summary>
public interface IRecorderDigitizationOutbox
{
    Task<RecorderDigitizationOutboxWriteResult> TryCreateAsync(
        Guid actorSubjectId,
        RecorderDigitizationSubmission submission,
        string requestFingerprint,
        CancellationToken cancellationToken);
}

/// <summary>
/// Orchestrates authorization, accepted-asset verification and durable,
/// idempotent outbox submission. It deliberately has no provider registration.
/// </summary>
public sealed class RecorderDigitizationSubmissionService(
    IRecorderDigitizationSubmissionAuthorizer authorizer,
    IRecorderAssetStatusReader assetStatusReader,
    IRecorderDigitizationOutbox outbox)
{
    public async Task<RecorderDigitizationSubmissionResult> SubmitAsync(
        RecorderDigitizationActor? actor,
        RecorderDigitizationSubmission? submission,
        CancellationToken cancellationToken)
    {
        if (actor is null || actor.SubjectId == Guid.Empty)
            return RecorderDigitizationSubmissionResult.Rejected("authenticated_actor_required");

        if (submission is null)
            return RecorderDigitizationSubmissionResult.Rejected("digitization_request_required");

        // Reject malformed identifiers before dependency calls. This is a shape
        // check only; no resource existence or lifecycle state is disclosed.
        if (submission.CaptureId == Guid.Empty || submission.AcceptedAssetId == Guid.Empty)
            return RecorderDigitizationSubmissionResult.Rejected("digitization_resource_required");

        // Authorization precedes resource-state reads to avoid disclosing whether
        // an unrelated capture or asset exists.
        var authorized = await authorizer.CanDigitizeCaptureAssetAsync(
            actor.SubjectId,
            submission.CaptureId,
            submission.AcceptedAssetId,
            cancellationToken);

        if (!authorized)
            return RecorderDigitizationSubmissionResult.Rejected("digitization_permission_denied");

        var status = await assetStatusReader.GetStatusAsync(
            submission.AcceptedAssetId,
            cancellationToken);

        if (status is null)
            return RecorderDigitizationSubmissionResult.Rejected("asset_not_found");

        var policy = RecordDigitizationEnqueuePolicy.Evaluate(
            new RecordDigitizationEnqueueRequest(
                submission.CaptureId,
                submission.AcceptedAssetId,
                status.Value,
                ActorCanDigitize: true,
                submission.AlgorithmProfile,
                submission.IdempotencyKey));

        if (!policy.IsAllowed)
            return RecorderDigitizationSubmissionResult.Rejected(policy.ErrorCode!);

        if (!RecordDigitizationRequestFingerprint.TryCompute(submission, out var requestFingerprint))
            return RecorderDigitizationSubmissionResult.Rejected("digitization_request_invalid");

        var write = await outbox.TryCreateAsync(
            actor.SubjectId,
            submission,
            requestFingerprint!,
            cancellationToken);

        return write.Status switch
        {
            RecorderDigitizationOutboxWriteStatus.Created when write.JobId is { } id && id != Guid.Empty =>
                RecorderDigitizationSubmissionResult.Accepted(id, existing: false),

            RecorderDigitizationOutboxWriteStatus.ExistingSameRequest when write.JobId is { } id && id != Guid.Empty =>
                RecorderDigitizationSubmissionResult.Accepted(id, existing: true),

            RecorderDigitizationOutboxWriteStatus.IdempotencyConflict =>
                RecorderDigitizationSubmissionResult.Rejected("idempotency_key_conflict"),

            _ => RecorderDigitizationSubmissionResult.Rejected("digitization_submission_unavailable")
        };
    }
}
