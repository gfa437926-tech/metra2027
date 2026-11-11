using Npgsql;

namespace Metra.Api.Infrastructure.Persistence;

/// <summary>
/// Opens an ops connection and binds a constrained role plus request-scoped
/// user/station settings for the duration of a transaction. Settings are LOCAL
/// to the transaction so pooled connections cannot leak identity across requests.
/// </summary>
public static class NpgsqlOpsSession
{
    public const string OpsRole = "metra_ops_faults";

    public static async Task<(NpgsqlConnection Connection, NpgsqlTransaction Transaction)>
        BeginScopedAsync(
            string connectionString,
            Guid userId,
            Guid stationId,
            CancellationToken cancellationToken)
    {
        var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await using (var roleCmd = new NpgsqlCommand($"set local role {OpsRole};", connection, transaction))
            await roleCmd.ExecuteNonQueryAsync(cancellationToken);

        await using (var userCmd = new NpgsqlCommand(
                         "select set_config('app.user_id', @user_id, true);", connection, transaction))
        {
            userCmd.Parameters.AddWithValue("user_id", userId.ToString());
            await userCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var stationCmd = new NpgsqlCommand(
                         "select set_config('app.station_id', @station_id, true);", connection, transaction))
        {
            stationCmd.Parameters.AddWithValue("station_id", stationId.ToString());
            await stationCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        return (connection, transaction);
    }

    public static async Task<bool> CanConnectAsync(string? connectionString, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            return false;

        try
        {
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);
            await using var cmd = new NpgsqlCommand("select 1;", connection);
            var result = await cmd.ExecuteScalarAsync(cancellationToken);
            return result is not null && Convert.ToInt32(result) == 1;
        }
        catch (Exception)
        {
            return false;
        }
    }
}
