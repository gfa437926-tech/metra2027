namespace Metra.Api.Features.Records;

/// <summary>
/// Security lifecycle for uploaded recorder images. A quarantined asset must not
/// be served to users or downstream OCR/digitization workers before acceptance.
/// This type is a pure transition contract; it performs no storage or scanning.
/// </summary>
public enum RecordImageAssetStatus
{
    AwaitingUpload,
    UploadedQuarantined,
    Scanning,
    Accepted,
    Rejected,
    Expired,
    Cancelled
}

public static class RecordImageAssetState
{
    public static RecordImageAssetTransition Evaluate(
        RecordImageAssetStatus current,
        RecordImageAssetStatus requested)
    {
        if (!Enum.IsDefined(current) || !Enum.IsDefined(requested))
            return RecordImageAssetTransition.Rejected("unknown_asset_state");

        if (current == requested)
            return RecordImageAssetTransition.Rejected("asset_state_unchanged");

        var allowed = current switch
        {
            RecordImageAssetStatus.AwaitingUpload =>
                requested is RecordImageAssetStatus.UploadedQuarantined
                    or RecordImageAssetStatus.Expired
                    or RecordImageAssetStatus.Cancelled,
            RecordImageAssetStatus.UploadedQuarantined =>
                requested is RecordImageAssetStatus.Scanning
                    or RecordImageAssetStatus.Expired
                    or RecordImageAssetStatus.Cancelled,
            RecordImageAssetStatus.Scanning =>
                requested is RecordImageAssetStatus.Accepted
                    or RecordImageAssetStatus.Rejected,
            _ => false
        };

        return allowed
            ? RecordImageAssetTransition.Accepted(current, requested)
            : RecordImageAssetTransition.Rejected(
                IsTerminal(current) ? "terminal_asset_state" : "invalid_asset_state_transition");
    }

    public static bool IsTerminal(RecordImageAssetStatus status) =>
        status is RecordImageAssetStatus.Accepted
            or RecordImageAssetStatus.Rejected
            or RecordImageAssetStatus.Expired
            or RecordImageAssetStatus.Cancelled;
}

public sealed record RecordImageAssetTransition(
    bool IsAllowed,
    RecordImageAssetStatus? From,
    RecordImageAssetStatus? To,
    string? ErrorCode)
{
    public static RecordImageAssetTransition Accepted(
        RecordImageAssetStatus from,
        RecordImageAssetStatus to) => new(true, from, to, null);

    public static RecordImageAssetTransition Rejected(string errorCode) =>
        new(false, null, null, errorCode);
}
