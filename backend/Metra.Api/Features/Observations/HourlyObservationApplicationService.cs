using Metra.Api.Domain.Observations;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Trusted actor snapshot resolved from the validated server principal and
/// authoritative METRA identity data. Never populate this from request JSON.
/// </summary>
public sealed record HourlyObservationActorContext(
    string UserId,
    bool IsActive,
    IReadOnlyList<HourlyObservationStationGrant> StationGrants,
    IReadOnlySet<string> Permissions);

public sealed record HourlyObservationStationGrant(
    string StationId,
    DateTimeOffset ValidFrom,
    DateTimeOffset? ValidTo,
    DateTimeOffset? RevokedAt);

public interface IHourlyObservationActorContextProvider
{
    Task<HourlyObservationActorContext?> GetCurrentActorAsync(CancellationToken cancellationToken);
}

public sealed record PersistHourlyObservationCommand(
    string StationId,
    string SubmittedBy,
    DateOnly ObservationDate,
    int UtcHour,
    IReadOnlyDictionary<string, string?> Values,
    DateTimeOffset SubmittedAt);

public sealed record PersistedHourlyObservation(
    string ObservationId,
    string StationId,
    string SubmittedBy,
    DateOnly ObservationDate,
    int UtcHour,
    HourlyObservationStatus Status,
    DateTimeOffset SubmittedAt);

public sealed record HourlyObservationReviewTarget(
    string ObservationId,
    string StationId,
    HourlyObservationStatus Status);

public sealed record CommitHourlyObservationReviewCommand(
    string ObservationId,
    HourlyObservationStatus ExpectedStatus,
    HourlyObservationStatus NewStatus,
    string ReviewedBy,
    string? Note,
    DateTimeOffset ReviewedAt);

public enum HourlyObservationStoreResult
{
    Committed = 0,
    NotFound = 1,
    Conflict = 2
}

/// <summary>
/// Persistence boundary. Implementations must persist the report and its audit
/// event atomically. Review must lock/reload the report and revalidate actor
/// station permission inside the same transaction before compare-and-set.
/// </summary>
public interface IHourlyObservationStore
{
    Task<PersistedHourlyObservation> CreateAsync(
        PersistHourlyObservationCommand command,
        CancellationToken cancellationToken);

    Task<HourlyObservationReviewTarget?> FindReviewTargetAsync(
        string observationId,
        CancellationToken cancellationToken);

    Task<HourlyObservationStoreResult> CommitReviewAsync(
        CommitHourlyObservationReviewCommand command,
        string requiredPermission,
        CancellationToken cancellationToken);
}

public sealed record HourlyObservationApplicationResult<T>(
    bool Succeeded,
    string Code,
    string Message,
    T? Value = default);

