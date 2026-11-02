using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class AuthoritativeMetraResourceAccessEvaluatorTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    private static readonly MetraResourceDescriptor Resource =
        new("observation", "obs-100", "untrusted-station-from-route");

    [Fact]
    public async Task Allows_when_active_assignment_covers_canonical_station_at_current_instant()
    {
        var source = new FakeDataSource(new(
            ActorIsActive: true,
            ResourceExists: true,
            CanonicalStationId: "station-canonical",
            StationAssignments:
            [
                new("station-other", Now.AddDays(-2), null, null),
                new("station-canonical", Now.AddDays(-1), Now.AddDays(1), null)
            ]));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("subject-42", source.ActorSubject);
        Assert.Equal("observation", source.ResourceType);
        Assert.Equal("obs-100", source.ResourceId);
    }

    [Theory]
    [InlineData(false, true, "station-7")]
    [InlineData(true, false, "station-7")]
    [InlineData(true, true, null)]
    [InlineData(true, true, "")]
    public async Task Denies_inactive_actor_missing_resource_or_canonical_station(
        bool actorIsActive,
        bool resourceExists,
        string? canonicalStationId)
    {
        var source = new FakeDataSource(new(
            actorIsActive,
            resourceExists,
            canonicalStationId,
            [new("station-7", Now.AddDays(-1), null, null)]));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Theory]
    [InlineData("station-other", "2026-11-01T00:00:00+00:00", null, null)]
    [InlineData("station-7", "2026-11-02T12:00:01+00:00", null, null)]
    [InlineData("station-7", "2026-11-01T00:00:00+00:00", "2026-11-02T12:00:00+00:00", null)]
    [InlineData("station-7", "2026-11-01T00:00:00+00:00", null, "2026-11-02T11:59:59+00:00")]
    public async Task Denies_assignment_for_wrong_station_or_outside_validity_window(
        string stationId,
        DateTimeOffset validFromUtc,
        DateTimeOffset? validToUtc,
        DateTimeOffset? revokedAtUtc)
    {
        var source = new FakeDataSource(new(
            true,
            true,
            "station-7",
            [new(stationId, validFromUtc, validToUtc, revokedAtUtc)]));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Does_not_trust_station_id_supplied_by_resource_descriptor()
    {
        var source = new FakeDataSource(new(
            true,
            true,
            "station-actual",
            [new("station-actual", Now.AddDays(-1), null, null)]));
        var evaluator = Evaluator(source);
        var forgedDescriptor = Resource with { StationId = "station-attacker-selected" };

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", forgedDescriptor, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("obs-100", source.ResourceId);
    }

    [Fact]
    public async Task Denies_when_authoritative_resource_lookup_returns_no_facts()
    {
        var evaluator = Evaluator(new FakeDataSource(null));

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Fails_closed_when_authoritative_data_source_throws()
    {
        var evaluator = Evaluator(new FakeDataSource(
            exception: new InvalidOperationException("database unavailable")));

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Propagates_request_cancellation()
    {
        using var cancellation = new CancellationTokenSource();
        await cancellation.CancelAsync();
        var evaluator = Evaluator(new FakeDataSource(
            exception: new OperationCanceledException()));

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            evaluator.CanAccessAsync("subject-42", Resource, cancellation.Token));
    }

    [Theory]
    [InlineData("", "observation", "obs-100")]
    [InlineData("subject-42", "", "obs-100")]
    [InlineData("subject-42", "observation", " ")]
    public async Task Rejects_missing_lookup_identifiers_without_calling_data_source(
        string subject,
        string resourceType,
        string resourceId)
    {
        var source = new FakeDataSource(new(true, true, "station-7",
            [new("station-7", Now.AddDays(-1), null, null)]));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            subject,
            new MetraResourceDescriptor(resourceType, resourceId),
            CancellationToken.None);

        Assert.False(allowed);
        Assert.Null(source.ActorSubject);
    }

    private static AuthoritativeMetraResourceAccessEvaluator Evaluator(
        IMetraResourceAuthorizationDataSource source)
        => new(source, new FixedTimeProvider(Now));

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class FakeDataSource(
        MetraResourceAuthorizationFacts? facts = null,
        Exception? exception = null) : IMetraResourceAuthorizationDataSource
    {
        public string? ActorSubject { get; private set; }
        public string? ResourceType { get; private set; }
        public string? ResourceId { get; private set; }

        public Task<MetraResourceAuthorizationFacts?> GetFactsAsync(
            string actorSubject,
            string resourceType,
            string resourceId,
            CancellationToken cancellationToken)
        {
            ActorSubject = actorSubject;
            ResourceType = resourceType;
            ResourceId = resourceId;

            if (exception is not null)
            {
                throw exception;
            }

            return Task.FromResult(facts);
        }
    }
}
