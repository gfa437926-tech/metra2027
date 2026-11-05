using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// Exposes only the caller's registration status. Ownership is enforced in SQL
/// against the immutable Supabase Auth subject from the validated JWT.
/// </summary>
public sealed class NpgsqlRegistrationSubmissionStatusStore(NpgsqlDataSource dataSource)
    : IRegistrationSubmissionStatusStore
{
    public async Task<RegistrationSubmissionStatusSnapshot?> FindOwnStatusAsync(
        Guid authUserId,
        Guid requestId,
        CancellationToken cancellationToken)
    {
        if (authUserId == Guid.Empty || requestId == Guid.Empty)
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            select id, status, submitted_at, updated_at
            from public.registration_requests
            where id = @request_id
              and user_id = @auth_user_id
            """,
            connection);
        command.Parameters.Add("request_id", NpgsqlDbType.Uuid).Value = requestId;
        command.Parameters.Add("auth_user_id", NpgsqlDbType.Uuid).Value = authUserId;

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;

        var status = reader.GetString(1) switch
        {
            "pending_station_approval" => RegistrationApprovalStatus.PendingStationApproval,
            "pending_system_approval" => RegistrationApprovalStatus.PendingSystemApproval,
            "active" => RegistrationApprovalStatus.Active,
            "rejected" => RegistrationApprovalStatus.Rejected,
            _ => throw new InvalidOperationException(
                "Registration request has an unknown persisted status.")
        };

        return new RegistrationSubmissionStatusSnapshot(
            reader.GetGuid(0),
            status,
            reader.GetFieldValue<DateTimeOffset>(2).ToUniversalTime(),
            reader.GetFieldValue<DateTimeOffset>(3).ToUniversalTime());
    }
}
