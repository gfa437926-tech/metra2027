using System.Security.Claims;
using Metra.Api.Features.Identity;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace Metra.Api.Tests.Features.Identity;

public sealed class HttpRegistrationSubmissionActorContextProviderTests
{
    private static readonly Guid AuthUserId =
        Guid.Parse("d6a3a9a4-4e3e-4d2f-9f5b-6d3c4a8f1234");

    [Fact]
    public async Task Returns_null_without_http_context()
    {
        var provider = CreateProvider(context: null);

        var result = await provider.GetCurrentAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task Returns_null_for_anonymous_principal_even_with_uuid_subject()
    {
        var context = new DefaultHttpContext();
        context.User = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim("sub", AuthUserId.ToString())]));

        var result = await CreateProvider(context).GetCurrentAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-a-uuid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public async Task Rejects_missing_or_invalid_subject(string? subject)
    {
        Claim[] claims = subject is null
            ? []
            : [new Claim("sub", subject)];
        var context = AuthenticatedContext(claims);

        var result = await CreateProvider(context).GetCurrentAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task Does_not_fall_back_to_name_identifier_when_sub_is_missing()
    {
        var context = AuthenticatedContext(
            [new Claim(ClaimTypes.NameIdentifier, AuthUserId.ToString())]);

        var result = await CreateProvider(context).GetCurrentAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task Returns_uuid_from_validated_authenticated_sub_claim()
    {
        var context = AuthenticatedContext([new Claim("sub", AuthUserId.ToString())]);

        var result = await CreateProvider(context).GetCurrentAsync(CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal(AuthUserId, result.AuthUserId);
        Assert.True(result.IsAuthenticated);
    }

    [Fact]
    public async Task Observes_request_cancellation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            CreateProvider(AuthenticatedContext([new Claim("sub", AuthUserId.ToString())]))
                .GetCurrentAsync(cancellation.Token));
    }

    private static HttpRegistrationSubmissionActorContextProvider CreateProvider(
        HttpContext? context)
        => new(new HttpContextAccessor { HttpContext = context });

    private static DefaultHttpContext AuthenticatedContext(IEnumerable<Claim> claims)
    {
        var context = new DefaultHttpContext();
        context.User = new ClaimsPrincipal(
            new ClaimsIdentity(claims, authenticationType: "validated-jwt"));
        return context;
    }
}
