using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAccountLifecyclePolicyTests
{
    [Theory]
    [InlineData(MetraAccountAccessState.Active, MetraAccountLifecycleCommand.Suspend, MetraAccountAccessState.Suspended)]
    [InlineData(MetraAccountAccessState.Active, MetraAccountLifecycleCommand.Disable, MetraAccountAccessState.Disabled)]
    [InlineData(MetraAccountAccessState.Suspended, MetraAccountLifecycleCommand.Restore, MetraAccountAccessState.Active)]
    [InlineData(MetraAccountAccessState.Suspended, MetraAccountLifecycleCommand.Disable, MetraAccountAccessState.Disabled)]
    public void Allows_only_explicit_supported_transitions(
        MetraAccountAccessState from,
        MetraAccountLifecycleCommand command,
        MetraAccountAccessState expected)
    {
        var result = MetraAccountLifecyclePolicy.Apply(from, command);

        Assert.True(result.Succeeded);
        Assert.Equal(expected, result.CurrentState);
        Assert.Equal(from, result.Transition?.From);
        Assert.Equal(command, result.Transition?.Command);
        Assert.Equal(expected, result.Transition?.To);
    }

    [Theory]
    [InlineData(MetraAccountAccessState.PendingApproval, MetraAccountLifecycleCommand.Suspend)]
    [InlineData(MetraAccountAccessState.PendingApproval, MetraAccountLifecycleCommand.Restore)]
    [InlineData(MetraAccountAccessState.PendingApproval, MetraAccountLifecycleCommand.Disable)]
    [InlineData(MetraAccountAccessState.Active, MetraAccountLifecycleCommand.Restore)]
    [InlineData(MetraAccountAccessState.Suspended, MetraAccountLifecycleCommand.Suspend)]
    [InlineData(MetraAccountAccessState.Disabled, MetraAccountLifecycleCommand.Suspend)]
    [InlineData(MetraAccountAccessState.Disabled, MetraAccountLifecycleCommand.Restore)]
    [InlineData(MetraAccountAccessState.Disabled, MetraAccountLifecycleCommand.Disable)]
    public void Rejects_unsupported_or_repeated_transitions(
        MetraAccountAccessState from,
        MetraAccountLifecycleCommand command)
    {
        var result = MetraAccountLifecyclePolicy.Apply(from, command);

        Assert.False(result.Succeeded);
        Assert.Equal(from, result.CurrentState);
        Assert.Null(result.Transition);
    }

    [Fact]
    public void Rejects_unknown_account_state()
    {
        var result = MetraAccountLifecyclePolicy.Apply(
            (MetraAccountAccessState)999, MetraAccountLifecycleCommand.Suspend);

        Assert.False(result.Succeeded);
        Assert.Equal("account_state_invalid", result.Code);
    }

    [Fact]
    public void Rejects_unknown_command()
    {
        var result = MetraAccountLifecyclePolicy.Apply(
            MetraAccountAccessState.Active, (MetraAccountLifecycleCommand)999);

        Assert.False(result.Succeeded);
        Assert.Equal("account_lifecycle_command_invalid", result.Code);
    }

    [Fact]
    public void Disabled_state_is_terminal()
    {
        var result = MetraAccountLifecyclePolicy.Apply(
            MetraAccountAccessState.Disabled, MetraAccountLifecycleCommand.Restore);

        Assert.Equal("account_disabled_terminal", result.Code);
    }
}
