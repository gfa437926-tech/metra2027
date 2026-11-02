using System.Net;
using System.Threading.RateLimiting;
using Metra.Api.Features.Observations;
using Metra.Api.Security;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();
builder.Services.AddMetraAuthorization();

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
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

var api = app.MapGroup("/api/v1");
app.MapObservationValidationEndpoints();

api.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    service = "metra-api",
    version = "v1"
})).WithName("GetApiHealth");

app.Run();

public partial class Program { }
