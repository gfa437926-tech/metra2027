using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests.Features.Identity;

public sealed class RegistrationSubmissionApplicationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    private static readonly Guid AuthUserId =
        Guid.Parse("d6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");

    private static readonly Guid AccountId =
        Guid.Parse("c6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");

    private static readonly Guid RequestId =
        Guid.Parse("b6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");

    private static SubmitRegistrationRequest ValidCommand()
        => new(
            " إبراهيم ",
            "محمد",
            "علي",
            "  +963 900 000 000  ",
            "observer",
            "station-1",
            "terms-2026-01",
            true,
            "registration-submit-001");

    private static RegistrationSubmissionApplicationService CreateService(
        FakeActorProvider? actor = null,
        FakeCatalogue? catalogue = null,
        FakeStore? store = null)
        => new(
            actor ?? new FakeActorProvider(new(AuthUserId, true)),
            catalogue ?? new FakeCatalogue(),
            store ?? new FakeStore(new(
                RegistrationSubmissionCommitStatus.Created, AccountId, RequestId)),
            new FrozenTimeProvider(Now));

    [Fact]
    public async Task Creates_pending_registration_using_auth_subject_from_trusted_context()
    {
        var store = new FakeStore(new(
            RegistrationSubmissionCommitStatus.Created, AccountId, RequestId));

        var result = await CreateService(store: store).SubmitAsync(ValidCommand());

        Assert.True(result.Succeeded);
        Assert.Equal("registration_submitted", result.Code);
        Assert.Equal(AccountId, result.AccountId);
        Assert.Equal(RequestId, result.RequestId);
        Assert.Equal(AuthUserId, store.Submission!.AuthUserId);
        Assert.Equal("إبراهيم", store.Submission.FirstName);
        Assert.Equal("+963 900 000 000", store.Submission.Phone);
        Assert.Equal(Now, store.Submission.SubmittedAtUtc);
    }

    [Fact]
    public async Task Does_not_accept_auth_user_id_from_the_registration_command()
    {
        var store = new FakeStore(new(
            RegistrationSubmissionCommitStatus.Created, AccountId, RequestId));

        await CreateService(store: store).SubmitAsync(ValidCommand());

        Assert.Equal(AuthUserId, store.Submission!.AuthUserId);
    }

    [Fact]
    public async Task Rejects_missing_or_unauthenticated_supabase_context()
    {
        foreach (var actor in new RegistrationSubmissionActorContext?[]
        {
            null,
            new(Guid.Empty, true),
            new(AuthUserId, false)
        })
        {
            var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));
            var result = await CreateService(
                actor: new FakeActorProvider(actor), store: store)
                .SubmitAsync(ValidCommand());

            Assert.False(result.Succeeded);
            Assert.Equal("unauthenticated", result.Code);
            Assert.Equal(0, store.Calls);
        }
    }

    [Fact]
    public async Task Rejects_incomplete_registration_before_catalogue_or_store_access()
    {
        var catalogue = new FakeCatalogue();
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(ValidCommand() with { FirstName = " " });

        Assert.False(result.Succeeded);
        Assert.Equal("invalid_registration", result.Code);
        Assert.Equal(0, catalogue.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData("FirstName")]
    [InlineData("FatherName")]
    [InlineData("LastName")]
    [InlineData("Phone")]
    [InlineData("RequestedRoleCode")]
    [InlineData("RequestedStationId")]
    [InlineData("TermsVersion")]
    [InlineData("IdempotencyKey")]
    public async Task Rejects_oversized_registration_fields_before_catalogue_or_store_access(
        string field)
    {
        var catalogue = new FakeCatalogue();
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));
        var oversized = new string('x', 129);
        var command = field switch
        {
            "FirstName" => ValidCommand() with { FirstName = oversized },
            "FatherName" => ValidCommand() with { FatherName = oversized },
            "LastName" => ValidCommand() with { LastName = oversized },
            "Phone" => ValidCommand() with { Phone = oversized },
            "RequestedRoleCode" => ValidCommand() with { RequestedRoleCode = oversized },
            "RequestedStationId" => ValidCommand() with { RequestedStationId = oversized },
            "TermsVersion" => ValidCommand() with { TermsVersion = oversized },
            "IdempotencyKey" => ValidCommand() with { IdempotencyKey = oversized },
            _ => throw new ArgumentOutOfRangeException(nameof(field))
        };

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(command);

        Assert.False(result.Succeeded);
        Assert.Equal("invalid_registration", result.Code);
        Assert.Equal(0, catalogue.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Trims_server_catalogue_keys_and_persisted_registration_values()
    {
        var catalogue = new FakeCatalogue();
        var store = new FakeStore(new(
            RegistrationSubmissionCommitStatus.Created, AccountId, RequestId));
        var command = ValidCommand() with
        {
            RequestedRoleCode = " observer ",
            RequestedStationId = " station-1 ",
            TermsVersion = " terms-2026-01 ",
            IdempotencyKey = " registration-submit-001 "
        };

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal("observer", store.Submission!.RequestedRoleCode);
        Assert.Equal("station-1", store.Submission.RequestedStationId);
        Assert.Equal("terms-2026-01", store.Submission.TermsVersion);
        Assert.Equal("registration-submit-001", store.Submission.IdempotencyKey);
    }

    [Fact]
    public async Task Requires_terms_acceptance()
    {
        var catalogue = new FakeCatalogue();
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(ValidCommand() with { TermsAccepted = false });

        Assert.False(result.Succeeded);
        Assert.Equal("terms_not_accepted", result.Code);
        Assert.Equal(0, catalogue.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_role_not_in_server_catalogue()
    {
        var catalogue = new FakeCatalogue(roleAvailable: false);
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(ValidCommand());

        Assert.False(result.Succeeded);
        Assert.Equal("role_not_available", result.Code);
        Assert.Equal(1, catalogue.RoleCalls);
        Assert.Equal(0, catalogue.StationCalls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_station_not_in_server_catalogue()
    {
        var catalogue = new FakeCatalogue(stationAvailable: false);
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));

        var result = await CreateService(catalogue: catalogue, store: store)
            .SubmitAsync(ValidCommand());

        Assert.False(result.Succeeded);
        Assert.Equal("station_not_available", result.Code);
        Assert.Equal(1, catalogue.RoleCalls);
        Assert.Equal(1, catalogue.StationCalls);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(RegistrationSubmissionCommitStatus.AuthUserAlreadyLinked, "auth_user_already_linked")]
    [InlineData(RegistrationSubmissionCommitStatus.ExistingPendingRequest, "registration_already_pending")]
    [InlineData(RegistrationSubmissionCommitStatus.Conflict, "registration_submission_conflict")]
    public async Task Maps_store_conflicts_to_safe_domain_outcomes(
        RegistrationSubmissionCommitStatus status,
        string expectedCode)
    {
        var store = new FakeStore(new(status));

        var result = await CreateService(store: store).SubmitAsync(ValidCommand());

        Assert.False(result.Succeeded);
        Assert.Equal(expectedCode, result.Code);
    }

    [Fact]
    public async Task Returns_existing_result_for_idempotent_retry()
    {
        var store = new FakeStore(new(
            RegistrationSubmissionCommitStatus.AlreadyCreatedForSameIdempotencyKey,
            AccountId, RequestId));

        var result = await CreateService(store: store).SubmitAsync(ValidCommand());

        Assert.True(result.Succeeded);
        Assert.Equal("registration_already_submitted", result.Code);
        Assert.Equal(AccountId, result.AccountId);
        Assert.Equal(RequestId, result.RequestId);
    }

    [Fact]
    public async Task Fails_closed_when_store_reports_success_without_identifiers()
    {
        var store = new FakeStore(new(RegistrationSubmissionCommitStatus.Created));

        var result = await CreateService(store: store).SubmitAsync(ValidCommand());

        Assert.False(result.Succeeded);
        Assert.Equal("registration_submission_failed", result.Code);
    }

    [Fact]
    public async Task Propagates_cancellation_to_actor_catalogue_and_store()
    {
        using var cts = new CancellationTokenSource();
        var actor = new FakeActorProvider(new(AuthUserId, true));
        var catalogue = new FakeCatalogue();
        var store = new FakeStore(new(
            RegistrationSubmissionCommitStatus.Created, AccountId, RequestId));

        await CreateService(actor, catalogue, store).SubmitAsync(ValidCommand(), cts.Token);

        Assert.Equal(cts.Token, actor.CancellationToken);
        Assert.Equal(cts.Token, catalogue.CancellationToken);
        Assert.Equal(cts.Token, store.CancellationToken);
    }

    private sealed class FakeActorProvider(RegistrationSubmissionActorContext? context)
        : IRegistrationSubmissionActorContextProvider
    {
        public CancellationToken CancellationToken { get; private set; }

        public Task<RegistrationSubmissionActorContext?> GetCurrentAsync(
            CancellationToken cancellationToken)
        {
            CancellationToken = cancellationToken;
            return Task.FromResult(context);
        }
    }

    private sealed class FakeCatalogue(
        bool roleAvailable = true,
        bool stationAvailable = true) : IRegistrationSubmissionCatalogue
    {
        public int Calls => RoleCalls + StationCalls;
        public int RoleCalls { get; private set; }
        public int StationCalls { get; private set; }
        public CancellationToken CancellationToken { get; private set; }

        public Task<bool> IsRoleRequestableAsync(
            string roleCode, CancellationToken cancellationToken)
        {
            RoleCalls++;
            CancellationToken = cancellationToken;
            return Task.FromResult(roleAvailable);
        }

        public Task<bool> IsStationSelectableAsync(
            string stationId, CancellationToken cancellationToken)
        {
            StationCalls++;
            CancellationToken = cancellationToken;
            return Task.FromResult(stationAvailable);
        }
    }

    private sealed class FakeStore(RegistrationSubmissionCommitResult result)
        : IRegistrationSubmissionStore
    {
        public int Calls { get; private set; }
        public PendingRegistrationSubmission? Submission { get; private set; }
        public CancellationToken CancellationToken { get; private set; }

        public Task<RegistrationSubmissionCommitResult> TryCreatePendingAsync(
            PendingRegistrationSubmission submission,
            CancellationToken cancellationToken)
        {
            Calls++;
            Submission = submission;
            CancellationToken = cancellationToken;
            return Task.FromResult(result);
        }
    }

    private sealed class FrozenTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
