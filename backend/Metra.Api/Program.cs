using Metra.Api.Features.Observations;
using Metra.Api.Features.EquipmentFaults;
using Metra.Api.Security;
using Metra.Api.Features.Stations;
using Metra.Api.Features.Users;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using Npgsql;

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
AddBoundedSupabaseClient(builder.Services, SupabaseLegacyHs256AuthenticationHandler.HttpClientName);
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationSubmissionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationDecisionService));
AddBoundedSupabaseClient(builder.Services, nameof(SupabaseObservationQueueService));
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
// Equipment Faults use a dedicated PostgreSQL login. Enforce TLS certificate
// validation even if the supplied connection string is weaker.
var equipmentFaultConnectionString = builder.Configuration["EquipmentFaults:ConnectionString"];
if (!string.IsNullOrWhiteSpace(equipmentFaultConnectionString))
{
    var connectionBuilder = new NpgsqlConnectionStringBuilder(equipmentFaultConnectionString)
    {
        SslMode = SslMode.VerifyFull,
        TrustServerCertificate = false,
        Timeout = 8,
        CommandTimeout = 8,
        Pooling = true
    };
    builder.Services.AddSingleton(NpgsqlDataSource.Create(connectionBuilder.ConnectionString));
    builder.Services.AddScoped<NpgsqlEquipmentFaultStore>();
    builder.Services.AddScoped<IEquipmentFaultStationReader>(sp => sp.GetRequiredService<NpgsqlEquipmentFaultStore>());
    builder.Services.AddScoped<IEquipmentFaultReadStore>(sp => sp.GetRequiredService<NpgsqlEquipmentFaultStore>());
    builder.Services.AddScoped<IEquipmentFaultTransitionWriter>(sp => sp.GetRequiredService<NpgsqlEquipmentFaultStore>());
    builder.Services.AddScoped<IEquipmentFaultSubmissionWriter>(sp => sp.GetRequiredService<NpgsqlEquipmentFaultStore>());
    builder.Services.AddScoped<EquipmentFaultApplicationService>();
    builder.Services.AddScoped<EquipmentFaultReadService>();
    builder.Services.AddScoped<EquipmentFaultTransitionService>();
}
builder.Services.AddOpenApi();

builder.Services
    .AddAuthentication("Supabase")
    .AddPolicyScheme("Supabase", "Supabase ES256 / legacy HS256", options =>
    {
        options.ForwardDefaultSelector = context =>
        {
            var authorization = context.Request.Headers.Authorization.ToString();
            if (authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) &&
                SupabaseLegacyHs256AuthenticationHandler.TryReadAlgorithm(
                    authorization["Bearer ".Length..].Trim(), out var algorithm) &&
                string.Equals(algorithm, "HS256", StringComparison.Ordinal))
            {
                return SupabaseLegacyHs256AuthenticationHandler.SchemeName;
            }

            // All non-HS256 algorithms go through the normal signature verifier.
            // JwtBearer will reject unsupported algorithms; the header is never trusted.
            return JwtBearerDefaults.AuthenticationScheme;
        };
    })
    .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
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
            ValidateIssuerSigningKey = true,
            ValidAlgorithms = new[] { SecurityAlgorithms.EcdsaSha256 },
            NameClaimType = "sub",
            ClockSkew = TimeSpan.FromSeconds(60)
        };
    })
    .AddScheme<AuthenticationSchemeOptions, SupabaseLegacyHs256AuthenticationHandler>(
        SupabaseLegacyHs256AuthenticationHandler.SchemeName, _ => { });

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
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapObservationValidationEndpoints();
app.MapObservationSubmissionEndpoints();
app.MapObservationDecisionEndpoints();
app.MapObservationQueueEndpoints();
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
.WithName("GetApiHealth");

// Readiness is separate from liveness: it verifies server configuration and a
// bounded, server-authenticated Supabase catalogue request without exposing secrets.
app.MapGet("/api/v1/ready", async (
    IStationAuthorizationService authorization,
    IObservationSubmissionService submission,
    IObservationDecisionService decision,
    IObservationQueueService queue,
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
    return probe is not null
        ? Results.Ok(new { status = "ready", service = "metra-api" })
        : Results.Problem(
            title: "Supabase readiness probe failed",
            statusCode: StatusCodes.Status503ServiceUnavailable);
})
.AllowAnonymous()
.WithName("GetApiReadiness");

app.Run();

public partial class Program;
