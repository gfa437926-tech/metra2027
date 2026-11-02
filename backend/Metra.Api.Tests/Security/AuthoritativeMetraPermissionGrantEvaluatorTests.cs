using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class AuthoritativeMetraPermissionGrantEvaluatorTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Allows_active_unrevoked_grant_for_active_actor()
    {
        var source = new FakeDataSource(new(true, true, Now.AddDays(-1), null, null));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", MetraPermissions.RegistrationSystemApprove, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal("subject-42", source.ActorSubject);
        Assert.Equal(MetraPermissions.RegistrationSystemApprove, source.Permission);
    }

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    public async Task Denies_inactive_actor_or_missing_grant(bool actorIsActive, bool grantExists)
    {
        var evaluator = Evaluator(new FakeDataSource(
            new(actorIsActive, grantExists, Now.AddDays(-1), null, null)));

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", MetraPermissions.RegistrationStationApprove, CancellationToken.None);

        Assert.False(allowed);
    }

    [Theory]
    [InlineData("2026-11-02T12:00:01+00:00", null, null)]
    [InlineData("2026-11-01T00:00:00+00:00", "2026-11-02T12:00:00+00:00", null)]
    [InlineData("2026-11-01T00:00:00+00:00", null, "2026-11-02T11:59:59+00:00")]
    public async Task Denies_future_expired_or_revoked_grants(
        string validFromUtc,
        string? validToUtc,
        string? revokedAtUtc)
    {
        var facts = new MetraPermissionGrantFacts(
            true,
            true,
            DateTimeOffset.Parse(validFromUtc),
            validToUtc is null ? null : DateTimeOffset.Parse(validToUtc),
            revokedAtUtc is null ? null : DateTimeOffset.Parse(revokedAtUtc));
        var evaluator = Evaluator(new FakeDataSource(facts));

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Rejects_unknown_permission_without_querying_source()
    {
        var source = new FakeDataSource(new(true, true, Now.AddDays(-1), null, null));
        var evaluator = Evaluator(source);

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", "admin", CancellationToken.None);

        Assert.False(allowed);
        Assert.Null(source.ActorSubject);
    }

    [Fact]
    public async Task Denies_when_no_authoritative_grant_facts_exist()
    {
        var evaluator = Evaluator(new FakeDataSource(null));

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, CancellationToken.None);

        Assert.False(allowed);
    }

    [Fact]
    public async Task Fails_closed_when_authoritative_source_throws()
    {
        var evaluator = Evaluator(new FakeDataSource(
            exception: new InvalidOperationException("authorization store unavailable")));

        var allowed = await evaluator.HasPermissionAsync(
            "subject-42", MetraPermissions.DailyObservationCreate, CancellationToken.None);

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
            evaluator.HasPermissionAsync(
                "subject-42", MetraPermissions.DailyObservationCreate, cancellation.Token));
    }

    private static AuthoritativeMetraPermissionGrantEvaluator Evaluator(
        IMetraPermissionAuthorizationDataSource source)
        => new(source, new FixedTimeProvider(Now));

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private sealed class FakeDataSource(
        MetraPermissionGrantFacts? facts = null,
        Exception? exception = null) : IMetraPermissionAuthorizationDataSource
    {
        public string? ActorSubject { get; private set; }
        public string? Permission { get; private set; }

        public Task<MetraPermissionGrantFacts?> GetGrantFactsAsync(
            string actorSubject,
            string permission,
            CancellationToken cancellationToken)
        {
            ActorSubject = actorSubject;
            Permission = permission;

            if (exception is not null)
            {
                throw exception;
            }

            return Task.FromResult(facts);
        }
    }
}
