using System.Security.Claims;
using Metra.Api.Domain.Identity;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Resolves registration approver capabilities from live METRA records.
/// JWT claims identify only the subject; permissions and station scope are read
/// from PostgreSQL on every request and are never accepted from client claims.
/// </summary>
public sealed class NpgsqlRegistrationApprovalActorContextProvider(
    IHttpContextAccessor httpContextAccessor,
    NpgsqlDataSource dataSource,
    TimeProvider timeProvider) : IRegistrationApprovalActorContextProvider
{
    public async Task<RegistrationApprovalActorContext?> GetCurrentActorAsync(
        CancellationToken cancellationToken)
    {
        var principal = httpContextAccessor.HttpContext?.User;
        if (principal?.Identity?.IsAuthenticated != true)
            return null;

        var subject = principal.FindFirst("sub")?.Value
            ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!Guid.TryParse(subject, out var actorId) || actorId == Guid.Empty)
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            System.Data.IsolationLevel.RepeatableRead, cancellationToken);

        string? state;
        await using (var command = new NpgsqlCommand(
            "select account_state from public.metra_account_states where user_id=@user_id",
            connection, transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
            state = await command.ExecuteScalarAsync(cancellationToken) as string;
        }

        if (state is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        var now = timeProvider.GetUtcNow();
        var permissions = new HashSet<string>(StringComparer.Ordinal);
        await using (var command = new NpgsqlCommand(
            """
            select distinct permission_code
            from public.permission_grants
            where user_id=@user_id and approval_status='approved'
              and (revoked_at is null or revoked_at > @now)
              and valid_from <= @now
              and (valid_to is null or valid_to > @now)
              and permission_code in ('registrations.station.approve','registrations.system.approve')
            """, connection, transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
            command.Parameters.Add("now", NpgsqlDbType.TimestampTz).Value = now;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                permissions.Add(reader.GetString(0));
        }

        var stationIds = new HashSet<string>(StringComparer.Ordinal);
        await using (var command = new NpgsqlCommand(
            """
            select distinct station_id::text
            from public.station_assignments
            where user_id=@user_id and approval_status='approved'
              and valid_from <= @now and (valid_to is null or valid_to > @now)
            """, connection, transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
            command.Parameters.Add("now", NpgsqlDbType.TimestampTz).Value = now;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                stationIds.Add(reader.GetString(0));
        }

        await transaction.CommitAsync(cancellationToken);
        return new RegistrationApprovalActorContext(
            actorId.ToString("D"),
            state == "active",
            permissions.Contains("registrations.station.approve"),
            stationIds,
            permissions.Contains("registrations.system.approve"));
    }
}
