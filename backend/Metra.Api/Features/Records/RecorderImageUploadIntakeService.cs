namespace Metra.Api.Features.Records;

/// <summary>
/// Server-authenticated upload actor. Never bind this value from request JSON.
/// </summary>
public sealed record RecorderImageUploadActor(Guid SubjectId);

public sealed record RecorderImageUploadRequest(
    Guid CaptureId,
    Guid AssetId,
    string FileName,
    string DeclaredContentType,
    string ExpectedSha256,
    string CorrelationId);

public sealed record RecorderImageUploadResult(
    bool IsAccepted,
    string? ErrorCode,
    Guid? AssetId)
{
    public static RecorderImageUploadResult Rejected(string code) =>
        new(false, code, null);

    public static RecorderImageUploadResult Accepted(Guid assetId) =>
        new(true, null, assetId);
}

/// <summary>
/// Resolves capture, asset and station scope from trusted persisted data.
/// Implementations must not trust station or actor identifiers supplied by clients.
/// </summary>
public interface IRecorderImageUploadAuthorizer
{
    Task<bool> AuthorizeAsync(
        Guid actorSubjectId,
        Guid captureId,
        Guid assetId,
        CancellationToken cancellationToken);
}

public enum RecorderQuarantineCommitResult
{
    Committed,
    StateConflict,
    OutcomeUnknown
}

/// <summary>
/// Reads and conditionally changes asset lifecycle state. The conditional update
/// and append-only audit insert must be one datastore transaction. OutcomeUnknown
/// means the caller cannot prove whether the transaction committed; the object
/// must remain quarantined until reconciliation resolves the durable state.
/// </summary>
public interface IRecorderImageAssetIntakeStore
{
    Task<RecordImageAssetStatus?> GetStatusAsync(
        Guid assetId,
        CancellationToken cancellationToken);

    Task<RecorderQuarantineCommitResult> TryRecordQuarantinedAsync(
        Guid assetId,
        RecordImageAssetStatus expectedState,
        QuarantinedRecorderObject storedObject,
        RecorderSecurityAuditEvent auditEvent,
        CancellationToken cancellationToken);
}

/// <summary>
/// Orchestrates the pre-scan upload boundary without implementing infrastructure.
/// Authorization precedes asset-state lookup; untrusted bytes are bounded, validated,
/// and written only to private quarantine. This service never marks an asset accepted.
/// </summary>
public sealed class RecorderImageUploadIntakeService(
    IRecorderImageUploadAuthorizer authorizer,
    IRecorderImageAssetIntakeStore assetStore,
    IRecorderQuarantineStorage quarantineStorage)
{
    public async Task<RecorderImageUploadResult> UploadAsync(
        RecorderImageUploadActor? actor,
        RecorderImageUploadRequest? request,
        Stream? source,
        CancellationToken cancellationToken)
    {
        if (actor is null || actor.SubjectId == Guid.Empty)
            return RecorderImageUploadResult.Rejected("authenticated_actor_required");

        if (request is null ||
            request.CaptureId == Guid.Empty ||
            request.AssetId == Guid.Empty)
            return RecorderImageUploadResult.Rejected("upload_request_invalid");

        if (source is null)
            return RecorderImageUploadResult.Rejected("upload_stream_required");

        var auditEvent = new RecorderSecurityAuditEvent(
            actor.SubjectId,
            request.AssetId,
            request.CaptureId,
            null,
            request.CorrelationId,
            "quarantine_upload",
            "upload_received");

        if (!RecorderSecurityAuditEventPolicy.IsValid(auditEvent))
            return RecorderImageUploadResult.Rejected("upload_correlation_invalid");

        if (!await authorizer.AuthorizeAsync(
                actor.SubjectId, request.CaptureId, request.AssetId, cancellationToken))
            return RecorderImageUploadResult.Rejected("upload_not_authorized");

        var currentState = await assetStore.GetStatusAsync(
            request.AssetId, cancellationToken);

        if (currentState is null)
            return RecorderImageUploadResult.Rejected("asset_not_found");

        if (currentState != RecordImageAssetStatus.AwaitingUpload)
            return RecorderImageUploadResult.Rejected("asset_not_awaiting_upload");

        var bounded = await RecordImageBoundedStreamReader.ReadAsync(
            source, RecordImageUploadValidator.MaximumBytes, cancellationToken);

        if (!bounded.IsAccepted || bounded.Content is null)
            return RecorderImageUploadResult.Rejected(
                bounded.ErrorCode ?? "upload_stream_invalid");

        var validation = RecordImageUploadValidator.Validate(
            request.FileName,
            request.DeclaredContentType,
            bounded.Content,
            request.ExpectedSha256);

        if (!validation.IsValid || validation.Sha256 is null)
            return RecorderImageUploadResult.Rejected(
                validation.ErrorCode ?? "upload_validation_failed");

        var uploadAttemptId = Guid.NewGuid();
        await using var content = new MemoryStream(bounded.Content, writable: false);
        var storedObject = await quarantineStorage.WriteQuarantinedAsync(
            request.AssetId,
            uploadAttemptId,
            content,
            RecordImageUploadValidator.MaximumBytes,
            cancellationToken);

        var storageDecision = QuarantinedRecorderObjectPolicy.Evaluate(
            request.AssetId, uploadAttemptId, storedObject);

        if (!storageDecision.IsAccepted || storedObject is null ||
            storedObject.Length != bounded.Content.LongLength ||
            !string.Equals(storedObject.Sha256, validation.Sha256, StringComparison.Ordinal) ||
            !string.Equals(storedObject.DetectedMediaType, validation.DetectedContentType, StringComparison.Ordinal))
        {
            await quarantineStorage.DeleteQuarantinedAsync(
                request.AssetId, uploadAttemptId, cancellationToken);
            return RecorderImageUploadResult.Rejected(
                storageDecision.ErrorCode ?? "stored_object_integrity_mismatch");
        }

        var commitResult = await assetStore.TryRecordQuarantinedAsync(
            request.AssetId,
            RecordImageAssetStatus.AwaitingUpload,
            storedObject,
            auditEvent,
            cancellationToken);

        if (commitResult == RecorderQuarantineCommitResult.StateConflict)
        {
            // The provider has confirmed that no state/audit transaction committed.
            await quarantineStorage.DeleteQuarantinedAsync(
                request.AssetId, uploadAttemptId, cancellationToken);
            return RecorderImageUploadResult.Rejected("asset_state_conflict");
        }

        if (commitResult == RecorderQuarantineCommitResult.OutcomeUnknown)
        {
            // Never delete an object when a commit may have succeeded. Keep it private
            // and let a reconciler inspect the durable asset state before cleanup.
            return RecorderImageUploadResult.Rejected("upload_commit_outcome_unknown");
        }

        if (commitResult != RecorderQuarantineCommitResult.Committed)
            return RecorderImageUploadResult.Rejected("upload_commit_result_unknown");

        return RecorderImageUploadResult.Accepted(request.AssetId);
    }
}
