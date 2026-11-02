/**
 * Mirrors GET /api/v1/identity/me.
 *
 * This is display context only. Never use these values as proof of authorization;
 * every protected operation is authorized again by the ASP.NET Core API.
 */
export interface CurrentUserContext {
  readonly userId: string;
  readonly profile: CurrentUserProfile;
  readonly accountState: string;
  readonly assignments: readonly CurrentUserStationAssignment[];
  readonly permissions: readonly string[];
}

export interface CurrentUserProfile {
  readonly firstName: string;
  readonly fatherName: string | null;
  readonly lastName: string;
  readonly email: string | null;
  readonly phone: string | null;
}

export interface CurrentUserStationAssignment {
  readonly stationId: string;
  readonly stationName: string;
  readonly roleCode: string;
  readonly validFrom: string;
  readonly validTo: string | null;
  /**
   * Server-computed for display. It is not an authorization decision for later requests.
   */
  readonly isActive: boolean;
}
