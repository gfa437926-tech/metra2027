using System.Security.Cryptography;
using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordImageUploadValidatorTests
{
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01];

    private static RecordImageValidationResult Validate(
        byte[]? bytes = null,
        string fileName = "recorder.png",
        string contentType = "image/png",
        string? hash = null)
    {
        var content = bytes ?? Png;
        return RecordImageUploadValidator.Validate(
            fileName, contentType, content, hash ?? Convert.ToHexString(SHA256.HashData(content)));
    }

    [Fact]
    public void Accepts_png_with_matching_media_type_extension_and_digest()
    {
        var result = Validate();
        Assert.True(result.IsValid);
        Assert.Equal("image/png", result.DetectedContentType);
        Assert.Equal(Convert.ToHexString(SHA256.HashData(Png)).ToLowerInvariant(), result.Sha256);
    }

    [Theory]
    [InlineData("image/jpeg", "scan.jpg", new byte[] { 255, 216, 255, 0 })]
    [InlineData("image/png", "scan.png", new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 })]
    [InlineData("image/tiff", "scan.tif", new byte[] { 73, 73, 42, 0 })]
    [InlineData("image/tiff", "scan.tiff", new byte[] { 77, 77, 0, 42 })]
    public void Recognizes_supported_image_signatures(string mediaType, string name, byte[] bytes)
    {
        Assert.True(Validate(bytes, name, mediaType).IsValid);
    }

    [Theory]
    [InlineData("../scan.png")]
    [InlineData("..\\scan.png")]
    [InlineData("")]
    public void Rejects_path_like_or_empty_file_names(string name)
    {
        Assert.Equal("invalid_file_name", Validate(fileName: name).ErrorCode);
    }

    [Theory]
    [InlineData("scan\\nforged.png")]
    [InlineData("scan\tforged.png")]
    [InlineData("مسجل.png")]
    [InlineData("scan image.png")]
    public void Rejects_control_characters_unicode_and_ambiguous_file_names(string name)
    {
        Assert.Equal("invalid_file_name", Validate(fileName: name).ErrorCode);
    }

    [Fact]
    public void Rejects_declared_type_that_does_not_match_file_signature()
    {
        Assert.Equal("content_type_mismatch", Validate(contentType: "image/jpeg").ErrorCode);
    }

    [Fact]
    public void Rejects_extension_that_does_not_match_detected_format()
    {
        Assert.Equal("file_extension_mismatch", Validate(fileName: "scan.jpg").ErrorCode);
    }

    [Fact]
    public void Rejects_unknown_or_forged_file_signature()
    {
        Assert.Equal("unsupported_or_invalid_image", Validate([0x25, 0x50, 0x44, 0x46], "scan.png", "image/png").ErrorCode);
    }

    [Fact]
    public void Rejects_empty_and_oversized_content()
    {
        Assert.Equal("empty_file", Validate([]).ErrorCode);
        Assert.Equal("file_too_large", Validate(new byte[RecordImageUploadValidator.MaximumBytes + 1]).ErrorCode);
    }

    [Fact]
    public void Requires_a_valid_sha256_digest_and_rejects_tampering()
    {
        Assert.Equal("sha256_required", RecordImageUploadValidator.Validate("scan.png", "image/png", Png, null).ErrorCode);
        Assert.Equal("invalid_sha256", Validate(hash: new string('z', 64)).ErrorCode);
        Assert.Equal("sha256_mismatch", Validate(hash: new string('0', 64)).ErrorCode);
    }
}
