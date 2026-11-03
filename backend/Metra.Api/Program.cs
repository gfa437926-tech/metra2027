using System.Net;
using System.Threading.RateLimiting;
using Metra.Api.Features.Observations;
using Metra.Api.Features.Stations;
using Metra.Api.Features.Identity;
using Metra.Api.Infrastructure.Database;
using Npgsql;
using Metra.Api.Security;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails();
builder.Services.AddDataProtection();
builder.Services.AddOpenApi();
builder.Services.AddMetraConfiguredAuthentication(builder.Configuration, builder.Environment);
builder.Services.AddMetraAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IRegistrationSubmissionActorContextProvider, HttpRegistrationSubmissionActorContextProvider>();
builder.Services.AddMetraResourceAuthorization();
builder.Services.AddMetraDatabase(builder.Configuration, builder.Environment);
builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);

var hasDatabase = !string.IsNullOrWhiteSpace(
    builder.Configuration.GetConnectionString("MetraDatabase"));
if (hasDatabase)
{
    builder.Services.AddScoped<IRegistrationSubmissionCatalogue, NpgsqlRegistrationSubmissionCatalogue>();
    builder.Services.AddScoped<IRegistrationSubmissionStore, NpgsqlRegistrationSubmissionStore>();
    builder.Services.AddScoped<RegistrationSubmissionApplicationService>();
    builder.Services.AddScoped<IRegistrationApprovalActorContextProvider, NpgsqlRegistrationApprovalActorContextProvider>();
    builder.Services.AddScoped<NpgsqlRegistrationApprovalStore>();
    builder.Services.AddScoped<IRegistrationApprovalStore>(sp => sp.GetRequiredService<NpgsqlRegistrationApprovalStore>());
    builder.Services.AddScoped<IRegistrationApprovalQueueReadStore>(sp => sp.GetRequiredService<NpgsqlRegistrationApprovalStore>());
    builder.Services.AddScoped<RegistrationApprovalApplicationService>();
    builder.Services.AddScoped<RegistrationApprovalQueueQueryService>();
    builder.Services.AddScoped<ICurrentUserContextDataSource, NpgsqlCurrentUserContextDataSource>();
    builder.Services.AddScoped<CurrentUserContextApplicationService>();
    builder.Services.AddScoped<NpgsqlMetraAuthorizationDataSources>();
    builder.Services.AddScoped<IMetraPermissionAuthorizationDataSource>(sp => sp.GetRequiredService<NpgsqlMetraAuthorizationDataSources>());
    builder.Services.AddScoped<IMetraResourceAuthorizationDataSource>(sp => sp.GetRequiredService<NpgsqlMetraAuthorizationDataSources>());
    builder.Services.AddScoped<IMetraActorAuthorizationContextDataSource>(sp => sp.GetRequiredService<NpgsqlMetraAuthorizationDataSources>());
    builder.Services.AddScoped<IMetraPermissionGrantEvaluator, AuthoritativeMetraPermissionGrantEvaluator>();
    builder.Services.AddScoped<IMetraResourceAccessEvaluator, AuthoritativeMetraResourceAccessEvaluator>();
    builder.Services.AddScoped<IMetraActorAuthorizationContextProvider, AuthoritativeMetraActorAuthorizationContextProvider>();
}

var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

var validatedOrigins = ApiSecurityConfiguration.ValidateCorsOrigins(
    allowedOrigins, builder.Environment.IsDevelopment());
builder.Services.AddCors(options =>
{
    options.AddPolicy("MetraClients", policy =>
    {
        if (validatedOrigins.Length > 0)
        {
            policy
                .WithOrigins(validatedOrigins)
                .WithMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .WithHeaders("Accept", "Authorization", "Content-Type", "X-Request-ID");
        }
    });
});

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("RegistrationSubmission", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromHours(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, IPAddress>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress ?? IPAddress.None,
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

var app = builder.Build();

app.UseExceptionHandler();
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseHttpsRedirection();
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        var headers = context.Response.Headers;
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Frame-Options"] = "DENY";
        headers["Referrer-Policy"] = "no-referrer";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        headers["X-Permitted-Cross-Domain-Policies"] = "none";
        headers["Cache-Control"] = "no-store";
        headers["Pragma"] = "no-cache";
        return Task.CompletedTask;
    });

    await next();
});

app.UseRouting();
app.UseCors("MetraClients");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

var api = app.MapGroup("/api/v1");
app.MapObservationValidationEndpoints();
app.MapStationEndpoints();
if (hasDatabase)
{
    app.MapRegistrationSubmissionEndpoints();
    app.MapRegistrationApprovalEndpoints();
    app.MapCurrentUserContextEndpoints();
}

api.MapGet("/ready", async (IServiceProvider services, CancellationToken cancellationToken) =>
{
    var dataSource = services.GetService<NpgsqlDataSource>();
    if (dataSource is null)
    {
        return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
    }

    try
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            select not r.rolsuper
               and not r.rolbypassrls
               and pg_has_role(current_user, 'metra_api_runtime', 'member')
            from pg_roles r
            where r.rolname = current_user
            """,
            connection);
        var leastPrivilegeRuntime = await command.ExecuteScalarAsync(cancellationToken);
        if (leastPrivilegeRuntime is not true)
            return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
        return Results.Ok(new { status = "ready", service = "metra-api" });
    }
    catch (NpgsqlException)
    {
        return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
    }
    catch (TimeoutException)
    {
        return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
    }
}).WithName("GetApiReadiness").AllowAnonymous();

api.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
})).WithName("GetApiHealth").AllowAnonymous();

app.Run();

public partial class Program { }
