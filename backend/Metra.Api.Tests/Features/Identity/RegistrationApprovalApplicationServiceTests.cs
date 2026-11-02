using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class RegistrationApprovalApplicationServiceTests
{
    [Fact]
    public async Task Persists_station_approval_with_server_resolved_actor()
    {
        var actor = new RegistrationApprovalActorContext(
            "station-manager", true, true, new HashSet<string> { "station-1" }, false);
        var request = Request();
        var store = new FakeStore(request);
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            request.RequestId, RegistrationApprovalDecision.Approve, "Reviewed"));

        Assert.True(result.Succeeded);
        Assert.Equal("decision_recorded", result.Code);
        Assert.Equal(RegistrationApprovalStatus.PendingSystemApproval, result.CurrentStatus);
        Assert.Equal("station-manager", store.ActorUserId);
        Assert.Equal(RegistrationApprovalStatus.PendingStationApproval, store.ExpectedStatus);
        Assert.Equal(RegistrationApprovalStatus.PendingSystemApproval, store.Transition?.To);
        Assert.Equal("Reviewed", store.Note);
    }

    [Fact]
    public async Task Does_not_persist_when_actor_lacks_station_scope()
    {
        var actor = new RegistrationApprovalActorContext(
            "manager", true, true, new HashSet<string> { "station-2" }, false);
        var store = new FakeStore(Request());
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.False(result.Succeeded);
        Assert.Equal("station_scope_violation", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Does_not_persist_when_actor_is_missing()
    {
        var store = new FakeStore(Request());
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(null), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.Equal("unauthenticated", result.Code);
        Assert.Equal(0, store.FindCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Returns_conflict_when_request_changed_concurrently()
    {
        var actor = new RegistrationApprovalActorContext(
            "manager", true, true, new HashSet<string> { "station-1" }, false);
        var store = new FakeStore(Request())
        {
            CommitResult = RegistrationApprovalCommitResult.Conflict
        };
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.False(result.Succeeded);
        Assert.Equal("approval_state_conflict", result.Code);
        Assert.Equal(1, store.CommitCalls);
    }

    [Fact]
    public async Task Requires_explicit_system_permission_for_final_decision()
    {
        var actor = new RegistrationApprovalActorContext(
            "system-manager", true, false, new HashSet<string>(), false);
        var store = new FakeStore(Request(
            status: RegistrationApprovalStatus.PendingSystemApproval));
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.Equal("system_approval_permission_required", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Prevents_station_reviewer_from_completing_final_system_stage()
    {
        var actor = new RegistrationApprovalActorContext(
            "station-reviewer", true, false, new HashSet<string>(), true);
        var store = new FakeStore(Request(
            status: RegistrationApprovalStatus.PendingSystemApproval));
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.False(result.Succeeded);
        Assert.Equal("approval_separation_of_duties_violation", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_undefined_decision_before_accessing_actor_or_store()
    {
        var store = new FakeStore(Request());
        var actorProvider = new FakeActorProvider(null);
        var service = new RegistrationApprovalApplicationService(actorProvider, store);

        var result = await service.DecideAsync(new(
            "request-1", (RegistrationApprovalDecision)999, null));

        Assert.Equal("invalid_decision", result.Code);
        Assert.Equal(0, actorProvider.Calls);
        Assert.Equal(0, store.FindCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_oversized_note_before_accessing_actor_or_store()
    {
        var store = new FakeStore(Request());
        var actorProvider = new FakeActorProvider(null);
        var service = new RegistrationApprovalApplicationService(actorProvider, store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Reject, new string('x', 2001)));

        Assert.Equal("note_too_long", result.Code);
        Assert.Equal(0, actorProvider.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Final_approval_commits_activation_transition_only_after_system_authorization()
    {
        var actor = new RegistrationApprovalActorContext(
            "system-manager", true, false, new HashSet<string>(), true);
        var store = new FakeStore(Request(
            status: RegistrationApprovalStatus.PendingSystemApproval));
        var service = new RegistrationApprovalApplicationService(
            new FakeActorProvider(actor), store);

        var result = await service.DecideAsync(new(
            "request-1", RegistrationApprovalDecision.Approve, null));

        Assert.True(result.Succeeded);
        Assert.Equal(RegistrationApprovalStatus.Active, store.Transition?.To);
        Assert.Equal("system-manager", store.ActorUserId);
    }

    private static RegistrationApprovalRequestContext Request(
        RegistrationApprovalStatus status = RegistrationApprovalStatus.PendingStationApproval)
        => new(
            "request-1",
            "applicant",
            "station-1",
            status,
            status == RegistrationApprovalStatus.PendingSystemApproval ? "station-reviewer" : null);

    private sealed class FakeActorProvider(RegistrationApprovalActorContext? actor)
        : IRegistrationApprovalActorContextProvider
    {
        public int Calls { get; private set; }

        public Task<RegistrationApprovalActorContext?> GetCurrentActorAsync(
            CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(actor);
        }
    }

    private sealed class FakeStore(RegistrationApprovalRequestContext? request)
        : IRegistrationApprovalStore
    {
        public int FindCalls { get; private set; }
        public int CommitCalls { get; private set; }
        public string? ActorUserId { get; private set; }
        public RegistrationApprovalStatus? ExpectedStatus { get; private set; }
        public RegistrationApprovalTransition? Transition { get; private set; }
        public string? Note { get; private set; }
        public RegistrationApprovalCommitResult CommitResult { get; set; }
            = RegistrationApprovalCommitResult.Committed;

        public Task<RegistrationApprovalRequestContext?> FindRequestAsync(
            string requestId,
            CancellationToken cancellationToken)
        {
            FindCalls++;
            var candidate = ReturnedRequest ?? request;\n            return Task.FromResult(candidate?.RequestId == requestId ? candidate : candidate);
        }

        public Task<RegistrationApprovalCommitResult> TryCommitDecisionAsync(
            string requestId,
            RegistrationApprovalStatus expectedStatus,
            RegistrationApprovalTransition transition,
            string actorUserId,
            string? note,
            CancellationToken cancellationToken)
        {
            CommitCalls++;
            ExpectedStatus = expectedStatus;
            Transition = transition;
            ActorUserId = actorUserId;
            Note = note;
            return Task.FromResult(CommitResult);
        }
    }
}
