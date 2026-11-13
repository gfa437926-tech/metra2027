using Xunit;
using System.Net;
using Metra.Api.Features.Users;

namespace Metra.Api.Tests.Features.Users;

public sealed class AuthorityAccessConflictDetectorTests
{
    [Theory]
    [InlineData("""{"code":"23505","message":"duplicate key value violates unique constraint \"permission_grants_active_station_unique\""}""")]
    [InlineData("""{"code":"23505","details":null,"hint":null,"message":"duplicate key"}""")]
    [InlineData("ERROR: duplicate key value violates unique constraint \"permission_grants_active_authority_unique\"")]
    [InlineData("unique_violation on permission_grants")]
    public void Detects_unique_violation_bodies(string body)
    {
        Assert.True(AuthorityAccessConflictDetector.IsUniqueViolation(body, HttpStatusCode.InternalServerError));
        Assert.True(AuthorityAccessConflictDetector.IsUniqueViolation(body, HttpStatusCode.BadRequest));
    }

    [Fact]
    public void Empty_body_with_http_409_is_treated_as_conflict()
    {
        Assert.True(AuthorityAccessConflictDetector.IsUniqueViolation(null, HttpStatusCode.Conflict));
        Assert.True(AuthorityAccessConflictDetector.IsUniqueViolation(" ", HttpStatusCode.Conflict));
    }

    [Theory]
    [InlineData("""{"code":"42501","message":"permission denied"}""")]
    [InlineData("""{"code":"22023","message":"invalid_authority_permission_request"}""")]
    [InlineData("connection refused")]
    [InlineData("")]
    [InlineData(null)]
    public void Does_not_classify_non_unique_errors(string? body)
    {
        Assert.False(AuthorityAccessConflictDetector.IsUniqueViolation(body, HttpStatusCode.InternalServerError));
        Assert.False(AuthorityAccessConflictDetector.IsUniqueViolation(body, HttpStatusCode.BadRequest));
        Assert.False(AuthorityAccessConflictDetector.IsUniqueViolation(body, null));
    }
}
