namespace Metra.Api.Security;

public static class ApiSecurityConfiguration
{
    public static string[] ValidateCorsOrigins(string[] origins, bool isDevelopment)
    {
        ArgumentNullException.ThrowIfNull(origins);

        if (origins.Length == 0)
        {
            if (!isDevelopment)
            {
                throw new InvalidOperationException(
                    "Cors:AllowedOrigins must contain at least one explicit origin outside Development.");
            }

            return [];
        }

        var validated = new List<string>(origins.Length);
        foreach (var origin in origins)
        {
            if (string.IsNullOrWhiteSpace(origin)
                || origin == "*"
                || !Uri.TryCreate(origin, UriKind.Absolute, out var uri)
                || (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp)
                || (!isDevelopment && uri.Scheme != Uri.UriSchemeHttps)
                || uri.AbsolutePath != "/"
                || !string.IsNullOrEmpty(uri.Query)
                || !string.IsNullOrEmpty(uri.Fragment)
                || uri.UserInfo.Length > 0)
            {
                throw new InvalidOperationException(
                    "Cors:AllowedOrigins contains an invalid origin. Use explicit HTTPS origins in production and explicit HTTP(S) origins in Development, without paths, credentials, query strings, or wildcards.");
            }

            var normalizedOrigin = uri.GetLeftPart(UriPartial.Authority);
            if (!validated.Contains(normalizedOrigin, StringComparer.OrdinalIgnoreCase))
            {
                validated.Add(normalizedOrigin);
            }
        }

        return [.. validated];
    }
}
