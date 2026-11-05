using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationValidationRequestGuardTests
{
    [Fact]
    public void AcceptsSmallWellFormedPayload()
    {
        var values = new Dictionary<string, string?> { ["dryTemp"] = "+20.0", ["utcTime"] = "00" };

        Assert.Null(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void RejectsFieldNamesContainingUnexpectedCharacters()
    {
        var values = new Dictionary<string, string?> { ["dryTemp\nInjected"] = "+20.0" };

        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void RejectsControlCharactersInValues()
    {
        var values = new Dictionary<string, string?> { ["dryTemp"] = "+20.0\0" };

        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void RejectsAggregatePayloadOverConfiguredLimit()
    {
        var values = Enumerable.Range(0, 65)
            .ToDictionary(index => $"field{index}", _ => (string?)new string('1', 64));

        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }

    [Fact]
    public void RejectsTooManyFields()
    {
        var values = Enumerable.Range(0, ObservationValidationRequestGuard.MaximumFields + 1)
            .ToDictionary(index => $"field{index}", _ => (string?)"1");

        Assert.NotNull(ObservationValidationRequestGuard.GetError(values));
    }
}
