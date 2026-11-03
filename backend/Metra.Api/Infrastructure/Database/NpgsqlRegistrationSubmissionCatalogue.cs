using Metra.Api.Features.Identity;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// Reads the authoritative role and station catalogues from the new METRA
/// database. A station must be approved, operational, non-demo and owned by an
/// active authority; a role must be explicitly active and requestable.
/// </summary>
public sealed class NpgsqlRegistrationSubmissionCatalogue(NpgsqlDataSource dataSource)
    : IRegistrationSubmissionCatalogue
{
    public Task<bool> IsRoleRequestableAsync(
        string roleCode,
        CancellationToken cancellationToken)
        => ExistsAsync(
            """
            select exists (
                select 1
                from public.metra_role_catalogue
                where role_code = @value
                  and is_active = true
                  and is_requestable = true
            )
            """,
            roleCode,
            NpgsqlDbType.Text,
            cancellationToken);

    public Task<bool> IsStationSelectableAsync(
        string stationId,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(stationId, out var id))
            return Task.FromResult(false);

        return ExistsAsync(
            """
            select exists (
                select 1
                from public.station_catalogue s
                join public.meteorological_authorities a
                  on a.id = s.owner_authority_id
                where s.id = @value
                  and s.approval_status = 'approved'
                  and s.operational_status = 'active'
                  and s.is_demo = false
                  and a.is_active = true
            )
            """,
            id,
            NpgsqlDbType.Uuid,
            cancellationToken);
    }

    private async Task<bool> ExistsAsync(
        string sql,
        object value,
        NpgsqlDbType type,
        CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.Add("value", type).Value = value;
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is true;
    }
}
