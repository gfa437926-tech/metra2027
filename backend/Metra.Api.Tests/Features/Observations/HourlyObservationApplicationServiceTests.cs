using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class HourlyObservationApplicationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 5, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Submit_RejectsInactiveActorBeforeCallingStore()
    {
        var store = new FakeStore();
        var service = CreateService(
            new HourlyObservationActorContext("user-1", false, [], new HashSet<string> { HourlyObservationApplicationService.SubmitPermission }),
            store);

        var result = await service.SubmitAsync(ValidRequest());

        Assert.False(result.Succeeded);
        Assert.Equal("unauthenticated", result.Code);
        Assert.Null(store.Created);
    }

    [Fact]
    public async Task Submit_RequiresExactlyOneEffectiveStationAssignment()
    {
        var store = new FakeStore();
        var actor = ActiveActor(
            new HourlyObservationStationGrant("station-a", Now.AddDays(-1), null, null),
            new HourlyObservationStationGrant("station-b", Now.AddDays(-1), null, null));
        var service = CreateService(actor, store);

        var result = await service.SubmitAsync(ValidRequest());

        Assert.False(result.Succeeded);
        Assert.Equal("station_context_required", result.Code);
        Assert.Null(store.Created);
    }

    [Fact]
    public async Task Submit_DerivesStationFromActorAndCreatesPendingReview()
    {
        var store = new FakeStore();
        var actor = ActiveActor(new HourlyObservationStationGrant("station-owned", Now.AddDays(-1), null, null));
        var service = CreateService(actor, store);

        var result = await service.SubmitAsync(ValidRequest());

        Assert.True(result.Succeeded);
        Assert.Equal("station-owned", store.Created?.StationId);
        Assert.Equal("user-1", store.Created?.SubmittedBy);
        Assert.Equal(HourlyObservationStatus.PendingReview, result.Value?.Status);
    }

    [Fact]
    public async Task Review_RejectsStationOutsideActorScope()
    {
        var store = new FakeStore
        {
            ReviewTarget = new HourlyObservationReviewTarget(
                "observation-1", "station-other", HourlyObservationStatus.PendingReview)
        };
        var actor = ActiveActor(new HourlyObservationStationGrant("station-owned", Now.AddDays(-1), null, null));
        var service = CreateService(actor, store);

        var result = await service.ReviewAsync(
            "observation-1",
            new HourlyObservationReviewRequest(HourlyObservationReviewDecision.Approve, null));

        Assert.False(result.Succeeded);
        Assert.Equal("station_scope_violation", result.Code);
        Assert.Null(store.ReviewCommand);
    }

    [Fact]
    public async Task Review_ReportsConcurrentDecisionConflict()
    {
        var store = new FakeStore
        {
            ReviewTarget = new HourlyObservationReviewTarget(
                "observation-1", "station-owned", HourlyObservationStatus.PendingReview),
            ReviewResult = HourlyObservationStoreResult.Conflict
        };
        var actor = ActiveActor(new HourlyObservationStationGrant("station-owned", Now.AddDays(-1), null, null));
        var service = CreateService(actor, store);

        var result = await service.ReviewAsync(
            "observation-1",
            new HourlyObservationReviewRequest(HourlyObservationReviewDecision.Approve, null));

        Assert.False(result.Succeeded);
        Assert.Equal("review_conflict", result.Code);
        Assert.Equal(HourlyObservationStatus.PendingReview, store.ReviewCommand?.ExpectedStatus);
    }

    private static HourlyObservationApplicationService CreateService(
        HourlyObservationActorContext actor,
        FakeStore store)
        => new(new FakeActorProvider(actor), store, new FixedTimeProvider(Now));

    private static HourlyObservationActorContext ActiveActor(params HourlyObservationStationGrant[] grants)
        => new(
            "user-1",
            true,
            grants,
            new HashSet<string>(StringComparer.Ordinal)
            {
                HourlyObservationApplicationService.SubmitPermission,
                HourlyObservationApplicationService.ReviewPermission
            });

    private static CreateHourlyObservationRequest ValidRequest()
        => new(
            new DateOnly(2026, 11, 5),
            0,
            new Dictionary<string, string?>
            {
                ["utcTime"] = "00",
                ["dryTemp"] = "+20.0",
                ["wetTemp"] = "+15.0",
                ["stationPressure"] = "1013.2",
                ["seaLevelPressure"] = "1015.2",
                ["windDirection"] = "09",
                ["windSpeed"] = "05",
                ["visibility"] = "100",
                ["totalCloudCover"] = "3",
                ["relativeHumidity"] = "050",
                ["dewPoint"] = "+10.0",
                ["cover12"] = "3",
                ["cover123"] = "4"
            });

    private sealed class FakeActorProvider(HourlyObservationActorContext actor)
        : IHourlyObservationActorContextProvider
    {
        public Task<HourlyObservationActorContext?> GetCurrentActorAsync(CancellationToken cancellationToken)
            => Task.FromResult<HourlyObservationActorContext?>(actor);
    }

    private sealed class FakeStore : IHourlyObservationStore
    {
        public PersistHourlyObservationCommand? Created { get; private set; }
        public HourlyObservationReviewTarget? ReviewTarget { get; init; }
        public CommitHourlyObservationReviewCommand? ReviewCommand { get; private set; }
        public HourlyObservationStoreResult ReviewResult { get; init; } = HourlyObservationStoreResult.Committed;

        public Task<PersistedHourlyObservation> CreateAsync(
            PersistHourlyObservationCommand command,
            CancellationToken cancellationToken)
        {
            Created = command;
            return Task.FromResult(new PersistedHourlyObservation(
                "observation-1",
                command.StationId,
                command.SubmittedBy,
                command.ObservationDate,
                command.UtcHour,
                HourlyObservationStatus.PendingReview,
                command.SubmittedAt));
        }

        public Task<HourlyObservationReviewTarget?> FindReviewTargetAsync(
            string observationId,
            CancellationToken cancellationToken)
            => Task.FromResult(ReviewTarget);

        public Task<HourlyObservationStoreResult> CommitReviewAsync(
            CommitHourlyObservationReviewCommand command,
            string requiredPermission,
            CancellationToken cancellationToken)
        {
            ReviewCommand = command;
            return Task.FromResult(ReviewResult);
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
