using System.Text.Json;
using Metra.Api.Domain.Observations;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class GreenfieldObservationValueMapperTests
{
    private static readonly Guid TemperatureId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private static readonly Guid WeatherCodeId = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private static readonly Guid CelsiusId = Guid.Parse("33333333-3333-3333-3333-333333333333");
    private static readonly GreenfieldParameterDefinition[] Parameters =
    [
        new(TemperatureId, "air_temperature", "decimal", CelsiusId, 1, true),
        new(WeatherCodeId, "present_weather_code", "integer", null, null, true)
    ];
    private static readonly GreenfieldUnitDefinition[] Units =
    [
        new(CelsiusId, "Cel", "temperature", true)
    ];

    private static JsonElement Payload(string json)
    {
        using var document = JsonDocument.Parse(json);
        return document.RootElement.Clone();
    }

    [Fact]
    public void Maps_decimal_and_integer_to_their_typed_columns()
    {
        var result = GreenfieldObservationValueMapper.Map(
            Payload("""[
                {"parameterCode":"air_temperature","value":21.5},
                {"parameterCode":"present_weather_code","value":7}
            ]"""), Parameters, Units);

        Assert.True(result.Succeeded);
        Assert.Empty(result.Issues);
        Assert.Equal(2, result.Values.Count);
        Assert.Equal(21.5m, result.Values[0].ValueDecimal);
        Assert.Equal(CelsiusId, result.Values[0].UnitId);
        Assert.Null(result.Values[0].ValueInteger);
        Assert.Equal(7L, result.Values[1].ValueInteger);
        Assert.Null(result.Values[1].UnitId);
    }

    [Fact]
    public void Maps_explicit_canonical_unit_and_sequence_number()
    {
        var result = GreenfieldObservationValueMapper.Map(
            Payload("""[{"parameterCode":"air_temperature","value":18.2,"unitCode":"Cel","sequenceNumber":2}]"""),
            Parameters, Units);

        Assert.True(result.Succeeded);
        Assert.Equal(2, result.Values[0].SequenceNumber);
        Assert.Equal(CelsiusId, result.Values[0].UnitId);
    }

    [Theory]
    [InlineData("""{"parameterCode":"air_temperature","value":21.5}""")]
    [InlineData("""[{"parameterCode":"air_temperature","value":21.5},{"parameterCode":"air_temperature","value":22.0}]""")]
    public void Rejects_non_array_or_duplicate_parameter_sequence(string json)
    {
        var result = GreenfieldObservationValueMapper.Map(Payload(json), Parameters, Units);
        Assert.False(result.Succeeded);
        Assert.Empty(result.Values);
    }

    [Theory]
    [InlineData("""[{"parameterCode":"unknown","value":1}]""", "parameter_unknown_or_inactive")]
    [InlineData("""[{"parameterCode":"air_temperature","value":"21.5"}]""", "decimal_value_required")]
    [InlineData("""[{"parameterCode":"air_temperature","value":21.55}]""", "decimal_precision_exceeded")]
    [InlineData("""[{"parameterCode":"present_weather_code","value":7.1}]""", "integer_value_required")]
    [InlineData("""[{"parameterCode":"present_weather_code","value":7,"unitCode":"Cel"}]""", "unit_not_allowed_for_parameter")]
    [InlineData("""[{"parameterCode":"air_temperature","value":21.5,"unitCode":"K"}]""", "unit_unknown_or_inactive")]
    [InlineData("""[{"parameterCode":"air_temperature","value":21.5,"unexpected":true}]""", "value_entry_has_duplicate_or_unknown_properties")]
    [InlineData("""[{"parameterCode":"air_temperature","value":21.5,"sequenceNumber":0}]""", "sequence_number_invalid")]
    public void Rejects_invalid_typed_values_and_metadata(string json, string expectedCode)
    {
        var result = GreenfieldObservationValueMapper.Map(Payload(json), Parameters, Units);

        Assert.False(result.Succeeded);
        Assert.Empty(result.Values);
        Assert.Contains(result.Issues, issue => issue.Code == expectedCode);
    }

    [Fact]
    public void Rejects_noncanonical_unit_instead_of_silently_converting()
    {
        var fahrenheit = new GreenfieldUnitDefinition(
            Guid.Parse("44444444-4444-4444-4444-444444444444"), "degF", "temperature", true);
        var result = GreenfieldObservationValueMapper.Map(
            Payload("""[{"parameterCode":"air_temperature","value":70,"unitCode":"degF"}]"""),
            Parameters, [.. Units, fahrenheit]);

        Assert.False(result.Succeeded);
        Assert.Contains(result.Issues, issue => issue.Code == "unit_conversion_not_supported");
    }

    [Fact]
    public void Rejects_duplicate_parameter_sequence_but_allows_distinct_sequences()
    {
        var result = GreenfieldObservationValueMapper.Map(
            Payload("""[
                {"parameterCode":"present_weather_code","value":6},
                {"parameterCode":"present_weather_code","value":7,"sequenceNumber":2}
            ]"""), Parameters, Units);

        Assert.True(result.Succeeded);
        Assert.Equal(new[] { 1, 2 }, result.Values.Select(value => value.SequenceNumber));
    }

    [Fact]
    public void Rejects_null_and_oversized_payloads()
    {
        var nullResult = GreenfieldObservationValueMapper.Map(Payload("null"), Parameters, Units);
        var largePayload = "[" + string.Join(",", Enumerable.Repeat(
            """{"parameterCode":"present_weather_code","value":1}""",
            GreenfieldObservationValueMapper.MaximumValues + 1)) + "]";
        var largeResult = GreenfieldObservationValueMapper.Map(Payload(largePayload), Parameters, Units);

        Assert.False(nullResult.Succeeded);
        Assert.Contains(nullResult.Issues, issue => issue.Code == "payload_must_be_array");
        Assert.False(largeResult.Succeeded);
        Assert.Contains(largeResult.Issues, issue => issue.Code == "payload_value_count_out_of_range");
    }
}
