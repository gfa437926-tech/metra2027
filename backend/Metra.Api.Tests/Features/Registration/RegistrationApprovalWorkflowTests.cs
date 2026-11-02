using Metra.Api.Features.Registration;
using Xunit;

namespace Metra.Api.Tests.Features.Registration;

public sealed class RegistrationApprovalWorkflowTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    private static readonly RegistrationRequestApprovalFacts PendingStationRequest =
        new("request-1", "applicant-1", "station-1",
            RegistrationRequestState.PendingStationApproval);

    private static RegistrationApprovalActorFacts StationManager(
        string userId = "station-manager",
        IReadOnlySet<string>? stations = null)
        => new(userId, true, false,
            stations ?? new HashSet<string>(["station-1"], StringComparer.Ordinal));

    private static RegistrationApprovalActorFacts SystemManager(
        string userId = "system-manager")
        => new(userId, false, true,
            new HashSet<string>(StringComparer.Ordinal));

    private static RegistrationApprovalWorkflow CreateWorkflow()
        => new(new FrozenTimeProvider(Now));

    [Fact]
    public void Station_approval_advances_only_to_system_review_and_records_audit()
    {
        var result = CreateWorkflow().DecideAtStation(
            PendingStationRequest, StationManager(),
            RegistrationApprovalDecision.Approve, "Reviewed by station manager");

        Assert.Equal(RegistrationRequestState.PendingSystemApproval,
            result.UpdatedRequest.State);
        Assert.Equal(RegistrationApprovalStage.Station, result.AuditEvent.Stage);
        Assert.Equal(RegistrationRequestState.PendingStationApproval,
            result.AuditEvent.PreviousState);
        Assert.Equal(RegistrationRequestState.PendingSystemApproval,
            result.AuditEvent.NextState);
        Assert.Equal("station-manager", result.AuditEvent.ActorMetraUserId);
        Assert.Equal(Now, result.AuditEvent.DecidedAtUtc);
        Assert.Equal("Reviewed by station manager", result.AuditEvent.Note);
    }

    [Fact]
    public void Station_rejection_ends_the_request()
    {
        var result = CreateWorkflow().DecideAtStation(
            PendingStationRequest, StationManager(),
            RegistrationApprovalDecision.Reject);

        Assert.Equal(RegistrationRequestState.Rejected, result.UpdatedRequest.State);
        Assert.Equal(RegistrationRequestState.Rejected, result.AuditEvent.NextState);
    }

    [Fact]
    public void Station_manager_cannot_decide_outside_active_station_scope()
    {
        var actor = StationManager(stations:
            new HashSet<string>(["station-2"], StringComparer.Ordinal));

        Assert.Throws<UnauthorizedAccessException>(() =>
            CreateWorkflow().DecideAtStation(
                PendingStationRequest, actor, RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void Actor_without_station_approval_permission_is_denied()
    {
        var actor = new RegistrationApprovalActorFacts(
            "viewer", false, false,
            new HashSet<string>(["station-1"], StringComparer.Ordinal));

        Assert.Throws<UnauthorizedAccessException>(() =>
            CreateWorkflow().DecideAtStation(
                PendingStationRequest, actor, RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void Applicant_cannot_approve_own_request()
    {
        var actor = StationManager(userId: "applicant-1");

        Assert.Throws<UnauthorizedAccessException>(() =>
            CreateWorkflow().DecideAtStation(
                PendingStationRequest, actor, RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void System_approval_cannot_skip_station_stage()
    {
        Assert.Throws<InvalidOperationException>(() =>
            CreateWorkflow().DecideAtSystem(
                PendingStationRequest, SystemManager(),
                RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void System_approval_activates_only_after_station_approval()
    {
        var request = PendingStationRequest with
        {
            State = RegistrationRequestState.PendingSystemApproval
        };

        var result = CreateWorkflow().DecideAtSystem(
            request, SystemManager(), RegistrationApprovalDecision.Approve);

        Assert.Equal(RegistrationRequestState.Active, result.UpdatedRequest.State);
        Assert.Equal(RegistrationApprovalStage.System, result.AuditEvent.Stage);
        Assert.Equal(RegistrationRequestState.PendingSystemApproval,
            result.AuditEvent.PreviousState);
        Assert.Equal(RegistrationRequestState.Active, result.AuditEvent.NextState);
    }

    [Fact]
    public void System_rejection_ends_the_request()
    {
        var request = PendingStationRequest with
        {
            State = RegistrationRequestState.PendingSystemApproval
        };

        var result = CreateWorkflow().DecideAtSystem(
            request, SystemManager(), RegistrationApprovalDecision.Reject);

        Assert.Equal(RegistrationRequestState.Rejected, result.UpdatedRequest.State);
    }

    [Fact]
    public void Actor_without_system_approval_permission_is_denied()
    {
        var request = PendingStationRequest with
        {
            State = RegistrationRequestState.PendingSystemApproval
        };

        Assert.Throws<UnauthorizedAccessException>(() =>
            CreateWorkflow().DecideAtSystem(
                request, StationManager(), RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void Repeated_station_decision_is_rejected_as_stale_transition()
    {
        var once = CreateWorkflow().DecideAtStation(
            PendingStationRequest, StationManager(),
            RegistrationApprovalDecision.Approve);

        Assert.Throws<InvalidOperationException>(() =>
            CreateWorkflow().DecideAtStation(
                once.UpdatedRequest, StationManager(),
                RegistrationApprovalDecision.Approve));
    }

    [Fact]
    public void Blank_note_is_normalized_to_null()
    {
        var result = CreateWorkflow().DecideAtStation(
            PendingStationRequest, StationManager(),
            RegistrationApprovalDecision.Approve, "   ");

        Assert.Null(result.AuditEvent.Note);
    }

    private sealed class FrozenTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
