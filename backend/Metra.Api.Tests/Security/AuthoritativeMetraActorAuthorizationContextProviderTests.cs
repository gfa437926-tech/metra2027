using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class AuthoritativeMetraActorAuthorizationContextProviderTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    private static readonly MetraResourceDescriptor Resource =
        new("observation", "obs-100", "spoofed-station");

    [Fact]
    public async Task Allows_only_when_active_actor_permission_and_canonical_station_assignment_all_match()
    {
        var source = new FakeSource(ValidContext());
        var provider = CreateProvider(source);

        var allowed = await provider.CanPerformOnResourceAsync(
            "subject-42",
            MetraPermissions.DailyObservationCreate,
            Resource,
            CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("subject-42", source.ActorSubject);
        Assert.Equal(MetraPermissions.DailyObservationCreate, source.Permission);
        Assert.Equal(Resource, source.Resource);
        Assert.Equal(1, source.CallCount);
    }

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    public async Task Denies_if_actor_or_permission_is_not_active(bool actorIsActive, bool grantExists)
    {
        var valid = ValidContext();
        var facts = valid.PermissionGrant! with
        {
            ActorIsActive = actorIsActive,
            GrantExists = grantExists
        };
        var provider = CreateProvider(new FakeSource(valid with { PermissionGrant = facts }));

        var allowed = await provider.CanPerformOnResourceAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Denies_when_resource_is_missing_or_station_assignment_is_not_canonical()
    {
        var valid = ValidContext();
        var resourceFacts = valid.ResourceAccess! with
        {
            StationAssignments =
            [
                new MetraStationAssignmentFacts("another-station", Now.AddDays(-1), null, null)
            ]
        };
        var provider = CreateProvider(new FakeSource(valid with { ResourceAccess = resourceFacts }));

        var allowed = await provider.CanPerformOnResourceAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Theory]
    [InlineData("grant-start")]
    [InlineData("grant-end")]
    [InlineData("grant-revoked")]
    [InlineData("assignment-start")]
    [InlineData("assignment-end")]
    [InlineData("assignment-revoked")]
    public async Task Denies_future_expired_or_revoked_permission_and_assignment_facts(string scenario)
    {
        var valid = ValidContext();
        var grant = valid.PermissionGrant!;
        var assignment = valid.ResourceAccess!.StationAssignments!.Single();

        switch (scenario)
        {
            case "grant-start":
                grant = grant with { ValidFromUtc = Now.AddSeconds(1) };
                break;
            case "grant-end":
                grant = grant with { ValidToUtc = Now };
                break;
            case "grant-revoked":
                grant = grant with { RevokedAtUtc = Now };
                break;
            case "assignment-start":
                assignment = assignment with { ValidFromUtc = Now.AddSeconds(1) };
                break;
            case "assignment-end":
                assignment = assignment with { ValidToUtc = Now };
                break;
            case "assignment-revoked":
                assignment = assignment with { RevokedAtUtc = Now };
                break;
        }

        var changed = valid with
        {
            PermissionGrant = grant,
            ResourceAccess = valid.ResourceAccess with
            {
                StationAssignments = [assignment]
            }
        };
        var provider = CreateProvider(new FakeSource(changed));

        var allowed = await provider.CanPerformOnResourceAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, Resource, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Denies_unknown_permission_without_querying_authoritative_source()
    {
        var source = new FakeSource(ValidContext());
        var provider = CreateProvider(source);

        var allowed = await provider.CanPerformOnResourceAsync(
            "subject-42", "admin", Resource, CancellationToken.None);

        Assert.False(allowed);
        Assert.Equal(0, source.CallCount);
    }

    [Fact]
    public async Task Denies_when_authoritative_context_is_missing_or_source_fails()
    {
        var missing = CreateProvider(new FakeSource(null));
        Assert.False(await missing.CanPerformOnResourceAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, Resource, CancellationToken.None));

        var failed = CreateProvider(new FakeSource(exception: new InvalidOperationException()));
        Assert.False(await failed.CanPerformOnResourceAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, Resource, CancellationToken.None));
    }

    [Fact]
    public async Task Propagates_request_cancellation()
    {
        using var cancellation = new CancellationTokenSource();
        await cancellation.CancelAsync();
        var provider = CreateProvider(new FakeSource(exception: new OperationCanceledException()));

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            provider.CanPerformOnResourceAsync(
                "subject-42", MetraPermissions.DailyObservationCreate, Resource, cancellation.Token));
    }

    private static MetraActorAuthorizationContext ValidContext()
        => new(
            true,
            new MetraPermissionGrantFacts(true, true, Now.AddDays(-1), null, null),
            new MetraResourceAuthorizationFacts(
                true,
                true,
                "station-canonical",
                [
                    new MetraStationAssignmentFacts(
                        "station-canonical", Now.AddDays(-1), null, null)
                ]));

    private static AuthoritativeMetraActorAuthorizationContextProvider CreateProvider(
        IMetraActorAuthorizationContextDataSource source)
        => new(source, new FixedTimeProvider(Now));

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class FakeSource(
        MetraActorAuthorizationContext? context = null,
        Exception? exception = null) : IMetraActorAuthorizationContextDataSource
    {
        public string? ActorSubject { get; private set; }
        public string? Permission { get; private set; }
        public MetraResourceDescriptor? Resource { get; private set; }
        public int CallCount { get; private set; }

        public Task<MetraActorAuthorizationContext?> GetContextAsync(
            string actorSubject,
            string permission,
            MetraResourceDescriptor resource,
            CancellationToken cancellationToken)
        {
            CallCount++;
            ActorSubject = actorSubject;
            Permission = permission;
            Resource = resource;
            if (exception is not null)
            {
                throw exception;
            }

            return Task.FromResult(context);
        }
    }
}
