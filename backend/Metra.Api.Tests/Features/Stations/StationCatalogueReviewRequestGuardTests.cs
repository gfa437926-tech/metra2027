using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationCatalogueReviewRequestGuardTests
{
    [Theory]
    [InlineData(null, null, null, true)]
    [InlineData("pending", "approved", "سبب واضح للموافقة", false)]
    [InlineData("pending", "rejected", "بيانات غير مكتملة", false)]
    [InlineData("pending", "changes_requested", "يرجى استكمال الإحداثيات", false)]
    [InlineData("approved", "rejected", "سبب واضح", true)]
    [InlineData("pending", "approve", "سبب واضح", true)]
    [InlineData("pending", "approved", "قصير", true)]
    [InlineData("pending", "approved", " سبب غير صالح ", true)]
    [InlineData("pending", "approved", null, true)]
    public void Guard_accepts_only_pending_station_review_with_valid_reason(
        string? expectedStatus, string? decision, string? reason, bool expectedError)
    {
        var request = expectedStatus is null && decision is null && reason is null
            ? null
            : new StationCatalogueReviewRequest(expectedStatus, decision, reason);
        Assert.Equal(expectedError, StationCatalogueReviewRequestGuard.GetError(request) is not null);
    }

    [Fact]
    public void Guard_rejects_reason_longer_than_2000_characters()
    {
        var request = new StationCatalogueReviewRequest("pending", "approved", new string('x', 2001));
        Assert.Equal("invalid_station_review_reason", StationCatalogueReviewRequestGuard.GetError(request));
    }
}
