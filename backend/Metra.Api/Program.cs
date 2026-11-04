using Metra.Api.Features.Observations;
using Metra.Api.Security;
using Metra.Api.Features.Stations;
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
builder.Services.AddHttpClient(nameof(SupabaseStationAuthorizationService));
builder.Services.AddHttpClient(nameof(SupabaseObservationQueueService));
builder.Services.AddHttpClient(nameof(SupabaseStationDirectoryService));
builder.Services.AddScoped<IStationAuthorizationService, SupabaseStationAuthorizationService>();
builder.Services.AddScoped<IObservationSubmissionService, SupabaseObservationSubmissionService>();
builder.Services.AddScoped<IObservationDecisionService, SupabaseObservationDecisionService>();
builder.Services.AddScoped<IObservationQueueService, SupabaseObservationQueueService>();
builder.Services.AddScoped<IStationDirectoryService, SupabaseStationDirectoryService>();
builder.Services.AddOpenApi();

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
            ValidateIssuerSigningKey = true,
            NameClaimType = "sub",
            ClockSkew = TimeSpan.FromSeconds(60)
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

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
}))
.AllowAnonymous()
.WithName("GetApiHealth");

// Readiness is deliberately separate from liveness. It reports only whether
// server-side Supabase integration is configured; it never exposes secret values.
app.MapGet("/api/v1/ready", async (
    IStationAuthorizationService authorization,
    IObservationSubmissionService submission,
    IObservationDecisionService decision,
    IObservationQueueService queue,
    IStationDirectoryService directory,
    CancellationToken cancellationToken) =>
{
    var configured = authorization.IsConfigured &&
        submission.IsConfigured &&
        decision.IsConfigured &&
        queue.IsConfigured &&
        directory.IsConfigured;

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
