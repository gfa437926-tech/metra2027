using Metra.Api.Features.Identity;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// Resolves one Supabase issuer/subject pair to a METRA profile and its effective
/// assignment/grant facts from a single repeatable-read database snapshot.
/// </summary>
public sealed class NpgsqlCurrentUserContextDataSource(
    NpgsqlDataSource dataSource,
    IConfiguration configuration) : ICurrentUserContextDataSource
{
    public async Task<CurrentUserAccountFacts?> FindByIdentitySubjectAsync(
        string issuer,
        string subject,
        CancellationToken cancellationToken)
    {
        var configuredIssuer = configuration["Authentication:Supabase:Authority"];
        if (string.IsNullOrWhiteSpace(configuredIssuer) ||
            !string.Equals(issuer.TrimEnd('/'), configuredIssuer.TrimEnd('/'), StringComparison.Ordinal) ||
            !Guid.TryParse(subject, out var userId))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            System.Data.IsolationLevel.RepeatableRead,
            cancellationToken);

        string state;
        CurrentUserProfileFacts profile;

        await using (var command = new NpgsqlCommand(
            """
            select s.account_state, p.first_name, p.father_name, p.last_name,
                   u.email, p.phone
            from public.metra_account_states s
            join public.metra_user_profiles p on p.user_id = s.user_id
            left join auth.users u on u.id = s.user_id
            where s.user_id = @user_id
            """,
            connection,
            transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = userId;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await transaction.RollbackAsync(cancellationToken);
                return null;
            }

            state = reader.GetString(0);
            profile = new(
                reader.GetString(1),
                reader.IsDBNull(2) ? null : reader.GetString(2),
                reader.GetString(3),
                reader.IsDBNull(4) ? null : reader.GetString(4),
                reader.IsDBNull(5) ? null : reader.GetString(5));
        }

        var accountState = state switch
        {
            "pending_station_approval" => MetraAccountState.PendingStationApproval,
            "pending_system_approval" => MetraAccountState.PendingSystemApproval,
            "active" => MetraAccountState.Active,
            "suspended" => MetraAccountState.Suspended,
            "rejected" => MetraAccountState.Rejected,
            _ => (MetraAccountState?)null
        };
        if (accountState is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }

        var assignments = new List<CurrentUserStationAssignmentFacts>();
        await using (var command = new NpgsqlCommand(
            """
            select a.station_id::text, s.name_ar, a.assignment_role_code,
                   a.valid_from, a.valid_to
            from public.station_assignments a
            join public.station_catalogue s on s.id = a.station_id
            where a.user_id = @user_id
              and a.approval_status = 'approved'
            order by a.station_id, a.assignment_role_code
            """,
            connection,
            transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = userId;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                assignments.Add(new(
                    reader.GetString(0),
                    reader.GetString(1),
                    reader.GetString(2),
                    reader.GetFieldValue<DateTimeOffset>(3),
                    reader.IsDBNull(4) ? null : reader.GetFieldValue<DateTimeOffset>(4),
                    null));
            }
        }

        var grants = new List<CurrentUserPermissionGrantFacts>();
        await using (var command = new NpgsqlCommand(
            """
            select permission_code, valid_from, valid_to, revoked_at
            from public.permission_grants
            where user_id = @user_id
              and approval_status = 'approved'
            order by permission_code, valid_from
            """,
            connection,
            transaction))
        {
            command.Parameters.Add("user_id", NpgsqlDbType.Uuid).Value = userId;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                grants.Add(new(
                    reader.GetString(0),
                    reader.GetFieldValue<DateTimeOffset>(1),
                    reader.IsDBNull(2) ? null : reader.GetFieldValue<DateTimeOffset>(2),
                    reader.IsDBNull(3) ? null : reader.GetFieldValue<DateTimeOffset>(3)));
            }
        }

        await transaction.CommitAsync(cancellationToken);
        return new(
            userId.ToString("D"),
            accountState.Value,
            profile,
            Array.AsReadOnly(assignments.ToArray()),
            Array.AsReadOnly(grants.ToArray()));
    }
}
