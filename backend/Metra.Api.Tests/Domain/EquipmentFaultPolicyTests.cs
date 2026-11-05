using Metra.Api.Domain.Maintenance;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class EquipmentFaultPolicyTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 8, 0, 0, TimeSpan.Zero);

    private static EquipmentFaultReport ValidReport(
        EquipmentFaultSeverity severity = EquipmentFaultSeverity.High,
        bool blocking = false) =>
        new(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "أجهزة الرصد",
            "مقياس الحرارة",
            "توقف الجهاز عن إرسال القراءات منذ بداية الوردية.",
            severity,
            Now.AddMinutes(-20),
            blocking);

    [Fact]
    public void Accepts_a_well_formed_report()
    {
        Assert.Empty(EquipmentFaultPolicy.Validate(ValidReport(), Now));
    }

    [Fact]
    public void Rejects_missing_station_or_reporter_identity()
    {
        var report = ValidReport() with { StationId = Guid.Empty, ReporterUserId = Guid.Empty };

        var issues = EquipmentFaultPolicy.Validate(report, Now);

        Assert.Contains(issues, issue => issue.Field == nameof(report.StationId));
        Assert.Contains(issues, issue => issue.Field == nameof(report.ReporterUserId));
    }

    [Theory]
    [InlineData("")]
    [InlineData("x")]
    public void Rejects_missing_or_too_short_equipment_category(string category)
    {
        var report = ValidReport() with { EquipmentCategory = category };

        var issues = EquipmentFaultPolicy.Validate(report, Now);

        Assert.Contains(issues, issue => issue.Field == nameof(report.EquipmentCategory));
    }

    [Fact]
    public void Rejects_descriptions_that_are_too_short()
    {
        var report = ValidReport() with { Description = "عطل" };

        var issues = EquipmentFaultPolicy.Validate(report, Now);

        Assert.Contains(issues, issue => issue.Field == nameof(report.Description));
    }

    [Fact]
    public void Rejects_fault_occurrence_in_the_future()
    {
        var report = ValidReport() with { OccurredAt = Now.AddMinutes(6) };

        var issues = EquipmentFaultPolicy.Validate(report, Now);

        Assert.Contains(issues, issue => issue.Field == nameof(report.OccurredAt));
    }

    [Fact]
    public void Blocking_fault_must_be_high_or_critical()
    {
        var report = ValidReport(EquipmentFaultSeverity.Medium, blocking: true);

        var issues = EquipmentFaultPolicy.Validate(report, Now);

        Assert.Contains(issues, issue => issue.Field == nameof(report.Severity));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview, true)]
    [InlineData(EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Assigned, true)]
    [InlineData(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.InProgress, true)]
    [InlineData(EquipmentFaultStatus.InProgress, EquipmentFaultStatus.Resolved, true)]
    [InlineData(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.Closed, true)]
    [InlineData(EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress, false)]
    [InlineData(EquipmentFaultStatus.Rejected, EquipmentFaultStatus.Assigned, false)]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Closed, false)]
    public void Enforces_the_fault_lifecycle(
        EquipmentFaultStatus current,
        EquipmentFaultStatus next,
        bool expected)
    {
        Assert.Equal(expected, EquipmentFaultPolicy.CanTransition(current, next));
    }
}