/// <summary>
/// Application workflow for submission and station review. It contains no
/// database-specific code; authorization facts are server-resolved.
/// </summary>
public sealed class HourlyObservationApplicationService(
    IHourlyObservationActorContextProvider actorContextProvider,
    IHourlyObservationStore store,
    TimeProvider timeProvider)
{
    public const string SubmitPermission = "observations.hourly.submit";
    public const string ReviewPermission = "observations.hourly.review";

    public async Task<HourlyObservationApplicationResult<HourlyObservationSubmissionResponse>> SubmitAsync(
        CreateHourlyObservationRequest? request,
        CancellationToken cancellationToken = default)
    {
        var contractErrors = HourlyObservationContractValidator.ValidateSubmission(request);
        if (contractErrors.Count > 0)
            return Failure<HourlyObservationSubmissionResponse>("invalid_request", string.Join(" ", contractErrors));

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (!IsValidActor(actor))
            return Failure<HourlyObservationSubmissionResponse>("unauthenticated", "يجب تسجيل الدخول بحساب METRA فعال.");

        if (!actor!.Permissions.Contains(SubmitPermission))
            return Failure<HourlyObservationSubmissionResponse>("permission_denied", "لا تملك صلاحية إرسال النشرات الساعية.");

        var now = timeProvider.GetUtcNow();
        var stationIds = actor.StationGrants
            .Where(grant => IsEffective(grant, now))
            .Select(grant => grant.StationId)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        if (stationIds.Length != 1)
            return Failure<HourlyObservationSubmissionResponse>(
                "station_context_required",
                "يجب أن يكون لحسابك تكليف فعال بمحطة واحدة محددة لإرسال النشرة.");

        var values = request!.Values!;
        var validationIssues = HourlyObservationValidator.Validate(values);
        if (validationIssues.Count > 0)
            return Failure<HourlyObservationSubmissionResponse>(
                "observation_validation_failed",
                string.Join(" ", validationIssues.Select(issue => issue.Message)));

        var saved = await store.CreateAsync(
            new PersistHourlyObservationCommand(
                stationIds[0],
                actor.UserId,
                request.ObservationDate,
                request.UtcHour,
                new Dictionary<string, string?>(values, StringComparer.Ordinal),
                now),
            cancellationToken);

        var response = new HourlyObservationSubmissionResponse(
            saved.ObservationId,
            saved.StationId,
            saved.ObservationDate,
            saved.UtcHour,
            saved.Status,
            saved.SubmittedAt,
            saved.SubmittedBy);

        return new(true, "submitted", "تم حفظ النشرة وإرسالها إلى قائمة مراجعة المحطة.", response);
    }

    public async Task<HourlyObservationApplicationResult<HourlyObservationReviewResponse>> ReviewAsync(
        string? observationId,
        HourlyObservationReviewRequest? request,
        CancellationToken cancellationToken = default)
    {
        if (!IsValidObservationId(observationId))
            return Failure<HourlyObservationReviewResponse>("invalid_observation_id", "معرّف النشرة غير صالح.");

        var contractErrors = HourlyObservationContractValidator.ValidateReview(request);
        if (contractErrors.Count > 0)
            return Failure<HourlyObservationReviewResponse>("invalid_review", string.Join(" ", contractErrors));

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (!IsValidActor(actor))
            return Failure<HourlyObservationReviewResponse>("unauthenticated", "يجب تسجيل الدخول بحساب METRA فعال.");

        if (!actor!.Permissions.Contains(ReviewPermission))
            return Failure<HourlyObservationReviewResponse>("permission_denied", "لا تملك صلاحية مراجعة النشرات.");

        var target = await store.FindReviewTargetAsync(observationId!, cancellationToken);
        if (target is null)
            return Failure<HourlyObservationReviewResponse>("not_found", "النشرة غير موجودة.");

        if (target.Status != HourlyObservationStatus.PendingReview)
            return Failure<HourlyObservationReviewResponse>("invalid_state", "هذه النشرة ليست بانتظار المراجعة.");

        var now = timeProvider.GetUtcNow();
        var canReviewStation = actor.StationGrants.Any(grant =>
            grant.StationId == target.StationId && IsEffective(grant, now));
        if (!canReviewStation)
            return Failure<HourlyObservationReviewResponse>("station_scope_violation", "لا يمكنك مراجعة نشرات هذه المحطة.");

        if (target.ObservationId != observationId)
            return Failure<HourlyObservationReviewResponse>("invalid_store_result", "تعذر التحقق من بيانات النشرة.");

        var nextStatus = request!.Decision == HourlyObservationReviewDecision.Approve
            ? HourlyObservationStatus.Approved
            : HourlyObservationStatus.Rejected;

        var note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        var commit = await store.CommitReviewAsync(
            new CommitHourlyObservationReviewCommand(
                target.ObservationId,
                HourlyObservationStatus.PendingReview,
                nextStatus,
                actor.UserId,
                note,
                now),
            ReviewPermission,
            cancellationToken);

        if (commit == HourlyObservationStoreResult.NotFound)
            return Failure<HourlyObservationReviewResponse>("not_found", "النشرة غير موجودة.");
        if (commit == HourlyObservationStoreResult.Conflict)
            return Failure<HourlyObservationReviewResponse>("review_conflict", "تمت مراجعة النشرة أو تغيرت صلاحياتك؛ أعد تحميل القائمة.");

        var response = new HourlyObservationReviewResponse(
            target.ObservationId,
            nextStatus,
            actor.UserId,
            now,
            note);
        return new(true, "review_recorded", "تم تسجيل قرار مراجعة النشرة.", response);
    }

    private static bool IsValidActor(HourlyObservationActorContext? actor)
        => actor is not null &&
           actor.IsActive &&
           !string.IsNullOrWhiteSpace(actor.UserId) &&
           actor.UserId == actor.UserId.Trim() &&
           actor.UserId.Length <= 128 &&
           !actor.UserId.Any(char.IsControl) &&
           actor.StationGrants is not null &&
           actor.Permissions is not null;

    private static bool IsEffective(HourlyObservationStationGrant grant, DateTimeOffset now)
        => grant.ValidFrom.Offset == TimeSpan.Zero &&
           grant.ValidFrom <= now &&
           (grant.ValidTo is null || grant.ValidTo.Value.Offset == TimeSpan.Zero && now < grant.ValidTo.Value) &&
           (grant.RevokedAt is null || grant.RevokedAt.Value.Offset == TimeSpan.Zero && now < grant.RevokedAt.Value);

    private static bool IsValidObservationId(string? value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= 128 &&
           value == value.Trim() &&
           value.All(character => char.IsAsciiLetterOrDigit(character) || character is '-' or '_' or '.' or ':');

    private static HourlyObservationApplicationResult<T> Failure<T>(string code, string message)
        => new(false, code, message);
}
