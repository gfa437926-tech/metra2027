using Npgsql;

namespace Metra.Api.Security;

public interface IStationAuthorizationService
{
    bool IsConfigured { get; }
    Task<bool> HasStationPermissionAsync(Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default);
}

public sealed class PostgresStationAuthorizationService(IConfiguration configuration) : IStationAuthorizationService
{
    private readonly string? _connectionString = configuration.GetConnectionString("MetraRuntime");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task<bool> HasStationPermissionAsync(Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default)
    {
        if (!IsConfigured || userId == Guid.Empty || stationId == Guid.Empty || string.IsNullOrWhiteSpace(permissionCode))
            return false;

        const string sql = """
            SELECT EXISTS (
                SELECT 1
                FROM public.metra_account_states account
                JOIN public.station_catalogue station ON station.id = @station_id
                JOIN public.meteorological_authorities authority
                  ON authority.id = station.owner_authority_id AND authority.country_id = station.country_id
                JOIN public.countries country ON country.id = station.country_id
                JOIN public.authority_memberships membership
                  ON membership.user_id = account.user_id AND membership.authority_id = station.owner_authority_id
                JOIN public.station_assignments assignment
                  ON assignment.user_id = account.user_id AND assignment.station_id = station.id
                 AND assignment.authority_id = station.owner_authority_id
                JOIN public.metra_role_catalogue role
                  ON role.role_code = assignment.assignment_role_code AND role.is_active = TRUE
                JOIN public.permission_grants permission
                  ON permission.user_id = account.user_id AND permission.permission_code = @permission_code
                WHERE account.user_id = @user_id
                  AND account.account_state = 'active'
                  AND station.approval_status = 'approved'
                  AND station.operational_status = 'active'
                  AND station.is_demo = FALSE
                  AND authority.is_active = TRUE AND country.is_active = TRUE
                  AND membership.approval_status = 'approved'
                  AND membership.valid_from <= now()
                  AND (membership.valid_to IS NULL OR membership.valid_to > now())
                  AND assignment.approval_status = 'approved'
                  AND assignment.valid_from <= now()
                  AND (assignment.valid_to IS NULL OR assignment.valid_to > now())
                  AND permission.approval_status = 'approved'
                  AND permission.revoked_at IS NULL
                  AND permission.valid_from <= now()
                  AND (permission.valid_to IS NULL OR permission.valid_to > now())
            );
            """;

        await using var connection = new NpgsqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("user_id", userId);
        command.Parameters.AddWithValue("station_id", stationId);
        command.Parameters.AddWithValue("permission_code", permissionCode);
        return await command.ExecuteScalarAsync(cancellationToken) is true;
    }
}
