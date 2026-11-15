using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordDigitizationEnqueuePolicyTests
{
    private static RecordDigitizationEnqueueRequest ValidRequest() =>
        new(Guid.NewGuid(), Guid.NewGuid(), RecordImageAssetStatus.Accepted,
            true, "thermograph-v1", "metra:job-123456");

    [Fact]
    public void Allows_authorized_request_for_accepted_asset_with_valid_keys()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(ValidRequest());

        Assert.True(result.IsAllowed);
        Assert.Null(result.ErrorCode);
    }

    [Fact]
    public void Rejects_null_request() =>
        Assert.Equal("digitization_request_required",
            RecordDigitizationEnqueuePolicy.Evaluate(null).ErrorCode);

    [Fact]
    public void Denies_actor_without_digitization_permission()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with { ActorCanDigitize = false });

        Assert.False(result.IsAllowed);
        Assert.Equal("digitization_permission_denied", result.ErrorCode);
    }

    [Theory]
    [InlineData(RecordImageAssetStatus.AwaitingUpload)]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined)]
    [InlineData(RecordImageAssetStatus.Scanning)]
    [InlineData(RecordImageAssetStatus.Rejected)]
    [InlineData(RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.Cancelled)]
    public void Rejects_asset_that_is_not_accepted(RecordImageAssetStatus status)
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with { AssetStatus = status });

        Assert.Equal("asset_not_accepted", result.ErrorCode);
    }

    [Fact]
    public void Rejects_unknown_asset_state()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with { AssetStatus = (RecordImageAssetStatus)999 });

        Assert.Equal("asset_not_accepted", result.ErrorCode);
    }

    [Fact]
    public void Rejects_empty_capture_or_asset_identifiers()
    {
        Assert.Equal("digitization_resource_required",
            RecordDigitizationEnqueuePolicy.Evaluate(
                ValidRequest() with { CaptureId = Guid.Empty }).ErrorCode);

        Assert.Equal("digitization_resource_required",
            RecordDigitizationEnqueuePolicy.Evaluate(
                ValidRequest() with { AcceptedAssetId = Guid.Empty }).ErrorCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Thermograph-v1")]
    [InlineData("../unsafe")]
    [InlineData("profile with spaces")]
    [InlineData("profile\nforged")]
    public void Rejects_invalid_algorithm_profiles(string profile)
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with { AlgorithmProfile = profile });

        Assert.Equal("algorithm_profile_invalid", result.ErrorCode);
    }

    [Fact]
    public void Rejects_algorithm_profile_over_policy_limit()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with
            {
                AlgorithmProfile = "a" + new string('b', RecordDigitizationEnqueuePolicy.MaximumAlgorithmProfileLength)
            });

        Assert.Equal("algorithm_profile_invalid", result.ErrorCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("short")]
    [InlineData("contains spaces")]
    [InlineData("line\nbreak")]
    [InlineData("slash/value")]
    public void Rejects_invalid_idempotency_keys(string key)
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with { IdempotencyKey = key });

        Assert.Equal("idempotency_key_invalid", result.ErrorCode);
    }

    [Fact]
    public void Accepts_idempotency_key_at_maximum_length()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with
            {
                IdempotencyKey = new string('a', RecordDigitizationEnqueuePolicy.MaximumIdempotencyKeyLength)
            });

        Assert.True(result.IsAllowed);
    }

    [Fact]
    public void Rejects_idempotency_key_over_policy_limit()
    {
        var result = RecordDigitizationEnqueuePolicy.Evaluate(
            ValidRequest() with
            {
                IdempotencyKey = new string('a', RecordDigitizationEnqueuePolicy.MaximumIdempotencyKeyLength + 1)
            });

        Assert.Equal("idempotency_key_invalid", result.ErrorCode);
    }
}
