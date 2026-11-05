import { HttpClient, HttpErrorResponse, HttpHeaders } from '@angular/common/http';
import { Injectable, InjectionToken, inject } from '@angular/core';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { firstValueFrom, timeout } from 'rxjs';
import { isSupabaseConfigured, supabaseConfig } from '../supabase/supabase.config';
import { RegistrationSubmissionStatus } from './registration-status.models';

export const RegistrationApiBaseUrl = new InjectionToken<string>(
  'REGISTRATION_API_BASE_URL',
  { providedIn: 'root', factory: () => '/api/v1' }
);

export type RegistrationStatusAccessErrorCode =
  | 'supabase_not_configured'
  | 'not_signed_in'
  | 'not_found'
  | 'forbidden'
  | 'unavailable';

export class RegistrationStatusAccessError extends Error {
  constructor(readonly code: RegistrationStatusAccessErrorCode) {
    super(code);
    this.name = 'RegistrationStatusAccessError';
  }
}

@Injectable({ providedIn: 'root' })
export class RegistrationStatusService {
  private readonly http = inject(HttpClient);
  private readonly apiBaseUrl = inject(RegistrationApiBaseUrl);
  private client: SupabaseClient | null = null;

  async getOwnStatus(requestId: string): Promise<RegistrationSubmissionStatus> {
    if (!isUuid(requestId)) {
      throw new RegistrationStatusAccessError('not_found');
    }

    const client = this.getClient();
    const { data, error } = await client.auth.getSession();
    if (error) {
      throw new RegistrationStatusAccessError('unavailable');
    }
    const accessToken = data.session?.access_token;
    if (!accessToken) {
      throw new RegistrationStatusAccessError('not_signed_in');
    }

    const baseUrl = this.apiBaseUrl.replace(/\/$/, '');
    try {
      return await firstValueFrom(
        this.http.get<RegistrationSubmissionStatus>(
          `${baseUrl}/registration-requests/${encodeURIComponent(requestId)}`,
          {
            headers: new HttpHeaders({ Authorization: `Bearer ${accessToken}` }),
            withCredentials: false
          }
        ).pipe(timeout({ first: 15000 }))
      );
    } catch (error: unknown) {
      if (error instanceof HttpErrorResponse) {
        if (error.status === 401) throw new RegistrationStatusAccessError('not_signed_in');
        if (error.status === 403) throw new RegistrationStatusAccessError('forbidden');
        if (error.status === 404) throw new RegistrationStatusAccessError('not_found');
      }
      throw new RegistrationStatusAccessError('unavailable');
    }
  }

  private getClient(): SupabaseClient {
    if (!isSupabaseConfigured()) {
      throw new RegistrationStatusAccessError('supabase_not_configured');
    }
    this.client ??= createClient(supabaseConfig.url, supabaseConfig.anonKey, {
      auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
    });
    return this.client;
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.trim());
}
