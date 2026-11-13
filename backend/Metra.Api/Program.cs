using Metra.Api.Features.Observations;
using Metra.Api.Security;
using Metra.Api.Features.Stations;
using Metra.Api.Features.Users;
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
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationQueueService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationArchiveService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationDirectoryService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationCatalogueReviewService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseRegistrationReviewService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseRegistrationSubmissionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationUserDirectoryService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationAuditService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseStationAssignmentService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseAuthorityAccessService));

builder.Services.AddScoped<IStationAuthorizationService, SupabaseStationAuthorizationService>();
builder.Services.AddScoped<IObservationSubmissionService, SupabaseObservationSubmissionService>();
builder.Services.AddScoped<IObservationDecisionService, SupabaseObservationDecisionService>();
builder.Services.AddScoped<IObservationQueueService, SupabaseObservationQueueService>();
builder.Services.AddScoped<IStationDirectoryService, SupabaseStationDirectoryService>();
builder.Services.AddScoped<IStationAssignmentService, SupabaseStationAssignmentService>();
builder.Services.AddScoped<IAuthorityAccessService, SupabaseAuthorityAccessService>();
builder.Services.AddScoped<IStationUserDirectoryService, SupabaseStationUserDirectoryService>();
builder.Services.AddScoped<IStationAuditService, SupabaseStationAuditService>();
builder.Services.AddScoped<IRegistrationSubmissionService, SupabaseRegistrationSubmissionService>();
builder.Services.AddScoped<IRegistrationReviewService, SupabaseRegistrationReviewService>();
builder.Services.AddScoped<IStationCatalogueReviewService, SupabaseStationCatalogueReviewService>();
builder.Services.AddScoped<IObservationArchiveService, SupabaseObservationArchiveService>();
builder.Services.AddOpenApi();
var rateLimitingDisabled = builder.Configuration.GetValue("RateLimiting:Disabled", false);
if (!rateLimitingDisabled)
    builder.Services.AddMetraRateLimiting();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = authority;
        options.Audience = audience;
        options.RequireHttpsMetadata = true;
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = authority,
            ValidateAudience = true,
            ValidAudience = audience,
            ValidateLifetime = true,
            RequireExpirationTime = true,
            ValidateIssuerSigningKey = true,
            NameClaimType = "sub",
            ClockSkew = TimeSpan.FromSeconds(60),
            // Supabase Auth issues asymmetric JWTs (RS256/ES256). Reject none/HS by omission.
            ValidAlgorithms = ["RS256", "ES256"]
        };
    });

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
app.UseHttpsRedirection();
app.UseCors("MetraClients");
app.Use(async (context, next) =>
{
    context.Response.Headers.TryAdd("X-Content-Type-Options", "nosniff");
    context.Response.Headers.TryAdd("X-Frame-Options", "DENY");
    context.Response.Headers.TryAdd("Referrer-Policy", "no-referrer");
    context.Response.Headers.TryAdd("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
    await next();
});

// Authenticate first so per-user rate-limit partitions can read the validated JWT subject.
app.UseAuthentication();
if (!rateLimitingDisabled)
    app.UseRateLimiter();
app.UseAuthorization();

// OpenAPI document: Development always; other environments only when OpenApi:Enabled=true.
// Do not enable anonymously on public production without an edge auth layer.
var openApiEnabled = app.Environment.IsDevelopment()
    || app.Configuration.GetValue("OpenApi:Enabled", false);
if (openApiEnabled)
{
    app.MapOpenApi();
}

app.MapObservationValidationEndpoints();
app.MapObservationSubmissionEndpoints();
app.MapObservationDecisionEndpoints();
app.MapObservationQueueEndpoints();
app.MapObservationArchiveEndpoints();
app.MapStationDirectoryEndpoints();
app.MapStationCatalogueReviewEndpoints();
app.MapRegistrationReviewEndpoints();
app.MapRegistrationSubmissionEndpoints();
app.MapStationUserDirectoryEndpoints();
app.MapStationAuditEndpoints();
app.MapStationAssignmentEndpoints();
app.MapAuthorityAccessEndpoints();

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
}))
.AllowAnonymous()
.RequireRateLimiting(MetraRateLimiting.PolicyAnonymousProbe)
.WithName("GetApiHealth");

// Readiness is separate from liveness: it verifies server configuration, a
// bounded catalogue request, and both protected archive RPC entry points without exposing secrets.
app.MapGet("/api/v1/ready", async (
    IStationAuthorizationService authorization,
    IObservationSubmissionService submission,
    IObservationDecisionService decision,
    IObservationQueueService queue,
    IObservationArchiveService archive,
    IStationDirectoryService directory,
    IStationCatalogueReviewService stationReview,
    IRegistrationReviewService registrationReview,
    IRegistrationSubmissionService registrationSubmission,
    IStationUserDirectoryService stationUsers,
    IStationAssignmentService stationAssignments,
    IStationAuditService stationAudit,
    IAuthorityAccessService authorityAccess,
    CancellationToken cancellationToken) =>
{
    var configured = authorization.IsConfigured &&
        submission.IsConfigured &&
        decision.IsConfigured &&
        queue.IsConfigured &&
        archive.IsConfigured &&
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

    // Verify an authenticated server-side PostgREST round trip, not merely
    // non-empty environment variables. A schema, credential, or network
    // failure must keep the instance out of service.
    var probe = await directory.GetStationsAsync(1, 0, null, cancellationToken);
    var archiveProbe = probe is not null && await archive.ProbeAsync(cancellationToken);
    var submissionRpcProbe = archiveProbe && await submission.ProbeAsync(cancellationToken);
    var decisionRpcProbe = submissionRpcProbe && await decision.ProbeAsync(cancellationToken);
    return probe is not null && archiveProbe && submissionRpcProbe && decisionRpcProbe
        ? Results.Ok(new { status = "ready", service = "metra-api" })
        : Results.Problem(
            title: "Supabase readiness probe failed",
            detail = "One or more required database RPC contracts are missing or not executable.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
})
.AllowAnonymous()
.RequireRateLimiting(MetraRateLimiting.PolicyAnonymousProbe)
.WithName("GetApiReadiness");

app.Run();

public partial class Program;
