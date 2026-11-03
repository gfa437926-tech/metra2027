using System.Data;
using Metra.Api.Domain.Identity;
using Metra.Api.Security;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// Transaction-consistent PostgreSQL authorization reads. Resource resolution is
/// intentionally limited to canonical station resources; unknown resource types
/// fail closed until a reviewed resource mapping is implemented.
/// </summary>
public sealed class NpgsqlMetraAuthorizationDataSources(NpgsqlDataSource dataSource)
    : IMetraPermissionAuthorizationDataSource,
      IMetraResourceAuthorizationDataSource,
      IMetraActorAuthorizationContextDataSource
{
    public async Task<MetraPermissionGrantFacts?> GetGrantFactsAsync(
        string actorSubject,
        string permission,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(actorSubject, out var actorId) ||
            actorId == Guid.Empty ||
            !MetraPermissions.All.Contains(permission, StringComparer.Ordinal))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            IsolationLevel.RepeatableRead, cancellationToken);

        var actorActive = await ReadActorActiveAsync(connection, transaction, actorId, cancellationToken);
        if (actorActive is null)
        {
            await transaction.CommitAsync(cancellationToken);
            return null;
        }

        var grant = await ReadPermissionGrantAsync(
            connection, transaction, actorId, permission, cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return grant is null
            ? new MetraPermissionGrantFacts(actorActive.Value, false, DateTimeOffset.UnixEpoch, null, null)
            : new MetraPermissionGrantFacts(
                actorActive.Value, true, grant.Value.ValidFrom, grant.Value.ValidTo, grant.Value.RevokedAt);
    }

    public async Task<MetraResourceAuthorizationFacts?> GetFactsAsync(
        string actorSubject,
        string resourceType,
        string resourceId,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(actorSubject, out var actorId) ||
            actorId == Guid.Empty ||
            !TryGetStationResource(resourceType, resourceId, out var stationId))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            IsolationLevel.RepeatableRead, cancellationToken);

        var actorActive = await ReadActorActiveAsync(connection, transaction, actorId, cancellationToken);
        if (actorActive is null)
        {
            await transaction.CommitAsync(cancellationToken);
            return null;
        }

        var canonicalStationId = await ReadSelectableStationAsync(
            connection, transaction, stationId, cancellationToken);
        var assignments = canonicalStationId is null
            ? Array.Empty<MetraStationAssignmentFacts>()
            : await ReadStationAssignmentsAsync(
                connection, transaction, actorId, stationId, cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return new(
            actorActive.Value,
            canonicalStationId is not null,
            canonicalStationId,
            Array.AsReadOnly(assignments));
    }

    public async Task<MetraActorAuthorizationContext?> GetContextAsync(
        string actorSubject,
        string permission,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(actorSubject, out var actorId) ||
            actorId == Guid.Empty ||
            !MetraPermissions.All.Contains(permission, StringComparer.Ordinal) ||
            !TryGetStationResource(resource.ResourceType, resource.ResourceId, out var stationId))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            IsolationLevel.RepeatableRead, cancellationToken);

        var actorActive = await ReadActorActiveAsync(connection, transaction, actorId, cancellationToken);
        if (actorActive is null)
        {
            await transaction.CommitAsync(cancellationToken);
            return null;
        }

        var grant = await ReadPermissionGrantAsync(
            connection, transaction, actorId, permission, cancellationToken);
        var grantFacts = grant is null
            ? new MetraPermissionGrantFacts(actorActive.Value, false, DateTimeOffset.UnixEpoch, null, null)
            : new MetraPermissionGrantFacts(
                actorActive.Value, true, grant.Value.ValidFrom, grant.Value.ValidTo, grant.Value.RevokedAt);

        var canonicalStationId = await ReadSelectableStationAsync(
            connection, transaction, stationId, cancellationToken);
        var assignments = canonicalStationId is null
            ? Array.Empty<MetraStationAssignmentFacts>()
            : await ReadStationAssignmentsAsync(
                connection, transaction, actorId, stationId, cancellationToken);

        var resourceFacts = new MetraResourceAuthorizationFacts(
            actorActive.Value,
            canonicalStationId is not null,
            canonicalStationId,
            Array.AsReadOnly(assignments));

        await transaction.CommitAsync(cancellationToken);
        return new(actorActive.Value, grantFacts, resourceFacts);
    }

    private static async Task<bool?> ReadActorActiveAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid actorId,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            "select account_state='active' from public.metra_account_states where user_id=@user_id",
            connection, transaction);
        command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is bool active ? active : null;
    }

    private static async Task<PermissionGrantRow?> ReadPermissionGrantAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid actorId,
        string permission,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            """
            select valid_from,valid_to,revoked_at
            from public.permission_grants
            where user_id=@user_id and permission_code=@permission
              and approval_status='approved'
            order by valid_from desc
            limit 1
            """, connection, transaction);
        command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
        command.Parameters.Add("permission", NpgsqlDbType.Text).Value = permission;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;
        return new(
            reader.GetFieldValue<DateTimeOffset>(0),
            reader.IsDBNull(1) ? null : reader.GetFieldValue<DateTimeOffset>(1),
            reader.IsDBNull(2) ? null : reader.GetFieldValue<DateTimeOffset>(2));
    }

    private static async Task<string?> ReadSelectableStationAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid stationId,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(
            """
            select s.id::text
            from public.station_catalogue s
            join public.meteorological_authorities a on a.id=s.owner_authority_id
            where s.id=@station_id and s.approval_status='approved'
              and s.operational_status='active' and s.is_demo=false
              and a.is_active=true
            """, connection, transaction);
        command.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
        return await command.ExecuteScalarAsync(cancellationToken) as string;
    }

    private static async Task<MetraStationAssignmentFacts[]> ReadStationAssignmentsAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid actorId,
        Guid stationId,
        CancellationToken cancellationToken)
    {
        var assignments = new List<MetraStationAssignmentFacts>();
        await using var command = new NpgsqlCommand(
            """
            select station_id::text,valid_from,valid_to
            from public.station_assignments
            where user_id=@user_id and station_id=@station_id and approval_status='approved'
            order by valid_from
            """, connection, transaction);
        command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = actorId;
        command.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            assignments.Add(new(
                reader.GetString(0),
                reader.GetFieldValue<DateTimeOffset>(1),
                reader.IsDBNull(2) ? null : reader.GetFieldValue<DateTimeOffset>(2),
                null));
        }
        return assignments.ToArray();
    }

    private static bool TryGetStationResource(
        string resourceType,
        string resourceId,
        out Guid stationId)
        => string.Equals(resourceType, "station", StringComparison.Ordinal) &&
           Guid.TryParse(resourceId, out stationId) &&
           stationId != Guid.Empty;

    private sealed record PermissionGrantRow(
        DateTimeOffset ValidFrom,
        DateTimeOffset? ValidTo,
        DateTimeOffset? RevokedAt);
}
