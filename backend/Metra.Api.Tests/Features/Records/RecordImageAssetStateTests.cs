using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordImageAssetStateTests
{
    [Theory]
    [InlineData(RecordImageAssetStatus.AwaitingUpload, RecordImageAssetStatus.UploadedQuarantined)]
    [InlineData(RecordImageAssetStatus.AwaitingUpload, RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.AwaitingUpload, RecordImageAssetStatus.Cancelled)]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined, RecordImageAssetStatus.Scanning)]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined, RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined, RecordImageAssetStatus.Cancelled)]
    [InlineData(RecordImageAssetStatus.Scanning, RecordImageAssetStatus.Accepted)]
    [InlineData(RecordImageAssetStatus.Scanning, RecordImageAssetStatus.Rejected)]
    public void Allows_only_documented_asset_transitions(
        RecordImageAssetStatus current,
        RecordImageAssetStatus requested)
    {
        var result = RecordImageAssetState.Evaluate(current, requested);

        Assert.True(result.IsAllowed);
        Assert.Equal(current, result.From);
        Assert.Equal(requested, result.To);
        Assert.Null(result.ErrorCode);
    }

    [Theory]
    [InlineData(RecordImageAssetStatus.AwaitingUpload, RecordImageAssetStatus.Scanning)]
    [InlineData(RecordImageAssetStatus.UploadedQuarantined, RecordImageAssetStatus.Accepted)]
    [InlineData(RecordImageAssetStatus.Scanning, RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.Accepted, RecordImageAssetStatus.Scanning)]
    [InlineData(RecordImageAssetStatus.Rejected, RecordImageAssetStatus.Accepted)]
    [InlineData(RecordImageAssetStatus.Expired, RecordImageAssetStatus.UploadedQuarantined)]
    [InlineData(RecordImageAssetStatus.Cancelled, RecordImageAssetStatus.Scanning)]
    public void Rejects_skipped_or_terminal_transitions(
        RecordImageAssetStatus current,
        RecordImageAssetStatus requested)
    {
        var result = RecordImageAssetState.Evaluate(current, requested);

        Assert.False(result.IsAllowed);
        Assert.Null(result.From);
        Assert.Null(result.To);
        Assert.NotNull(result.ErrorCode);
    }

    [Theory]
    [InlineData(RecordImageAssetStatus.Accepted)]
    [InlineData(RecordImageAssetStatus.Rejected)]
    [InlineData(RecordImageAssetStatus.Expired)]
    [InlineData(RecordImageAssetStatus.Cancelled)]
    public void Identifies_terminal_asset_states(RecordImageAssetStatus status) =>
        Assert.True(RecordImageAssetState.IsTerminal(status));

    [Fact]
    public void Rejects_same_state_and_undefined_values()
    {
        var same = RecordImageAssetState.Evaluate(
            RecordImageAssetStatus.Scanning, RecordImageAssetStatus.Scanning);
        var unknown = RecordImageAssetState.Evaluate(
            (RecordImageAssetStatus)999, RecordImageAssetStatus.Scanning);

        Assert.Equal("asset_state_unchanged", same.ErrorCode);
        Assert.Equal("unknown_asset_state", unknown.ErrorCode);
    }
}
