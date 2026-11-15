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

        if (string.IsNullOrWhiteSpace(inspection.ScannerName) ||
            string.IsNullOrWhiteSpace(inspection.ScannerVersion))
            return new(RecordImageAcceptanceAction.KeepQuarantined, "scanner_identity_missing");

        if (!integrity.Sha256Verified ||
            !integrity.ContentSignatureVerified ||
            !integrity.DimensionsWithinPolicy ||
            integrity.ActualLength <= 0)
            return new(RecordImageAcceptanceAction.Reject, "image_integrity_policy_failed");

        return new(RecordImageAcceptanceAction.Accept, "image_security_checks_passed");
    }
}

/// <summary>
/// Private quarantine storage port. Implementations must not expose public URLs,
/// must isolate untrusted bytes, and must authorize every read/promotion.
/// </summary>
public interface IRecorderQuarantineStorage
{
    Task<QuarantinedRecorderObject> WriteQuarantinedAsync(
        Guid assetId,
        Stream content,
        long maximumBytes,
        CancellationToken cancellationToken);

    Task<Stream> OpenQuarantinedReadAsync(
        Guid assetId,
        CancellationToken cancellationToken);

    Task PromoteAcceptedAsync(
        Guid assetId,
        string verifiedSha256,
        CancellationToken cancellationToken);

    Task DeleteExpiredQuarantineAsync(
        Guid assetId,
        CancellationToken cancellationToken);
}

public sealed record QuarantinedRecorderObject(
    Guid AssetId,
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
/// Append-only audit port for security-sensitive recorder transitions.
/// The actor and authority must be derived from validated server identity/context.
/// </summary>
public interface IRecorderSecurityAuditWriter
{
    Task WriteTransitionAsync(
        Guid assetId,
        string transition,
        string reasonCode,
        CancellationToken cancellationToken);
}
