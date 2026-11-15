using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordDigitizationRequestFingerprintTests
{
    private static RecorderDigitizationSubmission Request(
        Guid? captureId = null,
        Guid? assetId = null,
        string profile = "standard-v1") => new(
            captureId ?? Guid.Parse("11111111-1111-1111-1111-111111111111"),
            assetId ?? Guid.Parse("22222222-2222-2222-2222-222222222222"),
            profile,
            "idem-key-0001");

    [Fact]
    public void Computes_stable_sha256_for_identical_payloads()
    {
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(Request(), out var first));
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(Request(), out var second));

        Assert.Equal(first, second);
        Assert.NotNull(first);
        Assert.Equal(64, first!.Length);
    }

    [Fact]
    public void Changes_fingerprint_when_capture_asset_or_profile_changes()
    {
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(Request(), out var baseline));
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(
            Request(captureId: Guid.NewGuid()), out var otherCapture));
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(
            Request(assetId: Guid.NewGuid()), out var otherAsset));
        Assert.True(RecordDigitizationRequestFingerprint.TryCompute(
            Request(profile: "standard-v2"), out var otherProfile));

        Assert.NotEqual(baseline, otherCapture);
        Assert.NotEqual(baseline, otherAsset);
        Assert.NotEqual(baseline, otherProfile);
    }

    [Fact]
    public void Rejects_missing_submission_or_empty_resource_ids()
    {
        Assert.False(RecordDigitizationRequestFingerprint.TryCompute(null, out _));
        Assert.False(RecordDigitizationRequestFingerprint.TryCompute(
            Request(captureId: Guid.Empty), out _));
        Assert.False(RecordDigitizationRequestFingerprint.TryCompute(
            Request(assetId: Guid.Empty), out _));
    }

    [Theory]
    [InlineData("")]
    [InlineData("Standard-V1")]
    [InlineData("profile with spaces")]
    [InlineData("profile\nforged")]
    [InlineData("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")]
    public void Rejects_invalid_algorithm_profile(string profile)
    {
        Assert.False(RecordDigitizationRequestFingerprint.TryCompute(
            Request(profile: profile), out _));
    }
}
