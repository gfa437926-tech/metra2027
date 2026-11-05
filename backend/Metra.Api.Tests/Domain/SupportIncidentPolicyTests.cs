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
        Assert.Empty(SupportIncidentPolicy.Validate(ValidReport(kind: SupportIncidentKind.Telecommunications), Now));

    [Fact]
    public void Rejects_missing_station_and_reporter() 
    {
        var report = ValidReport() with { StationId = Guid.Empty, ReporterUserId = Guid.Empty };
        var issues = SupportIncidentPolicy.Validate(report, Now);
        Assert.Contains(issues, issue => issue.Field == nameof(report.StationId));
        Assert.Contains(issues, issue => issue.Field == nameof(report.ReporterUserId));
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
    public void Rejects_future_occurrence_time()
    {
        var report = ValidReport() with { OccurredAt = Now.AddMinutes(6) };
        Assert.Contains(
            SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.OccurredAt));
    }

    [Fact]
    public void Operationally_impacting_incident_requires_high_or_critical_severity()
    {
        var report = ValidReport(SupportIncidentSeverity.Normal, impactsOperations: true);
        Assert.Contains(
            SupportIncidentPolicy.Validate(report, Now),
            issue => issue.Field == nameof(report.Severity));
    }

    [Theory]
    [InlineData(SupportIncidentStatus.Submitted, SupportIncidentStatus.UnderReview, true)]
    [InlineData(SupportIncidentStatus.UnderReview, SupportIncidentStatus.Assigned, true)]
    [InlineData(SupportIncidentStatus.Assigned, SupportIncidentStatus.InProgress, true)]
    [InlineData(SupportIncidentStatus.InProgress, SupportIncidentStatus.WaitingForInformation, true)]
    [InlineData(SupportIncidentStatus.WaitingForInformation, SupportIncidentStatus.InProgress, true)]
    [InlineData(SupportIncidentStatus.InProgress, SupportIncidentStatus.Resolved, true)]
    [InlineData(SupportIncidentStatus.Resolved, SupportIncidentStatus.Closed, true)]
    [InlineData(SupportIncidentStatus.Closed, SupportIncidentStatus.InProgress, false)]
    [InlineData(SupportIncidentStatus.Rejected, SupportIncidentStatus.Assigned, false)]
    public void Enforces_incident_lifecycle(
        SupportIncidentStatus current,
        SupportIncidentStatus next,
        bool expected) =>
        Assert.Equal(expected, SupportIncidentPolicy.CanTransition(current, next));
}
