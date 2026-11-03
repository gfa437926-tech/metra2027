using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationValidationRequestGuardTests
{
    [Fact]
    public void Rejects_missing_values()
    {
        Assert.Equal("يجب إرسال كائن values.", ObservationValidationRequestGuard.GetError(null));
    }

    [Fact]
    public void Rejects_empty_values()
    {
        Assert.Equal("يجب إرسال حقل واحد على الأقل للتحقق.",
            ObservationValidationRequestGuard.GetError(new Dictionary<string, string?>()));
    }

    [Fact]
    public void Accepts_payload_at_field_and_value_limits()
    {
        // Keep field names within the documented limit while preserving unique keys.
        var values = Enumerable.Range(0, ObservationValidationRequestGuard.MaximumFields)
            .ToDictionary(i => $"f{i:D2}", _ => (string?)new string('v', ObservationValidationRequestGuard.MaximumValueLength));

        Assert.Null(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void Rejects_too_many_fields()
    {
        var values = Enumerable.Range(0, ObservationValidationRequestGuard.MaximumFields + 1)
            .ToDictionary(i => $"f{i:D3}", _ => (string?)"x");

        Assert.Contains("يتجاوز", ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void Rejects_overlong_field_name_and_value()
    {
        var nameError = ObservationValidationRequestGuard.GetError(
            new Dictionary<string, string?> { [new string('x', ObservationValidationRequestGuard.MaximumFieldNameLength + 1)] = "v" });
        var valueError = ObservationValidationRequestGuard.GetError(
            new Dictionary<string, string?> { ["field"] = new string('x', ObservationValidationRequestGuard.MaximumValueLength + 1) });

        Assert.NotNull(nameError);
        Assert.NotNull(valueError);
    }
}
