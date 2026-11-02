using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAccountLifecycleApplicationServiceTests
{
    [Fact]
    public async Task Commits_suspend_with_server_resolved_actor_and_reason()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 7));
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor("admin-1"), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Security review"));

        Assert.True(result.Succeeded);
        Assert.Equal(MetraAccountAccessState.Suspended, result.CurrentState);
        Assert.Equal("admin-1", store.ActorId);
        Assert.Equal(7, store.ExpectedVersion);
        Assert.Equal(MetraAccountAccessState.Active, store.ExpectedState);
        Assert.Equal(MetraAccountAccessState.Suspended, store.Transition?.To);
        Assert.Equal("Security review", store.Reason);
    }

    [Theory]
    [InlineData(MetraAccountLifecycleCommand.Suspend)]
    [InlineData(MetraAccountLifecycleCommand.Disable)]
    public async Task Requires_reason_for_restrictive_lifecycle_commands(MetraAccountLifecycleCommand command)
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(actor, store);

        var result = await service.ExecuteAsync(new("account-1", command, "  "));

        Assert.Equal("account_lifecycle_reason_required", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Allows_restore_without_inventing_or_requiring_reason()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Suspended, 2));
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Restore, null));

        Assert.True(result.Succeeded);
        Assert.Equal(MetraAccountAccessState.Active, store.Transition?.To);
        Assert.Equal(string.Empty, store.Reason);
    }

    [Fact]
    public async Task Rejects_invalid_account_identifier_before_actor_lookup()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(actor, store);

        var oversized = await service.ExecuteAsync(new(
            new string('a', 129), MetraAccountLifecycleCommand.Suspend, "Reason"));
        var control = await service.ExecuteAsync(new(
            "account-1\n", MetraAccountLifecycleCommand.Suspend, "Reason"));

        Assert.Equal("account_id_invalid", oversized.Code);
        Assert.Equal("account_id_invalid", control.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Fact]
    public async Task Rejects_control_characters_in_reason_before_actor_lookup()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(actor, store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Approved\nwithout review"));

        Assert.Equal("account_lifecycle_reason_invalid", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Rejects_malformed_actor_context()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor(" admin "), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Reason"));

        Assert.Equal("actor_context_invalid", result.Code);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Rejects_inconsistent_or_non_positive_store_snapshot()
    {
        var actor = new FakeActor("admin");
        var service = new MetraAccountLifecycleApplicationService(actor,
            new FakeStore(new("different-account", MetraAccountAccessState.Active, 1)));
        var mismatched = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Reason"));

        var invalidVersionService = new MetraAccountLifecycleApplicationService(
            new FakeActor("admin"),
            new FakeStore(new("account-1", MetraAccountAccessState.Active, 0)));
        var invalidVersion = await invalidVersionService.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Reason"));

        Assert.Equal("account_snapshot_invalid", mismatched.Code);
        Assert.Equal("account_snapshot_invalid", invalidVersion.Code);
    }

    [Fact]
    public async Task Does_not_lookup_account_without_authenticated_actor()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor(null), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Reason"));

        Assert.Equal("unauthenticated", result.Code);
        Assert.Equal(0, store.FindCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Returns_conflict_when_account_version_changed()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 5))
        {
            CommitResult = MetraAccountLifecycleCommitResult.Conflict
        };
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Suspend, "Reason"));

        Assert.Equal("account_lifecycle_conflict", result.Code);
        Assert.Equal(1, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_oversized_reason_before_actor_lookup()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccountLifecycleApplicationService(actor, store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Disable, new string('x', 2001)));

        Assert.Equal("account_lifecycle_reason_too_long", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Rejects_invalid_transition_without_committing()
    {
        var store = new FakeStore(new("account-1", MetraAccountAccessState.Disabled, 1));
        var service = new MetraAccountLifecycleApplicationService(
            new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(new(
            "account-1", MetraAccountLifecycleCommand.Restore, null));

        Assert.Equal("account_disabled_terminal", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    private sealed class FakeActor(string? actorId) : IAccountLifecycleActorContextProvider
    {
        public int Calls { get; private set; }
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(actorId);
        }
    }

    private sealed class FakeStore(MetraAccountLifecycleSnapshot? snapshot) : IAccountLifecycleStore
    {
        public int FindCalls { get; private set; }
        public int CommitCalls { get; private set; }
        public string? ActorId { get; private set; }
        public long ExpectedVersion { get; private set; }
        public MetraAccountAccessState? ExpectedState { get; private set; }
        public MetraAccountLifecycleTransition? Transition { get; private set; }
        public string? Reason { get; private set; }
        public MetraAccountLifecycleCommitResult CommitResult { get; set; }
            = MetraAccountLifecycleCommitResult.Committed;

        public Task<MetraAccountLifecycleSnapshot?> FindAccountAsync(
            string accountId, CancellationToken cancellationToken)
        {
            FindCalls++;
            return Task.FromResult(snapshot);
        }

        public Task<MetraAccountLifecycleCommitResult> TryCommitAsync(
            string accountId, long expectedVersion, MetraAccountAccessState expectedState,
            MetraAccountLifecycleTransition transition, string actorUserId, string reason,
            CancellationToken cancellationToken)
        {
            CommitCalls++;
            ExpectedVersion = expectedVersion;
            ExpectedState = expectedState;
            Transition = transition;
            ActorId = actorUserId;
            Reason = reason;
            return Task.FromResult(CommitResult);
        }
    }
}
