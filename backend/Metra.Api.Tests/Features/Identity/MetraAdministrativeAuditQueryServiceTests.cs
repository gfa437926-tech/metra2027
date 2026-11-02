using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAdministrativeAuditQueryServiceTests
{
    private static readonly DateTimeOffset From = new(2026, 11, 1, 0, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset Before = new(2026, 11, 2, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Reads_page_using_server_actor_and_bounded_query()
    {
        var actor = new FakeActor("auditor-1");
        var page = new MetraAdministrativeAuditStorePage(
            new[] { AuditEvent("event-2", Before) }, "cursor-2", true);
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success, page));
        var service = new MetraAdministrativeAuditQueryService(actor, store);
        var query = new MetraAdministrativeAuditQuery(
            "account-1", "admin-2", "account.lifecycle.suspend", "account",
            From, Before, 50, null);

        var result = await service.ExecuteAsync(query);

        Assert.True(result.Succeeded);
        Assert.Equal("auditor-1", store.ActorId);
        Assert.Same(query, store.Query);
        Assert.NotNull(result.Page);
        Assert.Equal("event-2", result.Page.Items[0].EventId);
        Assert.DoesNotContain("Reason", typeof(MetraAdministrativeAuditListItem)
            .GetProperties().Select(property => property.Name));
    }

    [Fact]
    public async Task Rejects_invalid_page_size_before_actor_lookup()
    {
        var actor = new FakeActor("auditor");
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(actor, store);

        var result = await service.ExecuteAsync(Query() with { PageSize = 101 });

        Assert.Equal("audit_page_size_invalid", result.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_noncanonical_filters_before_actor_lookup()
    {
        var actor = new FakeActor("auditor");
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(actor, store);

        var badAccount = await service.ExecuteAsync(Query() with { TargetAccountId = "account 1" });
        var badAction = await service.ExecuteAsync(Query() with { ActionCode = "Account.Suspend" });

        Assert.Equal("audit_filter_identifier_invalid", badAccount.Code);
        Assert.Equal("audit_filter_code_invalid", badAction.Code);
        Assert.Equal(0, actor.Calls);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Requires_utc_and_ordered_time_bounds()
    {
        var actor = new FakeActor("auditor");
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(actor, store);

        var nonUtc = await service.ExecuteAsync(Query() with
        {
            OccurredFromUtc = From.ToOffset(TimeSpan.FromHours(2))
        });
        var reversed = await service.ExecuteAsync(Query() with
        {
            OccurredFromUtc = Before,
            OccurredBeforeUtc = From
        });

        Assert.Equal("audit_filter_timestamp_must_be_utc", nonUtc.Code);
        Assert.Equal("audit_filter_time_range_invalid", reversed.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Fact]
    public async Task Rejects_malformed_cursor()
    {
        var actor = new FakeActor("auditor");
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(actor, store);

        var blank = await service.ExecuteAsync(Query() with { Cursor = " " });
        var control = await service.ExecuteAsync(Query() with { Cursor = "cursor\n" });
        var oversized = await service.ExecuteAsync(Query() with { Cursor = new string('x', 2049) });

        Assert.Equal("audit_cursor_invalid", blank.Code);
        Assert.Equal("audit_cursor_invalid", control.Code);
        Assert.Equal("audit_cursor_invalid", oversized.Code);
        Assert.Equal(0, actor.Calls);
    }

    [Fact]
    public async Task Rejects_missing_actor_before_store_read()
    {
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(new FakeActor(null), store);

        var result = await service.ExecuteAsync(Query());

        Assert.Equal("unauthenticated", result.Code);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(MetraAdministrativeAuditReadResult.ActorNotAuthorized, "actor_not_authorized")]
    [InlineData(MetraAdministrativeAuditReadResult.CursorInvalid, "audit_cursor_invalid")]
    public async Task Maps_store_authorization_and_cursor_failures(
        MetraAdministrativeAuditReadResult readResult, string expectedCode)
    {
        var store = new FakeStore((readResult, null));
        var service = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), store);

        var result = await service.ExecuteAsync(Query());

        Assert.False(result.Succeeded);
        Assert.Equal(expectedCode, result.Code);
    }

    [Fact]
    public async Task Rejects_page_larger_than_requested_page_size()
    {
        var events = Enumerable.Range(1, 2).Select(index => AuditEvent(
            $"event-{index}", new DateTimeOffset(2026, 11, 2, 0, 0, index, TimeSpan.Zero))).ToArray();
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(events, null, false)));
        var service = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), store);

        var result = await service.ExecuteAsync(Query() with { PageSize = 1 });

        Assert.Equal("audit_store_response_invalid", result.Code);
    }

    [Fact]
    public async Task Rejects_invalid_or_duplicate_audit_events_in_page()
    {
        var invalid = AuditEvent("event-1", Before) with { ActionCode = "Account.Suspend" };
        var invalidStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(new[] { invalid }, null, false)));
        var invalidService = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), invalidStore);
        var invalidResult = await invalidService.ExecuteAsync(Query());

        var duplicate = AuditEvent("event-1", Before);
        var duplicateStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(new[] { duplicate, duplicate }, null, false)));
        var duplicateService = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), duplicateStore);
        var duplicateResult = await duplicateService.ExecuteAsync(Query());

        Assert.Equal("audit_store_response_invalid", invalidResult.Code);
        Assert.Equal("audit_store_response_invalid", duplicateResult.Code);
    }

    [Fact]
    public async Task Rejects_non_deterministic_page_order_and_missing_next_cursor()
    {
        var newer = AuditEvent("event-z", Before);
        var older = AuditEvent("event-a", From);
        var outOfOrderStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(new[] { older, newer }, null, false)));
        var outOfOrderService = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), outOfOrderStore);
        var outOfOrder = await outOfOrderService.ExecuteAsync(Query());

        var noCursorStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(new[] { newer }, null, true)));
        var noCursorService = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), noCursorStore);
        var noCursor = await noCursorService.ExecuteAsync(Query());

        Assert.Equal("audit_store_response_invalid", outOfOrder.Code);
        Assert.Equal("audit_store_response_invalid", noCursor.Code);
    }

    private static MetraAdministrativeAuditEvent AuditEvent(string eventId, DateTimeOffset occurredAt)
        => new(eventId, "account-1", "admin-1", "account.lifecycle.suspend",
            "account", "account-1", "active", "suspended", occurredAt,
            "Security review", "request-1", 2);

    [Fact]
    public async Task Accepts_terminal_page_without_continuation_cursor()
    {
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), null, false)));
        var service = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), store);

        var result = await service.ExecuteAsync(Query());

        Assert.True(result.Succeeded);
        Assert.NotNull(result.Page);
        Assert.False(result.Page.HasMore);
    }

    [Fact]
    public async Task Rejects_non_advancing_or_empty_continuation_page()
    {
        var eventItem = AuditEvent("event-1", Before);
        var repeatedCursorStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(new[] { eventItem }, "cursor-1", true)));
        var repeatedCursorService = new MetraAdministrativeAuditQueryService(
            new FakeActor("auditor"), repeatedCursorStore);
        var repeatedCursor = await repeatedCursorService.ExecuteAsync(
            Query() with { Cursor = "cursor-1" });

        var emptyContinuationStore = new FakeStore((MetraAdministrativeAuditReadResult.Success,
            new(Array.Empty<MetraAdministrativeAuditEvent>(), "cursor-2", true)));
        var emptyContinuationService = new MetraAdministrativeAuditQueryService(
            new FakeActor("auditor"), emptyContinuationStore);
        var emptyContinuation = await emptyContinuationService.ExecuteAsync(Query());

        Assert.Equal("audit_store_response_invalid", repeatedCursor.Code);
        Assert.Equal("audit_store_response_invalid", emptyContinuation.Code);
    }

    [Fact]
    public async Task Rejects_success_response_without_page()
    {
        var store = new FakeStore((MetraAdministrativeAuditReadResult.Success, null));
        var service = new MetraAdministrativeAuditQueryService(new FakeActor("auditor"), store);

        var result = await service.ExecuteAsync(Query());

        Assert.Equal("audit_store_response_invalid", result.Code);
    }

    private static MetraAdministrativeAuditQuery Query() => new(
        null, null, null, null, null, null, 50, null);

    private sealed class FakeActor(string? actorId) : IAccountLifecycleActorContextProvider
    {
        public int Calls { get; private set; }
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(actorId);
        }
    }

    private sealed class FakeStore(
        (MetraAdministrativeAuditReadResult Result, MetraAdministrativeAuditStorePage? Page) response)
        : IMetraAdministrativeAuditReadStore
    {
        public int Calls { get; private set; }
        public string? ActorId { get; private set; }
        public MetraAdministrativeAuditQuery? Query { get; private set; }

        public Task<(MetraAdministrativeAuditReadResult Result, MetraAdministrativeAuditStorePage? Page)>
            ReadAsync(string actorUserId, MetraAdministrativeAuditQuery query,
                CancellationToken cancellationToken)
        {
            Calls++;
            ActorId = actorUserId;
            Query = query;
            return Task.FromResult(response);
        }
    }
}
