using Metra.Api.Features.Observations;
using Metra.Api.Security;
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
builder.Services.AddScoped<IStationAuthorizationService, SupabaseStationAuthorizationService>();
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

app.MapGet("/api/v1/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
}))
.AllowAnonymous()
.WithName("GetApiHealth");

app.Run();

public partial class Program;
