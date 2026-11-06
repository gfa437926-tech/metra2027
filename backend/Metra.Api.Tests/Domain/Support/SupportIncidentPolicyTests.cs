using Metra.Api.Domain.Support;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class SupportIncidentPolicyTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 8, 0, 0, TimeSpan.Zero);

    private static SupportIncidentReport ValidReport(
        SupportIncidentSeverity severity = SupportIncidentSeverity.High,
        bool impactsOperations = false,
        SupportIncidentKind kind = SupportIncidentKind.InformationTechnology) =>
        new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            kind,
            "الشبكة والاتصال",
            "انقطاع الاتصال عن نظام المحطة",
            "تعذر على فريق المحطة الوصول إلى النظام منذ بداية الوردية.",
            "موجّه الشبكة",
            severity,
            Now.AddMinutes(-15),
            impactsOperations);

    [Fact]
    public void Accepts_valid_it_incident() =>
        Assert.Empty(SupportIncidentPolicy.Validate(ValidReport(), Now));

    [Fact]
    public void Accepts_valid_telecommunications_incident() =>
        Assert.Empty(SupportIncidentPolicy.Validate(
            ValidReport(kind: SupportIncidentKind.Telecommunications), Now));

    [Fact]
    public void Rejects_missing_station_and_reporter()
    {
        var report = ValidReport() with { StationId = Guid.Empty, ReporterUserId = Guid.Empty };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.StationId));
        Assert.Contains(issues, issue => issue.Field == nameof(report.ReporterUserId));
    }

    [Fact]
    public void Rejects_invalid_kind_and_severity_values()
    {
        var report = ValidReport() with
        {
            Kind = (SupportIncidentKind)999,
            Severity = (SupportIncidentSeverity)999
        };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.Kind));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Severity));
    }

    [Fact]
    public void Rejects_short_title_and_description()
    {
        var report = ValidReport() with { Title = "عطل", Description = "لا يعمل" };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.Title));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Description));
    }

    [Fact]
    public void Rejects_null_required_text_fields()
    {
        var report = ValidReport() with
        {
            Category = null!,
            Title = null!,
            Description = null!
        };

        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.Category));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Title));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Description));
    }

    [Fact]
    public void Rejects_blank_category_title_and_description()
    {
        var report = ValidReport() with { Category = "  ", Title = "     ", Description = "\t " };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.Category));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Title));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Description));
    }

    [Fact]
    public void Rejects_text_fields_over_their_limits()
    {
        var report = ValidReport() with
        {
            Category = new string('c', 81),
            Title = new string('t', 161),
            Description = new string('d', 5001),
            AffectedAsset = new string('a', 161)
        };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.Category));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Title));
        Assert.Contains(issues, issue => issue.Field == nameof(report.Description));
        Assert.Contains(issues, issue => issue.Field == nameof(report.AffectedAsset));
    }

    [Fact]
    public void Rejects_future_occurrence_time()
    {
        var report = ValidReport() with { OccurredAt = Now.AddMinutes(6) };
        Assert.Contains(SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.OccurredAt));
    }

    [Fact]
    public void Accepts_occurrence_at_five_minute_future_boundary() =>
        Assert.Empty(SupportIncidentPolicy.Validate(
            ValidReport() with { OccurredAt = Now.AddMinutes(5) }, Now));

    [Fact]
    public void Rejects_default_occurrence_time()
    {
        var report = ValidReport() with { OccurredAt = default };
        Assert.Contains(SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.OccurredAt));
    }

    [Fact]
    public void Operationally_impacting_incident_requires_high_or_critical_severity()
    {
        var report = ValidReport(SupportIncidentSeverity.Normal, impactsOperations: true);
        Assert.Contains(SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.Severity));
    }

    [Fact]
    public void Allows_optional_affected_asset_to_be_null() =>
        Assert.Empty(SupportIncidentPolicy.Validate(
            ValidReport() with { AffectedAsset = null }, Now));

    [Theory]
    [InlineData("   ")]
    [InlineData("\t\n")]
    public void Rejects_blank_optional_affected_asset(string asset)
    {
        var report = ValidReport() with { AffectedAsset = asset };
        Assert.Contains(SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.AffectedAsset));
    }

    [Fact]
    public void Accepts_affected_asset_at_160_character_boundary() =>
        Assert.Empty(SupportIncidentPolicy.Validate(
            ValidReport() with { AffectedAsset = new string('a', 160) }, Now));

    [Fact]
    public void Rejects_null_report() =>
        Assert.Throws<ArgumentNullException>(() =>
            SupportIncidentPolicy.Validate(null!, Now));

    [Theory]
    [InlineData(SupportIncidentStatus.Submitted, SupportIncidentStatus.UnderReview, true)]
    [InlineData(SupportIncidentStatus.Submitted, SupportIncidentStatus.Rejected, true)]
    [InlineData(SupportIncidentStatus.UnderReview, SupportIncidentStatus.Assigned, true)]
    [InlineData(SupportIncidentStatus.UnderReview, SupportIncidentStatus.Rejected, true)]
    [InlineData(SupportIncidentStatus.Assigned, SupportIncidentStatus.InProgress, true)]
    [InlineData(SupportIncidentStatus.Assigned, SupportIncidentStatus.UnderReview, true)]
    [InlineData(SupportIncidentStatus.InProgress, SupportIncidentStatus.WaitingForInformation, true)]
    [InlineData(SupportIncidentStatus.WaitingForInformation, SupportIncidentStatus.InProgress, true)]
    [InlineData(SupportIncidentStatus.InProgress, SupportIncidentStatus.Resolved, true)]
    [InlineData(SupportIncidentStatus.Resolved, SupportIncidentStatus.Closed, true)]
    [InlineData(SupportIncidentStatus.Resolved, SupportIncidentStatus.InProgress, true)]
    [InlineData(SupportIncidentStatus.Closed, SupportIncidentStatus.InProgress, false)]
    [InlineData(SupportIncidentStatus.Rejected, SupportIncidentStatus.Assigned, false)]
    [InlineData(SupportIncidentStatus.Submitted, SupportIncidentStatus.Closed, false)]
    public void Enforces_incident_lifecycle(
        SupportIncidentStatus current,
        SupportIncidentStatus next,
        bool expected) =>
        Assert.Equal(expected, SupportIncidentPolicy.CanTransition(current, next));

    [Fact]
    public void Rejects_undefined_lifecycle_values() =>
        Assert.False(SupportIncidentPolicy.CanTransition(
            (SupportIncidentStatus)999, SupportIncidentStatus.Assigned));
}
