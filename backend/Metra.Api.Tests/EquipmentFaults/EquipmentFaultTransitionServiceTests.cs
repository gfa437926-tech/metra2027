using Metra.Api.Features.EquipmentFaults;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultTransitionServiceTests
{
    [Fact]
    public async Task Authorized_transition_is_forwarded_to_atomic_writer_with_actor_and_reason()
    {
        var stationId = Guid.NewGuid();
        var actorId = Guid.NewGuid();
        var faultId = Guid.NewGuid();
        var writer = new FakeWriter { Result = EquipmentFaultTransitionWriteResult.Applied };
        var service = CreateService(stationId, allowed: true, writer);

        var result = await service.ExecuteAsync(
            actorId, stationId, faultId,
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            "تمت مراجعة البلاغ.");

        Assert.Equal(EquipmentFaultTransitionExecutionResult.Applied, result);
        Assert.Equal(faultId, writer.FaultId);
        Assert.Equal(stationId, writer.StationId);
        Assert.Equal(actorId, writer.ActorId);
        Assert.Equal(EquipmentFaultStatus.Submitted, writer.ExpectedStatus);
        Assert.Equal(EquipmentFaultStatus.UnderReview, writer.NextStatus);
        Assert.Equal("تمت مراجعة البلاغ.", writer.Reason);
        Assert.Equal(1, writer.CallCount);
    }

    [Fact]
    public async Task Permission_denial_prevents_any_write()
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter();
        var service = CreateService(stationId, allowed: false, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            "مراجعة البلاغ");

        Assert.Equal(EquipmentFaultTransitionExecutionResult.Forbidden, result);
        Assert.Equal(0, writer.CallCount);
    }

    [Fact]
    public async Task Stale_write_conflict_is_returned_without_claiming_success()
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter { Result = EquipmentFaultTransitionWriteResult.Conflict };
        var service = CreateService(stationId, allowed: true, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            "مراجعة البلاغ");

        Assert.Equal(EquipmentFaultTransitionExecutionResult.Conflict, result);
    }

    [Theory]
    [InlineData("")]
    [InlineData("  سبب غير صالح")]
    [InlineData("سبب")]
    public async Task Invalid_reason_is_rejected_before_access_or_write(string reason)
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter();
        var auth = new FakeAuthorization { Allowed = true };
        var access = new EquipmentFaultApplicationService(
            auth, new FakeStationReader(stationId));
        var service = new EquipmentFaultTransitionService(access, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            reason);

        Assert.Equal(EquipmentFaultTransitionExecutionResult.InvalidRequest, result);
        Assert.Equal(0, auth.CallCount);
        Assert.Equal(0, writer.CallCount);
    }

    [Fact]
    public async Task Invalid_transition_is_rejected_before_write()
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter();
        var service = CreateService(stationId, allowed: true, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress,
            "محاولة إعادة فتح");

        Assert.Equal(EquipmentFaultTransitionExecutionResult.InvalidRequest, result);
        Assert.Equal(0, writer.CallCount);
    }

    [Theory]
    [InlineData(EquipmentFaultTransitionWriteResult.NotFoundOrWrongStation,
        EquipmentFaultTransitionExecutionResult.NotFoundOrWrongStation)]
    [InlineData(EquipmentFaultTransitionWriteResult.Forbidden,
        EquipmentFaultTransitionExecutionResult.Forbidden)]
    public async Task Writer_access_results_are_preserved(
        EquipmentFaultTransitionWriteResult writeResult,
        EquipmentFaultTransitionExecutionResult expected)
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter { Result = writeResult };
        var service = CreateService(stationId, allowed: true, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            "مراجعة البلاغ");

        Assert.Equal(expected, result);
    }

    [Fact]
    public async Task Caller_cancellation_from_atomic_writer_is_propagated()
    {
        var stationId = Guid.NewGuid();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var writer = new FakeWriter { ThrowCancellation = true };
        var service = CreateService(stationId, allowed: true, writer);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            service.ExecuteAsync(
                Guid.NewGuid(), stationId, Guid.NewGuid(),
                EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
                "مراجعة البلاغ", cancellation.Token));
    }

    [Fact]
    public async Task Unexpected_writer_failure_fails_closed()
    {
        var stationId = Guid.NewGuid();
        var writer = new FakeWriter { ThrowUnexpected = true };
        var service = CreateService(stationId, allowed: true, writer);

        var result = await service.ExecuteAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview,
            "مراجعة البلاغ");

        Assert.Equal(EquipmentFaultTransitionExecutionResult.Forbidden, result);
    }

    private static EquipmentFaultTransitionService CreateService(
        Guid stationId, bool allowed, FakeWriter writer)
    {
        var access = new EquipmentFaultApplicationService(
            new FakeAuthorization { Allowed = allowed },
            new FakeStationReader(stationId));
        return new EquipmentFaultTransitionService(access, writer);
    }

    private sealed class FakeStationReader(Guid stationId) : IEquipmentFaultStationReader
    {
        public Task<Guid?> GetOwningStationIdAsync(Guid faultId, CancellationToken cancellationToken) =>
            Task.FromResult<Guid?>(stationId);
    }

    private sealed class FakeAuthorization : IStationAuthorizationService
    {
        public bool IsConfigured => true;
        public bool Allowed { get; init; }
        public int CallCount { get; private set; }

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(Allowed);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) => Task.FromResult(false);
    }

    private sealed class FakeWriter : IEquipmentFaultTransitionWriter
    {
        public EquipmentFaultTransitionWriteResult Result { get; init; }
        public bool ThrowUnexpected { get; init; }
        public bool ThrowCancellation { get; init; }
        public int CallCount { get; private set; }
        public Guid FaultId { get; private set; }
        public Guid StationId { get; private set; }
        public Guid ActorId { get; private set; }
        public EquipmentFaultStatus ExpectedStatus { get; private set; }
        public EquipmentFaultStatus NextStatus { get; private set; }
        public string? Reason { get; private set; }

        public Task<EquipmentFaultTransitionWriteResult> TryTransitionAsync(
            Guid faultId, Guid expectedStationId,
            EquipmentFaultStatus expectedCurrentStatus, EquipmentFaultStatus nextStatus,
            Guid actorId, string reason, CancellationToken cancellationToken = default)
        {
            CallCount++;
            FaultId = faultId;
            StationId = expectedStationId;
            ExpectedStatus = expectedCurrentStatus;
            NextStatus = nextStatus;
            ActorId = actorId;
            Reason = reason;
            if (ThrowCancellation)
                throw new OperationCanceledException(cancellationToken);
            if (ThrowUnexpected)
                throw new InvalidOperationException("simulated writer failure");
            return Task.FromResult(Result);
        }
    }
}
