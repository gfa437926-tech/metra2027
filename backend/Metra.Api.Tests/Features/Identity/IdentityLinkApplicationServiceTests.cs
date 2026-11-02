using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests.Features.Identity;

public sealed class IdentityLinkApplicationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Links_reauthenticated_external_identity_to_server_resolved_account()
    {
        var actor = new FakeActorProvider(new(
            "metra-account-42",
            "https://idp.example.test/",
            "provider-subject-abc",
            Now.AddMinutes(-2),
            Now.AddMinutes(-2),
            true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);
        var service = CreateService(actor, store);

        var result = await service.LinkCurrentIdentityAsync();

        Assert.True(result.Succeeded);
        Assert.Equal("identity_linked", result.Code);
        Assert.Equal("metra-account-42", store.MetraUserId);
        Assert.Equal("https://idp.example.test/", store.Issuer);
        Assert.Equal("provider-subject-abc", store.Subject);
        Assert.Equal("metra-account-42", store.AuditActorUserId);
        Assert.Equal(Now, store.LinkedAt);
    }

    [Fact]
    public async Task Does_not_accept_or_use_client_supplied_account_identifier()
    {
        var actor = new FakeActorProvider(new(
            "server-resolved-account",
            "issuer",
            "subject",
            Now,
            Now,
            true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);
        var service = CreateService(actor, store);

        await service.LinkCurrentIdentityAsync();

        Assert.Equal("server-resolved-account", store.MetraUserId);
    }

    [Fact]
    public async Task Rejects_missing_or_incomplete_trusted_identity_context()
    {
        var store = new FakeStore(IdentityLinkCommitResult.Linked);
        var cases = new IdentityLinkActorContext?[]
        {
            null,
            new("", "issuer", "subject", Now, Now, true),
            new("account", "", "subject", Now, Now, true),
            new("account", "issuer", " ", Now, Now, true)
        };

        foreach (var context in cases)
        {
            var result = await CreateService(
                new FakeActorProvider(context), store).LinkCurrentIdentityAsync();

            Assert.False(result.Succeeded);
            Assert.Equal("unauthenticated", result.Code);
        }

        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_inactive_metra_account()
    {
        var actor = new FakeActorProvider(new(
            "account", "issuer", "subject", Now, Now, false));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);

        var result = await CreateService(actor, store).LinkCurrentIdentityAsync();

        Assert.False(result.Succeeded);
        Assert.Equal("account_not_active", result.Code);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(6)]
    [InlineData(-1)]
    public async Task Requires_recent_non_future_authentication(int minutesFromNow)
    {
        var actor = new FakeActorProvider(new(
            "account", "issuer", "subject", Now.AddMinutes(-minutesFromNow), Now.AddMinutes(-minutesFromNow), true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);

        var result = await CreateService(actor, store).LinkCurrentIdentityAsync();

        Assert.False(result.Succeeded);
        Assert.Equal("recent_authentication_required", result.Code);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Requires_recent_proof_for_the_identity_being_linked_even_if_session_is_fresh()
    {
        var actor = new FakeActorProvider(new(
            "account", "issuer", "new-provider-subject",
            Now, Now.AddMinutes(-6), true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);

        var result = await CreateService(actor, store).LinkCurrentIdentityAsync();

        Assert.False(result.Succeeded);
        Assert.Equal("recent_authentication_required", result.Code);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Treats_exact_five_minute_authentication_age_as_valid()
    {
        var actor = new FakeActorProvider(new(
            "account", "issuer", "subject", Now.AddMinutes(-5), Now.AddMinutes(-5), true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);

        var result = await CreateService(actor, store).LinkCurrentIdentityAsync();

        Assert.True(result.Succeeded);
        Assert.Equal(1, store.Calls);
    }

    [Theory]
    [InlineData(IdentityLinkCommitResult.AlreadyLinkedToSameAccount, true, "identity_already_linked")]
    [InlineData(IdentityLinkCommitResult.IdentityLinkedToDifferentAccount, false, "identity_already_in_use")]
    [InlineData(IdentityLinkCommitResult.AccountUnavailable, false, "account_unavailable")]
    [InlineData(IdentityLinkCommitResult.Conflict, false, "identity_link_conflict")]
    public async Task Maps_atomic_store_outcomes_without_leaking_store_details(
        IdentityLinkCommitResult commit,
        bool succeeded,
        string code)
    {
        var actor = new FakeActorProvider(new(
            "account", "issuer", "subject", Now, Now, true));
        var store = new FakeStore(commit);

        var result = await CreateService(actor, store).LinkCurrentIdentityAsync();

        Assert.Equal(succeeded, result.Succeeded);
        Assert.Equal(code, result.Code);
    }

    [Fact]
    public async Task Propagates_cancellation_to_the_atomic_store()
    {
        using var cts = new CancellationTokenSource();
        var actor = new FakeActorProvider(new(
            "account", "issuer", "subject", Now, true));
        var store = new FakeStore(IdentityLinkCommitResult.Linked);
        var service = CreateService(actor, store);

        await service.LinkCurrentIdentityAsync(cts.Token);

        Assert.Equal(cts.Token, store.CancellationToken);
    }

    private static IdentityLinkApplicationService CreateService(
        FakeActorProvider actor,
        FakeStore store)
        => new(actor, store, new FrozenTimeProvider(Now));

    private sealed class FakeActorProvider(IdentityLinkActorContext? context)
        : IIdentityLinkActorContextProvider
    {
        public Task<IdentityLinkActorContext?> GetCurrentAsync(
            CancellationToken cancellationToken)
            => Task.FromResult(context);
    }

    private sealed class FakeStore(IdentityLinkCommitResult result) : IIdentityLinkStore
    {
        public int Calls { get; private set; }
        public string? MetraUserId { get; private set; }
        public string? Issuer { get; private set; }
        public string? Subject { get; private set; }
        public DateTimeOffset LinkedAt { get; private set; }
        public string? AuditActorUserId { get; private set; }
        public CancellationToken CancellationToken { get; private set; }

        public Task<IdentityLinkCommitResult> TryLinkAsync(
            string metraUserId,
            string issuer,
            string subject,
            DateTimeOffset linkedAt,
            string auditActorUserId,
            CancellationToken cancellationToken)
        {
            Calls++;
            MetraUserId = metraUserId;
            Issuer = issuer;
            Subject = subject;
            LinkedAt = linkedAt;
            AuditActorUserId = auditActorUserId;
            CancellationToken = cancellationToken;
            return Task.FromResult(result);
        }
    }

    private sealed class FrozenTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
