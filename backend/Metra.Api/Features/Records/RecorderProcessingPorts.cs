namespace Metra.Api.Features.Records;

/// <summary>
/// Provider-neutral ports for the recorder intake pipeline. Implementations are
/// deliberately not registered until the storage, scanner, identity and schema
/// decisions are approved for a deployment environment.
/// </summary>
public enum RecordImageScanVerdict
{
    Clean,
    ThreatDetected,
    Indeterminate
}

public enum RecordImageAcceptanceAction
{
    Accept,
    Reject,
    KeepQuarantined
}

public sealed record RecordImageInspection(
    RecordImageScanVerdict Verdict,
    string ScannerName,
    string ScannerVersion,
    string? SafeReasonCode);

public sealed record RecordImageIntegrityEvidence(
    bool Sha256Verified,
    bool ContentSignatureVerified,
    bool DimensionsWithinPolicy,
    long ActualLength);

public sealed record RecordImageAcceptanceDecision(
    RecordImageAcceptanceAction Action,
    string ReasonCode);

/// <summary>
/// A fail-closed acceptance gate. Infrastructure uncertainty never grants access.
/// A clean verdict alone is insufficient without independent integrity evidence.
/// </summary>
public static class RecordImageAcceptancePolicy
{
    public static RecordImageAcceptanceDecision Evaluate(
        RecordImageAssetStatus currentState,
        RecordImageInspection? inspection,
        RecordImageIntegrityEvidence? integrity)
    {
        if (currentState != RecordImageAssetStatus.Scanning)
            return new(RecordImageAcceptanceAction.Reject, "asset_not_scanning");

        if (inspection is null || integrity is null)
            return new(RecordImageAcceptanceAction.KeepQuarantined, "inspection_evidence_missing");

        if (inspection.Verdict == RecordImageScanVerdict.Indeterminate)
            return new(RecordImageAcceptanceAction.KeepQuarantined, "scanner_result_indeterminate");

        if (inspection.Verdict == RecordImageScanVerdict.ThreatDetected)
            return new(RecordImageAcceptanceAction.Reject, "content_threat_detected");

        // Unknown enum values must never fall through as a clean verdict.
        if (inspection.Verdict != RecordImageScanVerdict.Clean)
            return new(RecordImageAcceptanceAction.KeepQuarantined, "scanner_result_unknown");

        if (!IsSafeScannerIdentity(inspection.ScannerName) ||
            !IsSafeScannerIdentity(inspection.ScannerVersion))
            return new(RecordImageAcceptanceAction.KeepQuarantined, "scanner_identity_missing");

        if (inspection.SafeReasonCode is not null &&
            !IsSafeScannerIdentity(inspection.SafeReasonCode))
            return new(RecordImageAcceptanceAction.KeepQuarantined, "scanner_reason_code_invalid");

        if (!integrity.Sha256Verified ||
            !integrity.ContentSignatureVerified ||
            !integrity.DimensionsWithinPolicy ||
            integrity.ActualLength <= 0 ||
            integrity.ActualLength > RecordImageUploadValidator.MaximumBytes)
            return new(RecordImageAcceptanceAction.Reject, "image_integrity_policy_failed");

        return new(RecordImageAcceptanceAction.Accept, "image_security_checks_passed");
    }

    private static bool IsSafeScannerIdentity(string? value) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.Length <= 100 &&
        value.All(character =>
            character is >= 'a' and <= 'z' or
                >= 'A' and <= 'Z' or
                >= '0' and <= '9' or
                '.' or '_' or ':' or '-');
}

/// <summary>
/// Private quarantine storage port. Implementations must not expose public URLs,
/// must isolate untrusted bytes, and must authorize every read/promotion.
/// </summary>
public interface IRecorderQuarantineStorage
{
    Task<QuarantinedRecorderObject> WriteQuarantinedAsync(
        Guid assetId,
        Guid uploadAttemptId,
        Stream content,
        long maximumBytes,
        CancellationToken cancellationToken);

    Task<Stream> OpenQuarantinedReadAsync(
        Guid assetId,
        Guid uploadAttemptId,
        CancellationToken cancellationToken);

    Task PromoteAcceptedAsync(
        Guid assetId,
        Guid uploadAttemptId,
        string verifiedSha256,
        CancellationToken cancellationToken);

    Task DeleteQuarantinedAsync(
        Guid assetId,
        Guid uploadAttemptId,
        CancellationToken cancellationToken);

    Task DeleteExpiredQuarantineAsync(
        Guid assetId,
        CancellationToken cancellationToken);
}

public sealed record QuarantinedRecorderObject(
    Guid AssetId,
    Guid UploadAttemptId,
    long Length,
    string Sha256,
    string DetectedMediaType);

/// <summary>
/// Scanner port. A timeout, unavailable scanner or unsupported file must map to
/// Indeterminate, never Clean. The caller owns disposal of the supplied stream.
/// </summary>
public interface IRecorderContentScanner
{
    Task<RecordImageInspection> InspectAsync(
        Stream content,
        string detectedMediaType,
        CancellationToken cancellationToken);
}

/// <summary>
/// Asynchronous worker queue port. Enqueue only after the asset has been accepted
/// and the caller has been authorized for recorder.digitize.
/// </summary>
public interface IRecorderDigitizationQueue
{
    Task<Guid> EnqueueAsync(
        Guid captureId,
        Guid acceptedAssetId,
        string algorithmProfile,
        string idempotencyKey,
        CancellationToken cancellationToken);
}

/// <summary>
/// Immutable audit facts for a security-sensitive recorder operation.
/// Actor identity is sourced from validated server authentication context;
/// correlation identifiers are generated or validated at the API boundary.
/// The event intentionally excludes image bytes, secrets and free-form user text.
/// </summary>
public sealed record RecorderSecurityAuditEvent(
    Guid ActorSubjectId,
    Guid AssetId,
    Guid? CaptureId,
    Guid? JobId,
    string CorrelationId,
    string Transition,
    string ReasonCode);

/// <summary>
/// Shared fail-closed shape validation for recorder audit events. Persistence
/// adapters should call this before writing and enforce equivalent database bounds.
/// </summary>
public static class RecorderSecurityAuditEventPolicy
{
    public static bool IsValid(RecorderSecurityAuditEvent? auditEvent)
    {
        if (auditEvent is null ||
            auditEvent.ActorSubjectId == Guid.Empty ||
            auditEvent.AssetId == Guid.Empty ||
            auditEvent.CaptureId == Guid.Empty ||
            auditEvent.JobId == Guid.Empty)
            return false;

        return IsSafeToken(auditEvent.CorrelationId, 128) &&
            IsSafeToken(auditEvent.Transition, 64) &&
            IsSafeToken(auditEvent.ReasonCode, 64);
    }

    private static bool IsSafeToken(string? value, int maximumLength) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.Length <= maximumLength &&
        value.All(character =>
            character is >= 'a' and <= 'z' or
                >= 'A' and <= 'Z' or
                >= '0' and <= '9' or
                '.' or '_' or ':' or '-');
}

/// <summary>
/// Append-only audit port for security-sensitive recorder transitions.
/// Implementations must persist actor, resource, operation and correlation context
/// atomically with the associated state transition where applicable. They must
/// reject empty actor/resource IDs and unbounded or control-character metadata.
/// Audit records must not be updateable through application-facing APIs.
/// </summary>
public interface IRecorderSecurityAuditWriter
{
    Task WriteAsync(
        RecorderSecurityAuditEvent auditEvent,
        CancellationToken cancellationToken);
}
