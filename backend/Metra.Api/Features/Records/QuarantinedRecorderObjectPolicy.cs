namespace Metra.Api.Features.Records;

/// <summary>
/// Validates the metadata returned by a quarantine-storage adapter before the
/// application records the object as a usable quarantined asset. Adapter output
/// is treated as untrusted until it passes this boundary.
/// </summary>
public static class QuarantinedRecorderObjectPolicy
{
    private static readonly HashSet<string> AllowedMediaTypes =
        new(StringComparer.Ordinal)
        {
            "image/jpeg",
            "image/png",
            "image/tiff"
        };

    public static QuarantinedRecorderObjectDecision Evaluate(
        Guid expectedAssetId,
        QuarantinedRecorderObject? storedObject)
    {
        if (expectedAssetId == Guid.Empty)
            return QuarantinedRecorderObjectDecision.Reject("asset_id_required");

        if (storedObject is null)
            return QuarantinedRecorderObjectDecision.Reject("storage_result_missing");

        if (storedObject.AssetId != expectedAssetId || storedObject.AssetId == Guid.Empty)
            return QuarantinedRecorderObjectDecision.Reject("storage_asset_id_mismatch");

        if (storedObject.Length <= 0 ||
            storedObject.Length > RecordImageUploadValidator.MaximumBytes)
            return QuarantinedRecorderObjectDecision.Reject("stored_object_length_invalid");

        if (!IsCanonicalSha256(storedObject.Sha256))
            return QuarantinedRecorderObjectDecision.Reject("stored_object_sha256_invalid");

        if (!AllowedMediaTypes.Contains(storedObject.DetectedMediaType))
            return QuarantinedRecorderObjectDecision.Reject("stored_object_media_type_invalid");

        return new(true, null);
    }

    private static bool IsCanonicalSha256(string? value) =>
        value is { Length: 64 } &&
        value.All(character =>
            character is >= '0' and <= '9' or
                >= 'a' and <= 'f');
}

public sealed record QuarantinedRecorderObjectDecision(
    bool IsAccepted,
    string? ErrorCode)
{
    public static QuarantinedRecorderObjectDecision Reject(string errorCode) =>
        new(false, errorCode);
}
