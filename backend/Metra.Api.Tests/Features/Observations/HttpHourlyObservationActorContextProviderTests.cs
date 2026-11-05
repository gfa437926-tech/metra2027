using System.Security.Claims;
using Metra.Api.Features.Identity;
using Metra.Api.Features.Observations;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class HttpHourlyObservationActorContextProviderTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 5, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task ResolvesSubjectFromAuthenticatedPrincipalAndReturnsOnlyEffectiveGrants()
    {
        var data = new FakeIdentityDataSource(ActiveFacts());
        var accessor = CreateAccessor(
            new Claim("iss", "https://identity.example"),
            new Claim("sub", "provider-subject-1"));
        var provider = new HttpHourlyObservationActorContextProvider(
            accessor, data, new FixedTimeProvider(Now));

        var actor = await provider.GetCurrentActorAsync(CancellationToken.None);

        Assert.NotNull(actor);
        Assert.Equal("metra-user-1", actor.UserId);
        Assert.Equal("https://identity.example", data.Issuer);
        Assert.Equal("provider-subject-1", data.Subject);
        Assert.Single(actor.StationGrants);
        Assert.Equal("station-current", actor.StationGrants[0].StationId);
        Assert.Contains(HourlyObservationApplicationService.SubmitPermission, actor.Permissions);
        Assert.DoesNotContain("unrecognized.permission", actor.Permissions);
    }

    [Fact]
    public async Task ReturnsNullWhenPrincipalIsNotAuthenticated()
    {
        var data = new FakeIdentityDataSource(ActiveFacts());
        var accessor = new HttpContextAccessor { HttpContext = new DefaultHttpContext() };
        var provider = new HttpHourlyObservationActorContextProvider(
            accessor, data, new FixedTimeProvider(Now));

        var actor = await provider.GetCurrentActorAsync(CancellationToken.None);

        Assert.Null(actor);
        Assert.Null(data.Subject);
    }

    [Fact]
    public async Task ReturnsNullForNonActiveMetraAccount()
    {
        var facts = ActiveFacts() with { AccountState = MetraAccountState.Suspended };
        var data = new FakeIdentityDataSource(facts);
        var provider = new HttpHourlyObservationActorContextProvider(
            CreateAccessor(new Claim("iss", "https://identity.example"), new Claim("sub", "subject")),
            data,
            new FixedTimeProvider(Now));

        var actor = await provider.GetCurrentActorAsync(CancellationToken.None);

        Assert.Null(actor);
    }

    [Fact]
    public async Task ReturnsNullWhenIdentitySnapshotContainsNonCanonicalUserId()
    {
        var facts = ActiveFacts() with { UserId = " metra-user-1 " };
        var provider = new HttpHourlyObservationActorContextProvider(
            CreateAccessor(new Claim("iss", "https://identity.example"), new Claim("sub", "subject")),
            new FakeIdentityDataSource(facts),
            new FixedTimeProvider(Now));

        var actor = await provider.GetCurrentActorAsync(CancellationToken.None);

        Assert.Null(actor);
    }

    [Fact]
    public async Task ReturnsNullWhenIdentitySnapshotContainsInvalidStationAssignment()
    {
        var facts = ActiveFacts() with
        {
            Assignments =
            [
                new CurrentUserStationAssignmentFacts(
                    "station-current", "Station Current", "observer",
                    Now.AddDays(-1), null, null),
                new CurrentUserStationAssignmentFacts(
                    " station-injected ", "Station Injected", "observer",
                    Now.AddDays(-1), null, null)
            ]
        };
        var provider = new HttpHourlyObservationActorContextProvider(
            CreateAccessor(new Claim("iss", "https://identity.example"), new Claim("sub", "subject")),
            new FakeIdentityDataSource(facts),
            new FixedTimeProvider(Now));

        var actor = await provider.GetCurrentActorAsync(CancellationToken.None);

        Assert.Null(actor);
    }

    private static HttpContextAccessor CreateAccessor(params Claim[] claims)
    {
        var context = new DefaultHttpContext();
        context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "test"));
        return new HttpContextAccessor { HttpContext = context };
    }

    private static CurrentUserAccountFacts ActiveFacts()
        => new(
            "metra-user-1",
            MetraAccountState.Active,
            new CurrentUserProfileFacts("Observer", null, "One", null, null),
            [
                new CurrentUserStationAssignmentFacts(
                    "station-current", "Station Current", "observer",
                    Now.AddDays(-1), null, null),
                new CurrentUserStationAssignmentFacts(
                    "station-expired", "Station Expired", "observer",
                    Now.AddDays(-3), Now.AddMinutes(-1), null)
            ],
            [
                new CurrentUserPermissionGrantFacts(
                    HourlyObservationApplicationService.SubmitPermission,
                    Now.AddDays(-1), null, null),
                new CurrentUserPermissionGrantFacts(
                    "unrecognized.permission", Now.AddDays(-1), null, null),
                new CurrentUserPermissionGrantFacts(
                    HourlyObservationApplicationService.ReviewPermission,
                    Now.AddDays(-2), Now.AddMinutes(-1), null)
            ]);

    private sealed class FakeIdentityDataSource(CurrentUserAccountFacts facts)
        : ICurrentUserContextDataSource
    {
        public string? Issuer { get; private set; }
        public string? Subject { get; private set; }

        public Task<CurrentUserAccountFacts?> FindByIdentitySubjectAsync(
            string issuer,
            string subject,
            CancellationToken cancellationToken)
        {
            Issuer = issuer;
            Subject = subject;
            return Task.FromResult<CurrentUserAccountFacts?>(facts);
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
