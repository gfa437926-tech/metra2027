import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Injectable, InjectionToken, inject, signal } from '@angular/core';
import { firstValueFrom, timeout } from 'rxjs';
import { CurrentUserContext } from './current-user-context.models';

/**
 * Keep disabled until an approved identity provider and the real /identity/me
 * endpoint are deployed. This prevents preview builds from inventing a session.
 */
export const IDENTITY_CONTEXT_ENDPOINT_ENABLED = new InjectionToken<boolean>(
  'IDENTITY_CONTEXT_ENDPOINT_ENABLED',
  { providedIn: 'root', factory: () => false }
);

export const METRA_API_BASE_URL = new InjectionToken<string>(
  'METRA_API_BASE_URL',
  { providedIn: 'root', factory: () => '/api/v1' }
);

export type CurrentUserSessionState =
  | 'unconfigured'
  | 'loading'
  | 'unauthenticated'
  | 'active'
  | 'pendingApproval'
  | 'suspended'
  | 'forbidden'
  | 'unavailable'
  | 'unknownAccountState';

@Injectable({ providedIn: 'root' })
export class CurrentUserContextService {
  private readonly http = inject(HttpClient);
  private readonly endpointEnabled = inject(IDENTITY_CONTEXT_ENDPOINT_ENABLED);
  private readonly apiBaseUrl = inject(METRA_API_BASE_URL);

  readonly state = signal<CurrentUserSessionState>('unconfigured');
  readonly context = signal<CurrentUserContext | null>(null);

  async refresh(): Promise<void> {
    this.context.set(null);
    if (!this.endpointEnabled) {
      this.state.set('unconfigured');
      return;
    }

    this.state.set('loading');
    try {
      const context = await firstValueFrom(
        this.http.get<CurrentUserContext>(
          `${this.apiBaseUrl.endsWith('/') ? this.apiBaseUrl.slice(0, -1) : this.apiBaseUrl}/identity/me`,
          { withCredentials: true }
        ).pipe(timeout({ first: 15000 }))
      );
      if (!context || typeof context.userId !== 'string' || !context.userId.trim()) {
        this.state.set('unavailable');
        return;
      }

      this.context.set(context);
      this.state.set(this.mapAccountState(context.accountState));
    } catch (error: unknown) {
      this.context.set(null);
      this.state.set(this.mapHttpError(error));
    }
  }

  clear(): void {
    this.context.set(null);
    this.state.set('unauthenticated');
  }

  private mapAccountState(value: string): CurrentUserSessionState {
    switch (value.toLowerCase()) {
      case 'active':
        return 'active';
      case 'pendingstationapproval':
      case 'pendingsystemapproval':
      case 'pendingapproval':
        return 'pendingApproval';
      case 'suspended':
      case 'disabled':
      case 'rejected':
        return 'suspended';
      default:
        return 'unknownAccountState';
    }
  }

  private mapHttpError(error: unknown): CurrentUserSessionState {
    if (!(error instanceof HttpErrorResponse)) return 'unavailable';
    if (error.status === 401) return 'unauthenticated';
    if (error.status === 403) return 'forbidden';
    if (error.status === 404) return 'unconfigured';
    return 'unavailable';
  }
}
