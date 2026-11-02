using Metra.Api.Security;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class StationScopedMetraResourceAccessEvaluatorTests
{
    private static readonly MetraResourceDescriptor Resource =
        new("observation", "obs-100", "caller-supplied-station");

    [Fact]
    public async Task Allows_access_when_active_actor_has_the_resource_actual_station_assignment()
    {
        var resolver = new FakeResourceStationResolver("station-canonical");
        var actors = new FakeActorStationAccessStore(
            isActive: true,
            ["station-canonical"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("observation", resolver.ResourceType);
        Assert.Equal("obs-100", resolver.ResourceId);
        Assert.Equal("subject-42", actors.ActorSubject);
    }

    [Fact]
    public async Task Ignores_caller_supplied_station_id_and_uses_resolved_resource_ownership()
    {
        var resolver = new FakeResourceStationResolver("station-actual");
        var actors = new FakeActorStationAccessStore(
            isActive: true,
            ["caller-supplied-station"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Denies_cross_station_access()
    {
        var resolver = new FakeResourceStationResolver("station-8");
        var actors = new FakeActorStationAccessStore(true, ["station-7"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Denies_inactive_actor_without_resolving_assignments()
    {
        var resolver = new FakeResourceStationResolver("station-7");
        var actors = new FakeActorStationAccessStore(false, ["station-7"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
        Assert.Equal(0, actors.AssignmentReads);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ")]
    public async Task Denies_missing_or_unclassified_resource(string? actualStationId)
    {
        var resolver = new FakeResourceStationResolver(actualStationId);
        var actors = new FakeActorStationAccessStore(true, ["station-7"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
        Assert.Equal(0, actors.AssignmentReads);
    }

    [Fact]
    public async Task Denies_when_authoritative_store_throws()
    {
        var resolver = new FakeResourceStationResolver("station-7")
        {
            ThrowOnResolve = true
        };
        var actors = new FakeActorStationAccessStore(true, ["station-7"]);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Denies_when_actor_has_no_active_station_assignments()
    {
        var resolver = new FakeResourceStationResolver("station-7");
        var actors = new FakeActorStationAccessStore(true, []);

        var allowed = await CreateEvaluator(resolver, actors).CanAccessAsync(
            "subject-42", Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    private static StationScopedMetraResourceAccessEvaluator CreateEvaluator(
        FakeResourceStationResolver resolver,
        FakeActorStationAccessStore actors)
        => new(
            resolver,
            actors,
            NullLogger<StationScopedMetraResourceAccessEvaluator>.Instance);

    private sealed class FakeResourceStationResolver(string? stationId)
        : IMetraResourceStationResolver
    {
        public string? ResourceType { get; private set; }
        public string? ResourceId { get; private set; }
        public bool ThrowOnResolve { get; init; }

        public Task<string?> ResolveStationIdAsync(
            string resourceType,
            string resourceId,
            CancellationToken cancellationToken)
        {
            ResourceType = resourceType;
            ResourceId = resourceId;
            if (ThrowOnResolve)
            {
                throw new InvalidOperationException("Simulated persistence failure.");
            }

            return Task.FromResult(stationId);
        }
    }

    private sealed class FakeActorStationAccessStore(
        bool isActive,
        IReadOnlyCollection<string> assignments)
        : IMetraActorStationAccessStore
    {
        public string? ActorSubject { get; private set; }
        public int AssignmentReads { get; private set; }

        public Task<bool> IsActorActiveAsync(
            string actorSubject,
            CancellationToken cancellationToken)
        {
            ActorSubject = actorSubject;
            return Task.FromResult(isActive);
        }

        public Task<IReadOnlyCollection<string>> GetActiveStationAssignmentsAsync(
            string actorSubject,
            CancellationToken cancellationToken)
        {
            AssignmentReads++;
            return Task.FromResult(assignments);
        }
    }
}
