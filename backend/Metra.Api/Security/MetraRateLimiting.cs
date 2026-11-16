using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace Metra.Api.Security;

/// <summary>
/// Fixed-window rate limit policies for METRA API.
/// Partition key prefers authenticated subject (sub); falls back to remote IP.
/// </summary>
public static class MetraRateLimiting
{
    public const string PolicyRead = "metra-read";
    public const string PolicyWrite = "metra-write";
    public const string PolicySensitive = "metra-sensitive";
    public const string PolicyAnonymousProbe = "metra-anonymous-probe";

    public static IServiceCollection AddMetraRateLimiting(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, cancellationToken) =>
            {
                context.HttpContext.Response.ContentType = "application/json";
                const string body = "{\"error\":\"rate_limit_exceeded\",\"message\":\"rate limit exceeded\"}";
                await context.HttpContext.Response.WriteAsync(body, cancellationToken);
            };

            options.AddPolicy(PolicyAnonymousProbe, httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    GetPartitionKey(httpContext),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 60,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));

            options.AddPolicy(PolicyRead, httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    GetPartitionKey(httpContext),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 120,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));

            options.AddPolicy(PolicyWrite, httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    GetPartitionKey(httpContext),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 40,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));

            options.AddPolicy(PolicySensitive, httpContext =>
                RateLimitPartition.GetFixedWindowLimiter(
                    GetPartitionKey(httpContext),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 15,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));
        });

        return services;
    }

    public static string GetPartitionKey(HttpContext httpContext)
    {
        var sub = httpContext.User?.FindFirst("sub")?.Value;
        if (!string.IsNullOrWhiteSpace(sub))
            return "user:" + sub;

        var ip = httpContext.Connection.RemoteIpAddress?.ToString();
        if (!string.IsNullOrWhiteSpace(ip))
            return "ip:" + ip;

        return "ip:unknown";
    }
}
