using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordDigitizationJobStateTests
{
    [Theory]
    [InlineData(RecordDigitizationJobStatus.Queued, RecordDigitizationJobStatus.Validating)]
    [InlineData(RecordDigitizationJobStatus.Queued, RecordDigitizationJobStatus.Cancelled)]
    [InlineData(RecordDigitizationJobStatus.Validating, RecordDigitizationJobStatus.Running)]
    [InlineData(RecordDigitizationJobStatus.Validating, RecordDigitizationJobStatus.Failed)]
    [InlineData(RecordDigitizationJobStatus.Validating, RecordDigitizationJobStatus.Cancelled)]
    [InlineData(RecordDigitizationJobStatus.Running, RecordDigitizationJobStatus.Succeeded)]
    [InlineData(RecordDigitizationJobStatus.Running, RecordDigitizationJobStatus.Failed)]
    [InlineData(RecordDigitizationJobStatus.Running, RecordDigitizationJobStatus.Cancelled)]
    public void Allows_only_documented_forward_transitions(
        RecordDigitizationJobStatus current,
        RecordDigitizationJobStatus requested)
    {
        var result = RecordDigitizationJobState.Evaluate(current, requested);

        Assert.True(result.IsAllowed);
        Assert.Equal(current, result.From);
        Assert.Equal(requested, result.To);
        Assert.Null(result.ErrorCode);
    }

    [Theory]
    [InlineData(RecordDigitizationJobStatus.Queued, RecordDigitizationJobStatus.Running)]
    [InlineData(RecordDigitizationJobStatus.Validating, RecordDigitizationJobStatus.Succeeded)]
    [InlineData(RecordDigitizationJobStatus.Succeeded, RecordDigitizationJobStatus.Running)]
    [InlineData(RecordDigitizationJobStatus.Failed, RecordDigitizationJobStatus.Queued)]
    [InlineData(RecordDigitizationJobStatus.Cancelled, RecordDigitizationJobStatus.Validating)]
    public void Rejects_skipped_or_terminal_state_transitions(
        RecordDigitizationJobStatus current,
        RecordDigitizationJobStatus requested)
    {
        var result = RecordDigitizationJobState.Evaluate(current, requested);

        Assert.False(result.IsAllowed);
        Assert.Null(result.From);
        Assert.Null(result.To);
        Assert.NotNull(result.ErrorCode);
    }

    [Theory]
    [InlineData(RecordDigitizationJobStatus.Succeeded)]
    [InlineData(RecordDigitizationJobStatus.Failed)]
    [InlineData(RecordDigitizationJobStatus.Cancelled)]
    public void Identifies_all_terminal_states(RecordDigitizationJobStatus status)
    {
        Assert.True(RecordDigitizationJobState.IsTerminal(status));
    }

    [Fact]
    public void Rejects_same_state_transition()
    {
        var result = RecordDigitizationJobState.Evaluate(
            RecordDigitizationJobStatus.Running,
            RecordDigitizationJobStatus.Running);

        Assert.False(result.IsAllowed);
        Assert.Equal("job_state_unchanged", result.ErrorCode);
    }

    [Fact]
    public void Rejects_undefined_enum_values()
    {
        var result = RecordDigitizationJobState.Evaluate(
            (RecordDigitizationJobStatus)999,
            RecordDigitizationJobStatus.Running);

        Assert.False(result.IsAllowed);
        Assert.Equal("unknown_job_state", result.ErrorCode);
    }
}
