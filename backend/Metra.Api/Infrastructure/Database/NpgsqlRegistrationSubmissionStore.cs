using Metra.Api.Features.Identity;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// Calls the single-statement PostgreSQL registration transaction. AuthUserId
/// must originate from the validated JWT subject in the trusted actor provider.
/// </summary>
public sealed class NpgsqlRegistrationSubmissionStore(NpgsqlDataSource dataSource)
    : IRegistrationSubmissionStore
{
    public async Task<RegistrationSubmissionCommitResult> TryCreatePendingAsync(
        PendingRegistrationSubmission submission,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(submission);
        if (!Guid.TryParse(submission.RequestedStationId, out var stationId))
            return new(RegistrationSubmissionCommitStatus.Conflict);

        // A concurrent request may win a unique-index race. The failed SQL
        // statement is rolled back by PostgreSQL; retrying the same idempotency
        // key lets the function classify the committed winner without duplicates.
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
                await using var command = new NpgsqlCommand(
                    """
                    select result_status, account_id, request_id
                    from private.submit_metra_registration(
                        @auth_user_id, @first_name, @father_name, @last_name,
                        @phone, @role_code, @station_id, @terms_version,
                        @submitted_at, @idempotency_key)
                    """,
                    connection);

                command.Parameters.Add("auth_user_id", NpgsqlDbType.Uuid).Value = submission.AuthUserId;
                command.Parameters.Add("first_name", NpgsqlDbType.Text).Value = submission.FirstName;
                command.Parameters.Add("father_name", NpgsqlDbType.Text).Value = submission.FatherName;
                command.Parameters.Add("last_name", NpgsqlDbType.Text).Value = submission.LastName;
                command.Parameters.Add("phone", NpgsqlDbType.Text).Value =
                    (object?)submission.Phone ?? DBNull.Value;
                command.Parameters.Add("role_code", NpgsqlDbType.Text).Value = submission.RequestedRoleCode;
                command.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
                command.Parameters.Add("terms_version", NpgsqlDbType.Text).Value = submission.TermsVersion;
                command.Parameters.Add("submitted_at", NpgsqlDbType.TimestampTz).Value = submission.SubmittedAtUtc;
                command.Parameters.Add("idempotency_key", NpgsqlDbType.Text).Value = submission.IdempotencyKey;

                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                    throw new InvalidOperationException("Registration persistence returned no outcome.");

                var status = reader.GetString(0);
                var accountId = reader.IsDBNull(1) ? (Guid?)null : reader.GetGuid(1);
                var requestId = reader.IsDBNull(2) ? (Guid?)null : reader.GetGuid(2);

                var commitStatus = status switch
                {
                    "created" => RegistrationSubmissionCommitStatus.Created,
                    "already_created" => RegistrationSubmissionCommitStatus.AlreadyCreatedForSameIdempotencyKey,
                    "auth_user_already_linked" => RegistrationSubmissionCommitStatus.AuthUserAlreadyLinked,
                    "existing_pending" => RegistrationSubmissionCommitStatus.ExistingPendingRequest,
                    "conflict" => RegistrationSubmissionCommitStatus.Conflict,
                    "station_not_available" => RegistrationSubmissionCommitStatus.Conflict,
                    _ => throw new InvalidOperationException("Registration persistence returned an unknown outcome.")
                };

                return new(commitStatus, accountId, requestId);
            }
            catch (PostgresException exception)
                when (attempt == 0 && exception.SqlState == PostgresErrorCodes.UniqueViolation)
            {
                // Re-run with the same key and payload to classify the winner.
            }
            catch (PostgresException exception)
                when (exception.SqlState == PostgresErrorCodes.CheckViolation &&
                      exception.ConstraintName is "registration_requests_station_selectable"
                          or "registration_requests_role_requestable")
            {
                return new(RegistrationSubmissionCommitStatus.Conflict);
            }
        }
    }
}
