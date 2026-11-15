namespace Metra.Api.Features.Records;

/// <summary>
/// Validates the application-level gate for submitting an accepted recorder
/// capture to asynchronous digitization. Authorization must be resolved from
/// the authenticated server context; this policy performs no I/O or deduplication.
/// </summary>
public sealed record RecordDigitizationEnqueueRequest(
    Guid CaptureId,
    Guid AcceptedAssetId,
    RecordImageAssetStatus AssetStatus,
    bool ActorCanDigitize,
    string AlgorithmProfile,
    string IdempotencyKey);

public sealed record RecordDigitizationEnqueueDecision(bool IsAllowed, string? ErrorCode)
{
    public static RecordDigitizationEnqueueDecision Allowed() => new(true, null);
    public static RecordDigitizationEnqueueDecision Rejected(string code) => new(false, code);
}

public static class RecordDigitizationEnqueuePolicy
{
    public const int MinimumIdempotencyKeyLength = 8;
    public const int MaximumIdempotencyKeyLength = 128;
    public const int MaximumAlgorithmProfileLength = 80;

    public static RecordDigitizationEnqueueDecision Evaluate(
        RecordDigitizationEnqueueRequest? request)
    {
        if (request is null)
            return RecordDigitizationEnqueueDecision.Rejected("digitization_request_required");

        // Check authority before resource details to avoid disclosing workflow state.
        if (!request.ActorCanDigitize)
            return RecordDigitizationEnqueueDecision.Rejected("digitization_permission_denied");

        if (request.CaptureId == Guid.Empty || request.AcceptedAssetId == Guid.Empty)
            return RecordDigitizationEnqueueDecision.Rejected("digitization_resource_required");

        if (!Enum.IsDefined(request.AssetStatus) ||
            request.AssetStatus != RecordImageAssetStatus.Accepted)
            return RecordDigitizationEnqueueDecision.Rejected("asset_not_accepted");

        if (!IsSafeAlgorithmProfile(request.AlgorithmProfile))
            return RecordDigitizationEnqueueDecision.Rejected("algorithm_profile_invalid");

        if (!IsSafeIdempotencyKey(request.IdempotencyKey))
            return RecordDigitizationEnqueueDecision.Rejected("idempotency_key_invalid");

        return RecordDigitizationEnqueueDecision.Allowed();
    }

    private static bool IsSafeAlgorithmProfile(string? value) =>
        !string.IsNullOrWhiteSpace(value) &&
        value.Length <= MaximumAlgorithmProfileLength &&
        IsLowerAlphaNumeric(value[0]) &&
        value.All(character =>
            IsLowerAlphaNumeric(character) || character is '.' or '_' or '-');

    private static bool IsSafeIdempotencyKey(string? value) =>
        value is not null &&
        value.Length is >= MinimumIdempotencyKeyLength and <= MaximumIdempotencyKeyLength &&
        value.All(character =>
            character is >= 'a' and <= 'z' ||
            character is >= 'A' and <= 'Z' ||
            character is >= '0' and <= '9' ||
            character is '-' or '_' or '.' or ':');

    private static bool IsLowerAlphaNumeric(char value) =>
        value is >= 'a' and <= 'z' or >= '0' and <= '9';
}
