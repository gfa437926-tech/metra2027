using Metra.Api.Features.Observations;

namespace Metra.Api.Tests.Features.Observations;

public sealed class HourlyObservationContractValidatorTests
{
    [Fact]
    public void Submission_RejectsMissingDate()
    {
        var request = ValidSubmission() with { ObservationDate = default };

        var errors = HourlyObservationContractValidator.ValidateSubmission(request);

        Assert.Contains(errors, error => error.Contains("تاريخ الرصد"));
    }

    [Fact]
    public void Submission_RejectsHourOutsideUtcDay()
    {
        var request = ValidSubmission() with { UtcHour = 24 };

        var errors = HourlyObservationContractValidator.ValidateSubmission(request);

        Assert.Contains(errors, error => error.Contains("00 و23"));
    }

    [Fact]
    public void Submission_RejectsPayloadHourMismatch()
    {
        var request = ValidSubmission() with
        {
            Values = new Dictionary<string, string?> { ["utcTime"] = "06" }
        };

        var errors = HourlyObservationContractValidator.ValidateSubmission(request);

        Assert.Contains(errors, error => error.Contains("لا تطابق"));
    }

    [Fact]
    public void Submission_DoesNotAcceptClientStationIdentifier()
    {
        var request = ValidSubmission();
        Assert.DoesNotContain("StationId", typeof(CreateHourlyObservationRequest)
            .GetProperties().Select(property => property.Name));
    }

    [Fact]
    public void Review_RequiresReasonWhenRejecting()
    {
        var request = new HourlyObservationReviewRequest(
            HourlyObservationReviewDecision.Reject, "  ");

        var errors = HourlyObservationContractValidator.ValidateReview(request);

        Assert.Contains(errors, error => error.Contains("سبب رفض"));
    }

    [Fact]
    public void Review_RejectsOversizedNote()
    {
        var request = new HourlyObservationReviewRequest(
            HourlyObservationReviewDecision.Approve,
            new string('x', HourlyObservationContractValidator.MaximumReviewNoteLength + 1));

        var errors = HourlyObservationContractValidator.ValidateReview(request);

        Assert.Contains(errors, error => error.Contains("1000"));
    }

    private static CreateHourlyObservationRequest ValidSubmission()
        => new(
            new DateOnly(2026, 11, 5),
            0,
            new Dictionary<string, string?> { ["utcTime"] = "00" });
}
