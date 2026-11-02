using Npgsql;

namespace Metra.Api.Infrastructure.Database;

public static class MetraDatabaseConfiguration
{
    public static string? BuildConnectionString(string? configuredConnectionString, bool isDevelopment)
    {
        if (string.IsNullOrWhiteSpace(configuredConnectionString))
        {
            if (isDevelopment)
            {
                return null;
            }

            throw new InvalidOperationException(
                "ConnectionStrings:MetraDatabase must be configured outside Development.");
        }

        var connection = new NpgsqlConnectionStringBuilder(configuredConnectionString);

        if (string.IsNullOrWhiteSpace(connection.Host)
            || string.IsNullOrWhiteSpace(connection.Database)
            || string.IsNullOrWhiteSpace(connection.Username)
            || string.IsNullOrWhiteSpace(connection.Password))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:MetraDatabase must include host, database, username and password.");
        }

        // Never allow a configuration value to silently downgrade transport security.
        connection.SslMode = SslMode.VerifyFull;
        connection.TrustServerCertificate = false;
        connection.Pooling = true;
        connection.MinPoolSize = 0;
        connection.MaxPoolSize = 50;
        connection.Timeout = 15;
        connection.CommandTimeout = 30;
        connection.IncludeErrorDetail = false;
        connection.PersistSecurityInfo = false;
        connection.ApplicationName = "metra-api";

        return connection.ConnectionString;
    }

    public static IServiceCollection AddMetraDatabase(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        var connectionString = BuildConnectionString(
            configuration.GetConnectionString("MetraDatabase"),
            environment.IsDevelopment());

        if (connectionString is not null)
        {
            services.AddSingleton(_ => NpgsqlDataSource.Create(connectionString));
        }

        return services;
    }
}
