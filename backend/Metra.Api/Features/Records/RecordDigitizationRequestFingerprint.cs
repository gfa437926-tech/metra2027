using System.Security.Cryptography;
using System.Text;

namespace Metra.Api.Features.Records;

/// <summary>
/// Produces a stable payload fingerprint for transactional idempotency claims.
/// The idempotency key and actor are deliberately excluded: they scope the claim,
/// while this digest detects reuse of that key for a different request payload.
/// </summary>
public static class RecordDigitizationRequestFingerprint
{
    public static bool TryCompute(
        RecorderDigitizationSubmission? submission,
        out string? fingerprint)
    {
        fingerprint = null;

        if (submission is null ||
            submission.CaptureId == Guid.Empty ||
            submission.AcceptedAssetId == Guid.Empty ||
            !IsSafeAlgorithmProfile(submission.AlgorithmProfile))
            return false;

        // Canonical fields are newline-delimited; the profile grammar excludes
        // separators and control characters, so this representation is unambiguous.
        var canonical = string.Concat(
            submission.CaptureId.ToString("N"), "\n",
            submission.AcceptedAssetId.ToString("N"), "\n",
            submission.AlgorithmProfile);

        fingerprint = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
        return true;
    }

    private static bool IsSafeAlgorithmProfile(string? value) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.Length <= RecordDigitizationEnqueuePolicy.MaximumAlgorithmProfileLength &&
        (value[0] is >= 'a' and <= 'z' or >= '0' and <= '9') &&
        value.All(character =>
            character is >= 'a' and <= 'z' or
                >= '0' and <= '9' or
                '.' or '_' or '-');
}
