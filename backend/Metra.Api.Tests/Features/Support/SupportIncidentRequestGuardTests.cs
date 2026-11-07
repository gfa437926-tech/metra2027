using Metra.Api.Domain.Support;
using Metra.Api.Features.Support;
using Xunit;

namespace Metra.Api.Tests.Features.Support;

public sealed class SupportIncidentRequestGuardTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 7, 2, 0, 0, TimeSpan.Zero);
    private static readonly Guid StationId = Guid.Parse("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
    private static readonly Guid UserId = Guid.Parse("11111111-1111-4111-8111-111111111111");

    [Fact]
    public void Accepts_valid_it_incident()
    {
        var request = new SupportIncidentSubmitRequest(
            "InformationTechnology",
            "نظام التشغيل",
            "تعذر تسجيل الدخول",
            "لا يمكن للمستخدم فتح تطبيق الرصد بعد التحديث الأخير للمحطة.",
            "جهاز المكتب",
            "High",
            Now.AddHours(-1),
            true);
        Assert.Empty(SupportIncidentRequestGuard.ValidateSubmit(StationId, UserId, request, Now));
    }

    [Fact]
    public void Rejects_operations_impact_with_low_severity()
    {
        var request = new SupportIncidentSubmitRequest(
            "Telecommunications",
            "رابط الإرسال",
            "انقطاع الرابط",
            "انقطع رابط الإرسال منذ ساعتين بشكل كامل.",
            null,
            "Low",
            Now.AddMinutes(-20),
            true);
        var issues = SupportIncidentRequestGuard.ValidateSubmit(StationId, UserId, request, Now);
        Assert.Contains(issues, i => i.Field.Contains("Severity", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Maps_forbidden_messages()
    {
        Assert.Equal(
            System.Net.HttpStatusCode.Forbidden,
            SupabaseSupportIncidentService.MapFailure(
                "station_support_incident_create_forbidden",
                System.Net.HttpStatusCode.InternalServerError));
    }
}
