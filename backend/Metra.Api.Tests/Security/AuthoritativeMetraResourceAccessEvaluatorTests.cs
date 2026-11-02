using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class AuthoritativeMetraResourceAccessEvaluatorTests
{
    private static readonly MetraResourceDescriptor Resource =
        new("observation", "obs-100", "untrusted-station-from-route");

    [Fact]
    public async Task Allows_only_when_actor_resource_and_active_assignment_facts_are_valid()
    {
        var source = new FakeDataSource(new(
            ActorIsActive: true,
            ResourceExists: true,
            CanonicalStationId: "station-canonical",
            HasActiveStationAssignment: true));
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("subject-42", source.ActorSubject);
        Assert.Equal("observation", source.ResourceType);
        Assert.Equal("obs-100", source.ResourceId);
    }

    [Theory]
    [InlineData(false, true, "station-7", true)]
    [InlineData(true, false, "station-7", true)]
    [InlineData(true, true, null, true)]
    [InlineData(true, true, "", true)]
    [InlineData(true, true, "station-7", false)]
    public async Task Denies_when_any_authoritative_access_fact_is_missing_or_inactive(
        bool actorIsActive,
        bool resourceExists,
        string? canonicalStationId,
        bool hasActiveStationAssignment)
    {
        var source = new FakeDataSource(new(
            actorIsActive,
            resourceExists,
            canonicalStationId,
            hasActiveStationAssignment));
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Does_not_trust_station_id_supplied_by_the_resource_descriptor()
    {
        var source = new FakeDataSource(new(
            ActorIsActive: true,
            ResourceExists: true,
            CanonicalStationId: "station-actual",
            HasActiveStationAssignment: true));
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(source);
        var forgedDescriptor = Resource with { StationId = "station-attacker-selected" };

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", forgedDescriptor, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("obs-100", source.ResourceId);
    }

    [Fact]
    public async Task Denies_when_authoritative_resource_lookup_returns_no_facts()
    {
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(new FakeDataSource(null));

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Fails_closed_when_authoritative_data_source_throws()
    {
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(
            new FakeDataSource(exception: new InvalidOperationException("database unavailable")));

        var allowed = await evaluator.CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Propagates_request_cancellation()
    {
        using var cancellation = new CancellationTokenSource();
        await cancellation.CancelAsync();
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(
            new FakeDataSource(exception: new OperationCanceledException()));

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
        var source = new FakeDataSource(new(true, true, "station-7", true));
        var evaluator = new AuthoritativeMetraResourceAccessEvaluator(source);

        var allowed = await evaluator.CanAccessAsync(
            subject,
            new MetraResourceDescriptor(resourceType, resourceId),
            CancellationToken.None);

        Assert.False(allowed);
        Assert.Null(source.ActorSubject);
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
