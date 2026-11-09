using Metra.Api.Domain.Maintenance;
using Metra.Api.Features.Maintenance;
using Xunit;

namespace Metra.Api.Tests.Features.Maintenance;

public sealed class EquipmentFaultRequestGuardTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 7, 2, 0, 0, TimeSpan.Zero);
    private static readonly Guid StationId = Guid.Parse("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
    private static readonly Guid UserId = Guid.Parse("11111111-1111-4111-8111-111111111111");

    [Fact]
    public void Accepts_valid_submit_request()
    {
        var request = new EquipmentFaultSubmitRequest(
            "أجهزة الرصد",
            "مقياس الحرارة",
            "توقف الجهاز عن إرسال القراءات منذ بداية الوردية.",
            "High",
            Now.AddMinutes(-30),
            false);
        Assert.Empty(EquipmentFaultRequestGuard.ValidateSubmit(StationId, UserId, request, Now));
    }

    [Fact]
    public void Rejects_unknown_severity()
    {
        var request = new EquipmentFaultSubmitRequest(
            "أجهزة الرصد",
            "مقياس الحرارة",
            "توقف الجهاز عن إرسال القراءات منذ بداية الوردية.",
            "Extreme",
            Now.AddMinutes(-10),
            false);
        var issues = EquipmentFaultRequestGuard.ValidateSubmit(StationId, UserId, request, Now);
        Assert.Contains(issues, i => i.Field.Contains("Severity", StringComparison.OrdinalIgnoreCase));
    }

    [Theory]
    [InlineData("UnderReview", "equipment_fault.review")]
    [InlineData("Rejected", "equipment_fault.review")]
    [InlineData("Assigned", "equipment_fault.assign")]
    [InlineData("InProgress", "equipment_fault.update")]
    [InlineData("Resolved", "equipment_fault.resolve")]
    [InlineData("Closed", "equipment_fault.resolve")]
    public void Maps_transition_permissions(string status, string permission)
    {
        Assert.True(EquipmentFaultRequestGuard.TryParseStatus(status, out var parsed));
        Assert.Equal(permission, EquipmentFaultRequestGuard.PermissionForTransition(parsed));
    }

    [Fact]
    public void Maps_forbidden_database_messages()
    {
        Assert.Equal(
            System.Net.HttpStatusCode.Forbidden,
            SupabaseEquipmentFaultService.MapFailure(
                "station_equipment_fault_create_forbidden",
                System.Net.HttpStatusCode.InternalServerError));
        Assert.Equal(
            System.Net.HttpStatusCode.Conflict,
            SupabaseEquipmentFaultService.MapFailure(
                "invalid_fault_state_transition",
                System.Net.HttpStatusCode.InternalServerError));
    }
}
