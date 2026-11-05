export type RegistrationRequestStatus =
  | 'pending_station_approval'
  | 'pending_system_approval'
  | 'active'
  | 'rejected';

export interface RegistrationSubmissionStatus {
  readonly requestId: string;
  readonly status: RegistrationRequestStatus;
  readonly statusLabel: string;
  readonly submittedAtUtc: string;
  readonly updatedAtUtc: string;
}
