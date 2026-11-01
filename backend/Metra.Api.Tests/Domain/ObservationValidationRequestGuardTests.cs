using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ObservationValidationRequestGuardTests
{
    [Fact]
    public void Rejects_null_values()
        => Assert.NotNull(ObservationValidationRequestGuard.GetError(null));

    [Fact]
    public void Rejects_empty_values()
        => Assert.NotNull(ObservationValidationRequestGuard.GetError(new Dictionary<string, string?>()));

    [Fact]
    public void Accepts_normal_payload()
    {
        var values = new Dictionary<string, string?> { ["minTemp"] = "12.5" };
        Assert.Null(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void Rejects_too_many_fields()
    {
        var values = Enumerable.Range(0, ObservationValidationRequestGuard.MaximumFields + 1)
            .ToDictionary(index => $"field{index}", _ => (string?)"1");
        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void Rejects_oversized_values()
    {
        var values = new Dictionary<string, string?> { ["minTemp"] = new string('1', ObservationValidationRequestGuard.MaximumValueLength + 1) };
        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void Rejects_oversized_field_names()
    {
        var values = new Dictionary<string, string?> { [new string('x', ObservationValidationRequestGuard.MaximumFieldNameLength + 1)] = "1" };
        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }
}