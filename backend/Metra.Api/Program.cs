using Metra.Api.Features.Observations;
using Metra.Api.Features.Maintenance;
using Metra.Api.Features.Support;
using Metra.Api.Security;
using Metra.Api.Infrastructure.Persistence;
using Metra.Api.Features.Stations;
using Metra.Api.Features.Users;
using Metra.Api.Features.Archive;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var supabaseUrl = builder.Configuration["Supabase:Url"]
    ?? "https://tbdnklyxjvbrilvnwgmq.supabase.co";
var authority = builder.Configuration["Authentication:Authority"]
    ?? $"{supabaseUrl.TrimEnd('/')}/auth/v1";
var audience = builder.Configuration["Authentication:Audience"] ?? "authenticated";

builder.Services.AddProblemDetails();
// Bound every server-side Supabase request. A stalled dependency must not
// hold an API request or authorization decision open for HttpClient's 100s default.
static void AddBoundedSupabaseClient(IServiceCollection services, string name) =>
    services.AddHttpClient(name, client => client.Timeout = TimeSpan.FromSeconds(8));

AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationAuthorizationService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationSubmissionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationDecisionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationResubmitService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationReturnedQueueService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationQueueService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationDirectoryService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationCatalogueReviewService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseRegistrationReviewService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseRegistrationSubmissionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationUserDirectoryService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationAuditService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationAssignmentService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseAuthorityAccessService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseEquipmentFaultService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseSupportIncidentService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseAccessTokenValidator));

builder.Services.AddScoped<IStationAuthorizationService, SupabaseStationAuthorizationService>();
builder.Services.AddScoped<IObservationSubmissionService, SupabaseObservationSubmissionService>();
builder.Services.AddScoped<IObservationDecisionService, SupabaseObservationDecisionService>();
builder.Services.AddScoped<IObservationResubmitService, SupabaseObservationResubmitService>();
builder.Services.AddScoped<IObservationReturnedQueueService, SupabaseObservationReturnedQueueService>();
builder.Services.AddScoped<IObservationQueueService, SupabaseObservationQueueService>();
builder.Services.AddScoped<IStationDirectoryService, SupabaseStationDirectoryService>();
builder.Services.AddScoped<IStationAssignmentService, SupabaseStationAssignmentService>();
builder.Services.AddScoped<IAuthorityAccessService, SupabaseAuthorityAccessService>();
// Prefer direct Npgsql ops connection when configured; otherwise Supabase RPC/REST path.
builder.Services.AddScoped<IEquipmentFaultService>(sp =>
{
    var configuration = sp.GetRequiredService<IConfiguration>();
    var auth = sp.GetRequiredService<IStationAuthorizationService>();
    if (!string.IsNullOrWhiteSpace(configuration.GetConnectionString("MetraOps")))
        return new NpgsqlEquipmentFaultService(configuration, auth);
    return ActivatorUtilities.CreateInstance<SupabaseEquipmentFaultService>(sp);
});
builder.Services.AddScoped<ISupportIncidentService>(sp =>
{
    var configuration = sp.GetRequiredService<IConfiguration>();
    var auth = sp.GetRequiredService<IStationAuthorizationService>();
    if (!string.IsNullOrWhiteSpace(configuration.GetConnectionString("MetraOps")))
        return new NpgsqlSupportIncidentService(configuration, auth);
    return ActivatorUtilities.CreateInstance<SupabaseSupportIncidentService>(sp);
});
builder.Services.AddSingleton<ISupabaseAccessTokenValidator, SupabaseAccessTokenValidator>();
builder.Services.AddSingleton<IManualArchiveLedgerService, InMemoryManualArchiveLedgerService>();
builder.Services.AddScoped<IStationUserDirectoryService, SupabaseStationUserDirectoryService>();
builder.Services.AddScoped<IStationAuditService, SupabaseStationAuditService>();
builder.Services.AddScoped<IRegistrationSubmissionService, SupabaseRegistrationSubmissionService>();
builder.Services.AddScoped<IRegistrationReviewService, SupabaseRegistrationReviewService>();
builder.Services.AddScoped<IStationCatalogueReviewService, SupabaseStationCatalogueReviewService>();
builder.Services.AddOpenApi();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
        MetraJwtBearerConfiguration.Configure(options, builder.Configuration, authority, audience));

