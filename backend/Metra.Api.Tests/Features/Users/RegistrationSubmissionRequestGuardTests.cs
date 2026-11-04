using System.Text.Json;
using Metra.Api.Features.Users;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class RegistrationSubmissionRequestGuardTests
{
    private static RegistrationSubmissionRequest Valid() => new(
        "إبراهيم", "محمد", "علي", null, "observer",
        Guid.Parse("11111111-1111-4111-8111-111111111111"),
        RegistrationSubmissionRequestGuard.TermsVersion, "request-key-0001");

    [Fact]
    public void Accepts_a_complete_requestable_role_submission_shape()
    {
        Assert.Null(RegistrationSubmissionRequestGuard.GetError(Valid()));
    }

    [Theory]
    [InlineData("", "محمد", "علي", "invalid_registration_name")]
    [InlineData("إبراهيم", null, "علي", "invalid_registration_name")]
    [InlineData("إبراهيم", "محمد", " ", "invalid_registration_name")]
    public void Rejects_missing_or_blank_required_names(string? first, string? father, string? last, string expected)
    {
        var request = Valid() with { FirstName = first, FatherName = father, LastName = last };
        Assert.Equal(expected, RegistrationSubmissionRequestGuard.GetError(request));
    }

    [Fact]
    public void Rejects_invalid_station_and_terms()
    {
        Assert.Equal("invalid_registration_station",
            RegistrationSubmissionRequestGuard.GetError(Valid() with { StationId = Guid.Empty }));
        Assert.Equal("invalid_registration_terms",
            RegistrationSubmissionRequestGuard.GetError(Valid() with { TermsVersion = "old-terms" }));
    }

    [Fact]
    public void Rejects_control_characters_in_optional_phone()
    {
        Assert.Equal("invalid_registration_phone",
            RegistrationSubmissionRequestGuard.GetError(Valid() with { Phone = "123\n456" }));
    }

    [Theory]
    [InlineData("[{\"result_status\":\"created\"}]", "created")]
    [InlineData("[{\"result_status\":\"already_created\"}]", "already_created")]
    [InlineData("[]", null)]
    [InlineData("{}", null)]
    public void Reads_only_the_registration_RPC_status(string json, string? expected)
    {
        using var document = JsonDocument.Parse(json);
        Assert.Equal(expected, RegistrationSubmissionRpcResult.GetStatus(document.RootElement));
    }
}
