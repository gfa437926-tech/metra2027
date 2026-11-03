namespace Metra.Api.Features.Identity;

/// <summary>
/// Server-produced, read-only presentation context for the authenticated METRA account.
/// This contract is not an authorization token; protected operations must re-evaluate
/// current permissions and resource scope on the server.
/// </summary>
public sealed record CurrentUserContextResponse(
    string UserId,
    CurrentUserProfileResponse Profile,
    string AccountState,
    IReadOnlyList<CurrentUserStationAssignmentResponse> Assignments,
    IReadOnlyList<string> Permissions);

public sealed record CurrentUserProfileResponse(
    string FirstName,
    string? FatherName,
    string LastName,
    string? Email,
    string? Phone);

public sealed record CurrentUserStationAssignmentResponse(
    string StationId,
    string StationName,
    string RoleCode,
    DateTimeOffset ValidFrom,
    DateTimeOffset? ValidTo,
    bool IsActive);