builder.Services.AddAuthorization(options =>
{
    // All endpoints require a valid Supabase access token unless explicitly anonymous.
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("MetraClients", policy =>
    {
        var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        if (origins.Length > 0)
        {
            policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

var app = builder.Build();

app.UseExceptionHandler();
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}
app.UseHttpsRedirection();

// Apply a consistent defensive header baseline to every API response.
// API payloads may contain operational and personal data, so they must not
// be cached by browsers or intermediary caches.
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        var headers = context.Response.Headers;
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Frame-Options"] = "DENY";
        headers["Referrer-Policy"] = "no-referrer";
        headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
        headers["Cache-Control"] = "no-store";
        headers["Pragma"] = "no-cache";
        return Task.CompletedTask;
    });

    await next();
});

app.UseCors("MetraClients");
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapObservationValidationEndpoints();
app.MapObservationSubmissionEndpoints();
app.MapObservationDecisionEndpoints();
app.MapObservationResubmitEndpoints();
app.MapObservationReturnedQueueEndpoints();
app.MapEquipmentFaultEndpoints();
app.MapSupportIncidentEndpoints();
app.MapObservationQueueEndpoints();
app.MapStationDirectoryEndpoints();
app.MapStationCatalogueReviewEndpoints();
app.MapRegistrationReviewEndpoints();
app.MapRegistrationSubmissionEndpoints();
app.MapStationUserDirectoryEndpoints();
app.MapStationAuditEndpoints();
app.MapStationAssignmentEndpoints();
app.MapManualArchiveEndpoints();
app.MapAuthorityAccessEndpoints();

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
}))
.AllowAnonymous()
.WithName("GetApiHealth");

// Readiness is separate from liveness: it verifies server configuration and a
// bounded, server-authenticated Supabase catalogue request without exposing secrets.
app.MapGet("/api/v1/ready", async (
    IConfiguration configuration,
    IStationAuthorizationService authorization,
    IObservationSubmissionService submission,
    IObservationDecisionService decision,
    IObservationResubmitService resubmit,
    IObservationReturnedQueueService returnedQueue,
    IObservationQueueService queue,
    IStationDirectoryService directory,
    IStationCatalogueReviewService stationReview,
    IRegistrationReviewService registrationReview,
    IRegistrationSubmissionService registrationSubmission,
    IStationUserDirectoryService stationUsers,
    IStationAssignmentService stationAssignments,
    IStationAuditService stationAudit,
    IAuthorityAccessService authorityAccess,
    IEquipmentFaultService equipmentFaults,
    ISupportIncidentService supportIncidents,
    CancellationToken cancellationToken) =>
{
    var configured = authorization.IsConfigured &&
        submission.IsConfigured &&
        decision.IsConfigured &&
        resubmit.IsConfigured &&
        returnedQueue.IsConfigured &&
        queue.IsConfigured &&
        directory.IsConfigured &&
        stationReview.IsConfigured &&
        registrationReview.IsConfigured &&
        registrationSubmission.IsConfigured &&
        stationUsers.IsConfigured &&
        stationAssignments.IsConfigured &&
        stationAudit.IsConfigured &&
        authorityAccess.IsConfigured;

    if (!configured)
        return Results.Problem(
            title: "API dependencies are not configured",
            statusCode: StatusCodes.Status503ServiceUnavailable);

    // When MetraOps is configured, readiness must prove the Npgsql path is live.
    // An empty connection string means ops still rely on Supabase-only adapters.
    var metraOps = configuration.GetConnectionString("MetraOps");
    if (!string.IsNullOrWhiteSpace(metraOps))
    {
        if (!equipmentFaults.IsConfigured)
            return Results.Problem(
                title: "MetraOps equipment fault adapter is not configured",
                statusCode: StatusCodes.Status503ServiceUnavailable);

        if (!supportIncidents.IsConfigured)
            return Results.Problem(
                title: "MetraOps support incident adapter is not configured",
                statusCode: StatusCodes.Status503ServiceUnavailable);

        var opsOk = await NpgsqlOpsSession.CanConnectAsync(metraOps, cancellationToken);
        if (!opsOk)
            return Results.Problem(
                title: "MetraOps database readiness probe failed",
                statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    // Verify an authenticated server-side PostgREST round trip, not merely
    // non-empty environment variables. A schema, credential, or network
    // failure must keep the instance out of service.
    var probe = await directory.GetStationsAsync(1, 0, null, cancellationToken);
    return probe is not null
        ? Results.Ok(new
        {
            status = "ready",
            service = "metra-api",
            metraOps = string.IsNullOrWhiteSpace(metraOps) ? "not_configured" : "reachable"
        })
        : Results.Problem(
            title: "Supabase readiness probe failed",
            statusCode: StatusCodes.Status503ServiceUnavailable);
})
.AllowAnonymous()
.WithName("GetApiReadiness");

app.Run();

public partial class Program;
