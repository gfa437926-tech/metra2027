using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class QuarantinedRecorderObjectPolicyTests
{
    private static readonly Guid AssetId =
        Guid.Parse("1d17d0d8-7d7a-4a1d-a2c3-4f2d6e9b8c10");

    private static QuarantinedRecorderObject ValidObject(string mediaType = "image/jpeg") =>
        new(AssetId, 1024, new string('a', 64), mediaType);

    [Fact]
    public void Accepts_matching_bounded_object_with_canonical_metadata()
    {
        var result = QuarantinedRecorderObjectPolicy.Evaluate(AssetId, ValidObject());

        Assert.True(result.IsAccepted);
        Assert.Null(result.ErrorCode);
    }

    [Fact]
    public void Rejects_missing_or_empty_expected_asset_identifier()
    {
        Assert.Equal("asset_id_required",
            QuarantinedRecorderObjectPolicy.Evaluate(Guid.Empty, ValidObject()).ErrorCode);
        Assert.Equal("storage_result_missing",
            QuarantinedRecorderObjectPolicy.Evaluate(AssetId, null).ErrorCode);
    }

    [Fact]
    public void Rejects_storage_result_for_a_different_asset()
    {
        var result = ValidObject() with { AssetId = Guid.NewGuid() };

        Assert.Equal("storage_asset_id_mismatch",
            QuarantinedRecorderObjectPolicy.Evaluate(AssetId, result).ErrorCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(20971521)]
    public void Rejects_non_positive_or_oversized_stored_objects(long length)
    {
        var result = ValidObject() with { Length = length };

        Assert.Equal("stored_object_length_invalid",
            QuarantinedRecorderObjectPolicy.Evaluate(AssetId, result).ErrorCode);
    }

    [Fact]
    public void Accepts_object_at_the_maximum_configured_size()
    {
        var result = ValidObject() with
        {
            Length = RecordImageUploadValidator.MaximumBytes
        };

        Assert.True(QuarantinedRecorderObjectPolicy.Evaluate(AssetId, result).IsAccepted);
    }

    [Theory]
    [InlineData("")]
    [InlineData("ABCDEFabcdefABCDEFabcdefABCDEFabcdefABCDEFabcdefABCDEFabcdefABCD")]
    [InlineData("gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg")]
    [InlineData("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")]
    public void Rejects_noncanonical_sha256(string sha256)
    {
        var result = ValidObject() with { Sha256 = sha256 };

        Assert.Equal("stored_object_sha256_invalid",
            QuarantinedRecorderObjectPolicy.Evaluate(AssetId, result).ErrorCode);
    }

    [Theory]
    [InlineData("image/gif")]
    [InlineData("application/octet-stream")]
    [InlineData("IMAGE/JPEG")]
    [InlineData("image/jpeg; charset=binary")]
    public void Rejects_unsupported_or_noncanonical_detected_media_types(string mediaType)
    {
        var result = ValidObject(mediaType);

        Assert.Equal("stored_object_media_type_invalid",
            QuarantinedRecorderObjectPolicy.Evaluate(AssetId, result).ErrorCode);
    }

    [Theory]
    [InlineData("image/jpeg")]
    [InlineData("image/png")]
    [InlineData("image/tiff")]
    public void Accepts_supported_detected_image_media_types(string mediaType)
    {
        Assert.True(QuarantinedRecorderObjectPolicy.Evaluate(
            AssetId, ValidObject(mediaType)).IsAccepted);
    }
}
