using System.Security.Cryptography;

namespace Metra.Api.Features.Records;

/// <summary>
/// Validates recorder scan bytes and integrity metadata before a storage adapter persists them.
/// This class performs no I/O and grants no access.
/// </summary>
public static class RecordImageUploadValidator
{
    public const int MaximumBytes = 20 * 1024 * 1024;

    private sealed record ImageFormat(string MediaType, byte[] Signature);

    private static readonly ImageFormat[] Formats =
    [
        new("image/jpeg", [0xFF, 0xD8, 0xFF]),
        new("image/png", [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        new("image/tiff", [0x49, 0x49, 0x2A, 0x00]),
        new("image/tiff", [0x4D, 0x4D, 0x00, 0x2A])
    ];

    public static RecordImageValidationResult Validate(
        string? fileName,
        string? declaredContentType,
        ReadOnlyMemory<byte> content,
        string? expectedSha256)
    {
        if (string.IsNullOrWhiteSpace(fileName) ||
            fileName.Length > 180 ||
            fileName.Contains('/') ||
            fileName.Contains('\\') ||
            fileName is "." or ".." ||
            !fileName.All(character =>
                character is >= 'a' and <= 'z' or
                    >= 'A' and <= 'Z' or
                    >= '0' and <= '9' or
                    '.' or '_' or '-'))
            return RecordImageValidationResult.Invalid("invalid_file_name");

        if (content.Length == 0)
            return RecordImageValidationResult.Invalid("empty_file");
        if (content.Length > MaximumBytes)
            return RecordImageValidationResult.Invalid("file_too_large");

        var format = Formats.FirstOrDefault(candidate => content.Span.StartsWith(candidate.Signature));
        if (format is null)
            return RecordImageValidationResult.Invalid("unsupported_or_invalid_image");

        if (!string.Equals(declaredContentType?.Trim(), format.MediaType, StringComparison.OrdinalIgnoreCase))
            return RecordImageValidationResult.Invalid("content_type_mismatch");

        var extension = Path.GetExtension(fileName);
        var extensionMatches = format.MediaType switch
        {
            "image/jpeg" => extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                            extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase),
            "image/png" => extension.Equals(".png", StringComparison.OrdinalIgnoreCase),
            "image/tiff" => extension.Equals(".tif", StringComparison.OrdinalIgnoreCase) ||
                            extension.Equals(".tiff", StringComparison.OrdinalIgnoreCase),
            _ => false
        };
        if (!extensionMatches)
            return RecordImageValidationResult.Invalid("file_extension_mismatch");

        if (string.IsNullOrWhiteSpace(expectedSha256) || expectedSha256.Length != 64)
            return RecordImageValidationResult.Invalid("sha256_required");

        byte[] expectedHash;
        try { expectedHash = Convert.FromHexString(expectedSha256); }
        catch (FormatException) { return RecordImageValidationResult.Invalid("invalid_sha256"); }

        var actualHash = SHA256.HashData(content.Span);
        if (!CryptographicOperations.FixedTimeEquals(actualHash, expectedHash))
            return RecordImageValidationResult.Invalid("sha256_mismatch");

        return new(true, null, format.MediaType, Convert.ToHexString(actualHash).ToLowerInvariant());
    }
}

public sealed record RecordImageValidationResult(
    bool IsValid,
    string? ErrorCode,
    string? DetectedContentType,
    string? Sha256)
{
    public static RecordImageValidationResult Invalid(string errorCode) =>
        new(false, errorCode, null, null);
}
