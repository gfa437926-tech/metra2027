using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAccessMutationApplicationServiceTests
{
    private static readonly DateTimeOffset Start = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Grants_explicit_permission_using_server_actor_and_expected_version()
    {
        var actor = new FakeActor("admin-7");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 12));
        var service = new MetraAccessMutationApplicationService(actor, store);
        var command = new ChangeMetraAccessCommand(
            " user-1 ", MetraAccessMutationKind.GrantPermission, null,
            new("observations.read", "station-4", Start, null, null), null, "Approved access");

        var result = await service.ExecuteAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal("admin-7", store.ActorId);
        Assert.Equal("user-1", store.AccountId);
        Assert.Equal(12, store.ExpectedVersion);
        Assert.Equal("Approved access", store.Command?.Reason);
        Assert.Equal(MetraAccessMutationKind.GrantPermission, store.Command?.Kind);
    }

    [Fact]
    public async Task Assigns_station_with_validated_scope()
    {
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 3));
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);
        var command = new ChangeMetraAccessCommand(
            "user-1", MetraAccessMutationKind.AssignStation, null, null,
            new("station-2", Start, null, null), "Station assignment");

        var result = await service.ExecuteAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal("station-2", store.Command?.StationAssignment?.StationId);
    }

    [Fact]
    public async Task Rejects_non_active_target_before_store_commit()
    {
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Suspended, 4));
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(GrantCommand());

        Assert.Equal("target_account_not_active", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_control_characters_in_reason_before_actor_lookup()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);

        var result = await service.ExecuteAsync(GrantCommand() with { Reason = "Approved\nby admin" });

        Assert.Equal("access_mutation_reason_invalid", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Rejects_oversized_or_control_character_account_identifiers()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);

        var oversized = await service.ExecuteAsync(GrantCommand() with { AccountId = new string('a', 129) });
        var control = await service.ExecuteAsync(GrantCommand() with { AccountId = "user-1\n" });

        Assert.Equal("account_id_invalid", oversized.Code);
        Assert.Equal("account_id_invalid", control.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Fact]
    public async Task Rejects_invalid_store_snapshot_before_commit()
    {
        var store = new FakeStore(new("different-account", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(GrantCommand());

        Assert.Equal("account_snapshot_invalid", result.Code);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_missing_actor_before_target_lookup()
    {
        var actor = new FakeActor(null);
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);

        var result = await service.ExecuteAsync(GrantCommand());

        Assert.Equal("unauthenticated", result.Code);
        Assert.Equal(0, store.FindCalls);
        Assert.Equal(0, store.CommitCalls);
    }

    [Fact]
    public async Task Rejects_invalid_permission_record_before_actor_lookup()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);
        var command = GrantCommand() with
        {
            PermissionGrant = new("Observations.Read", null, Start, null, null)
        };

        var result = await service.ExecuteAsync(command);

        Assert.Equal("permission_code_invalid", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.FindCalls);
    }

    [Fact]
    public async Task Rejects_mismatched_or_ambiguous_payloads()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);
        var command = GrantCommand() with
        {
            StationAssignment = new("station-1", Start, null, null)
        };

        var result = await service.ExecuteAsync(command);

        Assert.Equal("access_mutation_payload_invalid", result.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Fact]
    public async Task Requires_reason_and_rejects_oversized_reason()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 1));
        var service = new MetraAccessMutationApplicationService(actor, store);

        var missing = await service.ExecuteAsync(GrantCommand() with { Reason = " " });
        var oversized = await service.ExecuteAsync(GrantCommand() with { Reason = new string('x', 2001) });

        Assert.Equal("access_mutation_reason_required", missing.Code);
        Assert.Equal("access_mutation_reason_too_long", oversized.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Theory]
    [InlineData(MetraAccessMutationCommitResult.Conflict, "access_mutation_conflict")]
    [InlineData(MetraAccessMutationCommitResult.ActorNotAuthorized, "actor_not_authorized")]
    [InlineData(MetraAccessMutationCommitResult.StationNotActiveOrUnknown, "station_not_active_or_unknown")]
    [InlineData(MetraAccessMutationCommitResult.PermissionUnknownOrDisabled, "permission_unknown_or_disabled")]
    [InlineData(MetraAccessMutationCommitResult.AlreadyRevoked, "access_record_already_revoked")]
    public async Task Maps_transactional_store_rejections_without_claiming_success(
        MetraAccessMutationCommitResult commitResult, string expectedCode)
    {
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 2))
        {
            CommitResult = commitResult
        };
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);

        var result = await service.ExecuteAsync(GrantCommand());

        Assert.False(result.Succeeded);
        Assert.Equal(expectedCode, result.Code);
    }

    [Fact]
    public async Task Allows_revocation_for_suspended_account_to_support_access_cleanup()
    {
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Suspended, 9));
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);
        var command = new ChangeMetraAccessCommand(
            "user-1", MetraAccessMutationKind.RevokePermission, "grant-9",
            null, null, "Emergency access cleanup");

        var result = await service.ExecuteAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal(1, store.CommitCalls);
    }

    [Fact]
    public async Task Allows_station_assignment_revocation_for_disabled_account()
    {
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Disabled, 10));
        var service = new MetraAccessMutationApplicationService(new FakeActor("admin"), store);
        var command = new ChangeMetraAccessCommand(
            "user-1", MetraAccessMutationKind.RevokeStationAssignment, "assignment-12",
            null, null, "Remove obsolete station access");

        var result = await service.ExecuteAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal(MetraAccessMutationKind.RevokeStationAssignment, store.Command?.Kind);
        Assert.Equal("assignment-12", store.Command?.RecordId);
    }

    [Fact]
    public async Task Revoke_requires_exact_record_id_and_no_replacement_payload()
    {
        var actor = new FakeActor("admin");
        var store = new FakeStore(new("user-1", MetraAccountAccessState.Active, 2));
        var service = new MetraAccessMutationApplicationService(actor, store);
        var command = new ChangeMetraAccessCommand(
            "user-1", MetraAccessMutationKind.RevokePermission, "grant-8",
            null, null, "Remove temporary access");

        var result = await service.ExecuteAsync(command);

        Assert.True(result.Succeeded);
        Assert.Equal("grant-8", store.Command?.RecordId);
    }

    private static ChangeMetraAccessCommand GrantCommand() => new(
        "user-1", MetraAccessMutationKind.GrantPermission, null,
        new("observations.read", null, Start, null, null), null, "Approved");

    private sealed class FakeActor(string? actorId) : IAccountLifecycleActorContextProvider
    {
        public int Calls { get; private set; }
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(actorId);
        }
    }

    private sealed class FakeStore(MetraAccessMutationSnapshot? snapshot) : IMetraAccessMutationStore
    {
        public int FindCalls { get; private set; }
        public int CommitCalls { get; private set; }
        public string? ActorId { get; private set; }
        public string? AccountId { get; private set; }
        public long ExpectedVersion { get; private set; }
        public ChangeMetraAccessCommand? Command { get; private set; }
        public MetraAccessMutationCommitResult CommitResult { get; set; }
            = MetraAccessMutationCommitResult.Committed;

        public Task<MetraAccessMutationSnapshot?> FindTargetAsync(
            string accountId, CancellationToken cancellationToken)
        {
            FindCalls++;
            return Task.FromResult(snapshot?.AccountId == accountId ? snapshot : null);
        }

        public Task<MetraAccessMutationCommitResult> TryCommitAsync(
            string accountId, long expectedVersion, string actorUserId,
            ChangeMetraAccessCommand command, CancellationToken cancellationToken)
        {
            CommitCalls++;
            AccountId = accountId;
            ExpectedVersion = expectedVersion;
            ActorId = actorUserId;
            Command = command;
            return Task.FromResult(CommitResult);
        }
    }
}
