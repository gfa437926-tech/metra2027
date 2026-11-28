using Metra.Api.Features.Users;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class RegistrationDecisionRequestGuardTests
{
    [Theory]
    [InlineData("approve", null, false)]
    [InlineData("approve", "تمت مطابقة الطلب", false)]
    [InlineData("reject", "بيانات غير مكتملة", false)]
    [InlineData("reject", null, true)]
    [InlineData("reject", "   ", true)]
    [InlineData("reject", " سبب غير صالح ", true)]
    [InlineData("grant_admin", "سبب", true)]
    [InlineData(null, null, true)]
    public void Validates_registration_decisions(string? decision, string? note, bool invalid)
    {
        var request = decision is null ? null : new RegistrationDecisionRequest(decision, note);
        Assert.Equal(invalid, RegistrationDecisionRequestGuard.GetError(request) is not null);
    }

    [Fact]
    public void Rejects_notes_longer_than_database_limit()
    {
        var request = new RegistrationDecisionRequest("approve", new string('x', 2001));
        Assert.Equal("registration_note_too_long", RegistrationDecisionRequestGuard.GetError(request));
    }

    [Fact]
    public void Rejects_control_characters_in_notes()
    {
        var request = new RegistrationDecisionRequest("approve", "مراجعة\nمرفوضة");
        Assert.Equal("registration_note_contains_control_characters", RegistrationDecisionRequestGuard.GetError(request));
    }
}
