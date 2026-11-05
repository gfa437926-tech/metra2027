using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests.Features.Identity;

public sealed class RegistrationSubmissionStatusApplicationServiceTests
{
    private static readonly Guid AuthUserId =
        Guid.Parse("d6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");
    private static readonly Guid RequestId =
        Guid.Parse("b6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");
    private static readonly DateTimeOffset SubmittedAt =
        new(2026, 11, 5, 10, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset UpdatedAt =
        new(2026, 11, 5, 11, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Returns_only_the_authenticated_applicants_own_status()
    {
        var actor = new FakeActorProvider(new(AuthUserId, true));
        var store = new FakeStore(new(
            RequestId,
            RegistrationApprovalStatus.PendingSystemApproval,
            SubmittedAt,
            UpdatedAt));
        var service = new RegistrationSubmissionStatusApplicationService(actor, store);

        var result = await service.ReadOwnAsync(RequestId);

        Assert.True(result.Succeeded);
        Assert.Equal("registration_status_loaded", result.Code);
        Assert.Equal("pending_system_approval", result.Value!.Status);
        Assert.Equal("بانتظار موافقة إدارة النظام", result.Value.StatusLabel);
        Assert.Equal(RequestId, result.Value.RequestId);
        Assert.Equal(AuthUserId, store.AuthUserId);
        Assert.Equal(RequestId, store.RequestId);
    }

    [Fact]
    public async Task Does_not_query_store_for_an_unauthenticated_applicant()
    {
        var store = new FakeStore(null);
        var service = new RegistrationSubmissionStatusApplicationService(
            new FakeActorProvider(null), store);

        var result = await service.ReadOwnAsync(RequestId);

        Assert.False(result.Succeeded);
        Assert.Equal("unauthenticated", result.Code);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_empty_request_id_before_identity_or_database_access()
    {
        var actor = new FakeActorProvider(new(AuthUserId, true));
        var store = new FakeStore(null);
        var service = new RegistrationSubmissionStatusApplicationService(actor, store);

        var result = await service.ReadOwnAsync(Guid.Empty);

        Assert.False(result.Succeeded);
        Assert.Equal("invalid_request_id", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Returns_same_not_found_result_when_request_is_not_owned_by_applicant()
    {
        var store = new FakeStore(null);
        var service = new RegistrationSubmissionStatusApplicationService(
            new FakeActorProvider(new(AuthUserId, true)), store);

        var result = await service.ReadOwnAsync(RequestId);

        Assert.False(result.Succeeded);
        Assert.Equal("registration_request_not_found", result.Code);
    }

    [Fact]
    public async Task Rejects_corrupt_or_unknown_persisted_status()
    {
        var store = new FakeStore(new(
            RequestId,
            (RegistrationApprovalStatus)999,
            SubmittedAt,
            UpdatedAt));
        var service = new RegistrationSubmissionStatusApplicationService(
            new FakeActorProvider(new(AuthUserId, true)), store);

        var result = await service.ReadOwnAsync(RequestId);

        Assert.False(result.Succeeded);
        Assert.Equal("registration_status_unavailable", result.Code);
    }

    [Fact]
    public async Task Rejects_non_utc_or_reversed_timestamps()
    {
        var store = new FakeStore(new(
            RequestId,
            RegistrationApprovalStatus.PendingStationApproval,
            SubmittedAt.ToOffset(TimeSpan.FromHours(3)),
            UpdatedAt));
        var service = new RegistrationSubmissionStatusApplicationService(
            new FakeActorProvider(new(AuthUserId, true)), store);

        var result = await service.ReadOwnAsync(RequestId);

        Assert.False(result.Succeeded);
        Assert.Equal("registration_status_unavailable", result.Code);
    }

    private sealed class FakeActorProvider(RegistrationSubmissionActorContext? context)
        : IRegistrationSubmissionActorContextProvider
    {
        public int Calls { get; private set; }

        public Task<RegistrationSubmissionActorContext?> GetCurrentAsync(
            CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(context);
        }
    }

    private sealed class FakeStore(RegistrationSubmissionStatusSnapshot? snapshot)
        : IRegistrationSubmissionStatusStore
    {
        public int Calls { get; private set; }
        public Guid? AuthUserId { get; private set; }
        public Guid? RequestId { get; private set; }

        public Task<RegistrationSubmissionStatusSnapshot?> FindOwnStatusAsync(
            Guid authUserId,
            Guid requestId,
            CancellationToken cancellationToken)
        {
            Calls++;
            AuthUserId = authUserId;
            RequestId = requestId;
            return Task.FromResult(snapshot);
        }
    }
}
