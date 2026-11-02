namespace Metra.Api.Domain.Identity;

/// <summary>
/// Immutable, append-only administrative audit fact. Values are deliberately
/// scalar and bounded; secrets, tokens, credentials and request bodies do not
/// belong in this record.
/// </summary>
public sealed record MetraAdministrativeAuditEvent(
    string EventId,
    string TargetAccountId,
    string ActorUserId,
    string ActionCode,
    string ResourceType,
    string ResourceId,
    string? PreviousValue,
    string? NewValue,
    DateTimeOffset OccurredAtUtc,
    string Reason,
    string CorrelationId,
    long AggregateVersion);

public sealed record MetraAdministrativeAuditValidationResult(bool IsValid, string Code);

/// <summary>
/// Structural validation only. Authorization, event ordering, uniqueness,
/// append-only enforcement and transaction atomicity belong to persistence.
/// </summary>
public static class MetraAdministrativeAuditEventPolicy
{
    public static MetraAdministrativeAuditValidationResult Validate(
        MetraAdministrativeAuditEvent? auditEvent)
    {
        if (auditEvent is null)
            return Invalid("audit_event_required");

        if (!IsBoundedIdentifier(auditEvent.EventId, 128) ||
            !IsBoundedIdentifier(auditEvent.TargetAccountId, 128) ||
            !IsBoundedIdentifier(auditEvent.ActorUserId, 128) ||
            !IsBoundedIdentifier(auditEvent.ResourceId, 128) ||
            !IsBoundedIdentifier(auditEvent.CorrelationId, 128))
            return Invalid("audit_identifier_invalid");

        if (!IsCanonicalCode(auditEvent.ActionCode))
            return Invalid("audit_action_code_invalid");

        if (!IsCanonicalCode(auditEvent.ResourceType))
            return Invalid("audit_resource_type_invalid");

        if (auditEvent.OccurredAtUtc.Offset != TimeSpan.Zero)
            return Invalid("audit_timestamp_must_be_utc");

        if (string.IsNullOrWhiteSpace(auditEvent.Reason) ||
            auditEvent.Reason != auditEvent.Reason.Trim() ||
            auditEvent.Reason.Length > 2000 ||
            ContainsDisallowedControlCharacters(auditEvent.Reason))
            return Invalid("audit_reason_invalid");

        if (auditEvent.PreviousValue?.Length > 512 ||
            auditEvent.NewValue?.Length > 512 ||
            auditEvent.PreviousValue is not null && ContainsDisallowedControlCharacters(auditEvent.PreviousValue) ||
            auditEvent.NewValue is not null && ContainsDisallowedControlCharacters(auditEvent.NewValue))
            return Invalid("audit_change_value_invalid");

        if (auditEvent.PreviousValue is null && auditEvent.NewValue is null)
            return Invalid("audit_change_context_required");

        if (auditEvent.AggregateVersion <= 0)
            return Invalid("audit_aggregate_version_invalid");

        return new(true, "audit_event_valid");
    }

    private static bool IsBoundedIdentifier(string? value, int maxLength)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= maxLength &&
           value == value.Trim() &&
           !ContainsDisallowedControlCharacters(value);

    private static bool IsCanonicalCode(string? value)
    {
        if (string.IsNullOrEmpty(value) || value.Length > 128)
            return false;

        var segmentHasCharacter = false;
        foreach (var character in value)
        {
            if (character is >= 'a' and <= 'z' or >= '0' and <= '9')
            {
                segmentHasCharacter = true;
                continue;
            }

            if (character is '.' or '_' or '-')
            {
                if (!segmentHasCharacter)
                    return false;
                segmentHasCharacter = false;
                continue;
            }

            return false;
        }

        return segmentHasCharacter;
    }

    private static bool ContainsDisallowedControlCharacters(string value)
        => value.Any(char.IsControl);

    private static MetraAdministrativeAuditValidationResult Invalid(string code)
        => new(false, code);
}
