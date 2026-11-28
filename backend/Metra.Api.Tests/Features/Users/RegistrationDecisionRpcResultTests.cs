using System.Text.Json;
using Metra.Api.Features.Users;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class RegistrationDecisionRpcResultTests
{
    [Theory]
    [InlineData("[{\"result_status\":\"committed\",\"resulting_status\":\"active\"}]", "committed")]
    [InlineData("[{\"result_status\":\"unauthorized\",\"resulting_status\":null}]", "unauthorized")]
    [InlineData("[{\"result_status\":\"not_found\",\"resulting_status\":null}]", "not_found")]
    [InlineData("[{\"result_status\":\"conflict\",\"resulting_status\":\"pending_system_approval\"}]", "conflict")]
    [InlineData("[]", null)]
    [InlineData("{}", null)]
    [InlineData("null", null)]
    public void Reads_only_the_explicit_rpc_result_status(string json, string? expected)
    {
        using var document = JsonDocument.Parse(json);
        Assert.Equal(expected, RegistrationDecisionRpcResult.GetStatus(document.RootElement));
    }
}
