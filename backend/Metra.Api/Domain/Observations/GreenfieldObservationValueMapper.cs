using System.Text.Json;

namespace Metra.Api.Domain.Observations;

/// <summary>
/// Reference-data snapshot supplied by the persistence adapter. Values are resolved
/// from ref.parameters and ref.units; callers must not construct this catalogue from
/// client input.
/// </summary>
public sealed record GreenfieldParameterDefinition(
    Guid Id,
    string Code,
    string ValueKind,
    Guid? CanonicalUnitId,
    int? PrecisionScale,
    bool IsActive);

public sealed record GreenfieldUnitDefinition(
    Guid Id,
    string Code,
    string DimensionCode,
    bool IsActive);

/// <summary>
/// Typed row shape for observations.values. Exactly one typed value column is populated.
/// UnitId is the resolved canonical unit; unit conversion is intentionally not inferred.
/// </summary>
public sealed record GreenfieldObservationValue(
    Guid ParameterId,
    string ValueKind,
    decimal? ValueDecimal,
    long? ValueInteger,
    string? ValueText,
    bool? ValueBoolean,
    Guid? UnitId,
    int SequenceNumber);

public sealed record GreenfieldObservationMappingIssue(int Index, string Code);

public sealed record GreenfieldObservationValueMappingResult(
    bool Succeeded,
    IReadOnlyList<GreenfieldObservationValue> Values,
    IReadOnlyList<GreenfieldObservationMappingIssue> Issues);

/// <summary>
/// Strictly maps the versioned API payload array to the normalized typed/EAV
/// observations.values shape. It performs no database or network access.
/// </summary>
public static class GreenfieldObservationValueMapper
{
    public const int MaximumValues = 1000;
    public const int MaximumTextLength = 4000;
    public const int MaximumSequenceNumber = 10000;

    public static GreenfieldObservationValueMappingResult Map(
        JsonElement payload,
        IReadOnlyCollection<GreenfieldParameterDefinition> parameters,
        IReadOnlyCollection<GreenfieldUnitDefinition> units)
    {
        ArgumentNullException.ThrowIfNull(parameters);
        ArgumentNullException.ThrowIfNull(units);

        var issues = new List<GreenfieldObservationMappingIssue>();
        var mapped = new List<GreenfieldObservationValue>();
        if (payload.ValueKind != JsonValueKind.Array)
            return Failure("payload_must_be_array");

        if (payload.GetArrayLength() is < 1 or > MaximumValues)
            return Failure("payload_value_count_out_of_range");

        var parameterIndex = new Dictionary<string, GreenfieldParameterDefinition>(StringComparer.Ordinal);
        foreach (var parameter in parameters)
        {
            if (parameter.Id == Guid.Empty || string.IsNullOrWhiteSpace(parameter.Code) ||
                !parameterIndex.TryAdd(parameter.Code, parameter))
                return Failure("parameter_catalogue_invalid");
        }

        var unitByCode = new Dictionary<string, GreenfieldUnitDefinition>(StringComparer.Ordinal);
        var unitById = new Dictionary<Guid, GreenfieldUnitDefinition>();
        foreach (var unit in units)
        {
            if (unit.Id == Guid.Empty || string.IsNullOrWhiteSpace(unit.Code) ||
                string.IsNullOrWhiteSpace(unit.DimensionCode) ||
                !unitByCode.TryAdd(unit.Code, unit) || !unitById.TryAdd(unit.Id, unit))
                return Failure("unit_catalogue_invalid");
        }

        var seenSequences = new HashSet<(Guid ParameterId, int Sequence)>();
        var index = 0;
        foreach (var item in payload.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object)
            {
                issues.Add(new(index, "value_entry_must_be_object"));
                index++;
                continue;
            }

            var properties = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
            var duplicateProperty = false;
            foreach (var property in item.EnumerateObject())
            {
                if (!properties.TryAdd(property.Name, property.Value))
                    duplicateProperty = true;
            }

            if (duplicateProperty || properties.Keys.Any(key =>
                key is not ("parameterCode" or "value" or "unitCode" or "sequenceNumber")))
            {
                issues.Add(new(index, "value_entry_has_duplicate_or_unknown_properties"));
                index++;
                continue;
            }

            if (!properties.TryGetValue("parameterCode", out var codeElement) ||
                codeElement.ValueKind != JsonValueKind.String ||
                string.IsNullOrWhiteSpace(codeElement.GetString()))
            {
                issues.Add(new(index, "parameter_code_required"));
                index++;
                continue;
            }

            var parameterCode = codeElement.GetString()!;
            if (!parameterIndex.TryGetValue(parameterCode, out var parameter) || !parameter.IsActive)
            {
                issues.Add(new(index, "parameter_unknown_or_inactive"));
                index++;
                continue;
            }

            if (!properties.TryGetValue("value", out var valueElement))
            {
                issues.Add(new(index, "typed_value_required"));
                index++;
                continue;
            }

            var sequence = 1;
            if (properties.TryGetValue("sequenceNumber", out var sequenceElement) &&
                (sequenceElement.ValueKind != JsonValueKind.Number ||
                 !sequenceElement.TryGetInt32(out sequence) ||
                 sequence is < 1 or > MaximumSequenceNumber))
            {
                issues.Add(new(index, "sequence_number_invalid"));
                index++;
                continue;
            }

            if (!seenSequences.Add((parameter.Id, sequence)))
            {
                issues.Add(new(index, "duplicate_parameter_sequence"));
                index++;
                continue;
            }

            if (!TryResolveUnit(parameter, properties, unitByCode, unitById, out var unitId, out var unitError))
            {
                issues.Add(new(index, unitError!));
                index++;
                continue;
            }

            if (!TryMapValue(parameter, valueElement, unitId, sequence, out var mappedValue, out var valueError))
            {
                issues.Add(new(index, valueError!));
                index++;
                continue;
            }

            mapped.Add(mappedValue!);
            index++;
        }

