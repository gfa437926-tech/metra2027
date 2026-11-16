using System.Net;
using System.Text.Json;
using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationCatalogueReviewResponseParserTests
{
    [Fact]
    public void Updated_rpc_row_is_a_successful_review()
    {
        using var document = JsonDocument.Parse(
            """[{"result_status":"updated","resulting_status":"approved"}]""");

        var result = StationCatalogueReviewResponseParser.Parse(HttpStatusCode.OK, document.RootElement);

        Assert.True(result.IsConfigured);
        Assert.True(result.Succeeded);
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal("updated", result.Data!.Value.GetProperty("result_status").GetString());
        Assert.Equal("approved", result.Data.Value.GetProperty("resulting_status").GetString());
    }

    [Fact]
    public void State_conflict_rpc_row_maps_to_http_conflict()
    {
        using var document = JsonDocument.Parse(
            """[{"result_status":"state_conflict","resulting_status":"approved"}]""");

        var result = StationCatalogueReviewResponseParser.Parse(HttpStatusCode.OK, document.RootElement);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.Conflict, result.StatusCode);
        Assert.Equal("approved", result.Data!.Value.GetProperty("resulting_status").GetString());
    }

    [Theory]
    [InlineData("[]")]
    [InlineData("[{},{}]")]
    [InlineData("[{\"result_status\":\"updated\"}]")]
    [InlineData("[{\"result_status\":\"unexpected\",\"resulting_status\":\"pending\"}]")]
    public void Invalid_or_unexpected_rpc_rows_fail_closed(string json)
    {
        using var document = JsonDocument.Parse(json);

        var result = StationCatalogueReviewResponseParser.Parse(HttpStatusCode.OK, document.RootElement);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, result.StatusCode);
        Assert.Null(result.Data);
    }

    [Fact]
    public void Non_success_http_status_is_preserved()
    {
        using var document = JsonDocument.Parse("{}");

        var result = StationCatalogueReviewResponseParser.Parse(HttpStatusCode.Forbidden, document.RootElement);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.Forbidden, result.StatusCode);
        Assert.Null(result.Data);
    }
}