        return issues.Count == 0
            ? new(true, mapped, Array.Empty<GreenfieldObservationMappingIssue>())
            : new(false, Array.Empty<GreenfieldObservationValue>(), issues);

        GreenfieldObservationValueMappingResult Failure(string code) =>
            new(false, Array.Empty<GreenfieldObservationValue>(),
                [new(-1, code)]);
    }

    private static bool TryResolveUnit(
        GreenfieldParameterDefinition parameter,
        IReadOnlyDictionary<string, JsonElement> properties,
        IReadOnlyDictionary<string, GreenfieldUnitDefinition> unitByCode,
        IReadOnlyDictionary<Guid, GreenfieldUnitDefinition> unitById,
        out Guid? unitId,
        out string? error)
    {
        unitId = null;
        error = null;
        var suppliedUnitCode = properties.TryGetValue("unitCode", out var unitElement)
            ? unitElement.ValueKind == JsonValueKind.String ? unitElement.GetString() : null
            : null;

        if (properties.ContainsKey("unitCode") &&
            unitElement.ValueKind is not (JsonValueKind.String or JsonValueKind.Null))
        {
            error = "unit_code_invalid";
            return false;
        }

        if (parameter.CanonicalUnitId is null)
        {
            if (!string.IsNullOrWhiteSpace(suppliedUnitCode))
            {
                error = "unit_not_allowed_for_parameter";
                return false;
            }
            return true;
        }

        if (!unitById.TryGetValue(parameter.CanonicalUnitId.Value, out var canonical) || !canonical.IsActive)
        {
            error = "canonical_unit_missing_or_inactive";
            return false;
        }

        if (string.IsNullOrWhiteSpace(suppliedUnitCode))
        {
            unitId = canonical.Id;
            return true;
        }

        if (!unitByCode.TryGetValue(suppliedUnitCode, out var supplied) || !supplied.IsActive)
        {
            error = "unit_unknown_or_inactive";
            return false;
        }

        // The schema currently identifies canonical units but does not define a
        // conversion graph. Reject alternate units rather than silently storing
        // an unconverted magnitude under a different unit.
        if (supplied.Id != canonical.Id || supplied.DimensionCode != canonical.DimensionCode)
        {
            error = "unit_conversion_not_supported";
            return false;
        }

        unitId = canonical.Id;
        return true;
    }

    private static bool TryMapValue(
        GreenfieldParameterDefinition parameter,
        JsonElement element,
        Guid? unitId,
        int sequence,
        out GreenfieldObservationValue? mapped,
        out string? error)
    {
        mapped = null;
        error = null;
        decimal? decimalValue = null;
        long? integerValue = null;
        string? textValue = null;
        bool? booleanValue = null;

        switch (parameter.ValueKind)
        {
            case "decimal":
                if (element.ValueKind != JsonValueKind.Number || !element.TryGetDecimal(out var number))
                {
                    error = "decimal_value_required";
                    return false;
                }
                if (parameter.PrecisionScale is < 0 or > 18 ||
                    parameter.PrecisionScale is int scale && DecimalScale(number) > scale)
                {
                    error = "decimal_precision_exceeded";
                    return false;
                }
                decimalValue = number;
                break;

            case "integer":
                if (element.ValueKind != JsonValueKind.Number || !element.TryGetInt64(out var whole))
                {
                    error = "integer_value_required";
                    return false;
                }
                integerValue = whole;
                break;

            case "text":
                if (element.ValueKind != JsonValueKind.String ||
                    element.GetString() is not { Length: <= MaximumTextLength } text ||
                    text.Any(char.IsControl))
                {
                    error = "text_value_invalid";
                    return false;
                }
                textValue = text;
                break;

            case "boolean":
                if (element.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                {
                    error = "boolean_value_required";
                    return false;
                }
                booleanValue = element.GetBoolean();
                break;

            default:
                error = "parameter_value_kind_unsupported";
                return false;
        }

        mapped = new GreenfieldObservationValue(
            parameter.Id, parameter.ValueKind, decimalValue, integerValue,
            textValue, booleanValue, unitId, sequence);
        return true;
    }

    private static int DecimalScale(decimal value) =>
        (decimal.GetBits(value)[3] >> 16) & 0x7F;
}
