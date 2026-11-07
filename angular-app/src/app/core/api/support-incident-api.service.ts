import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

@Injectable({ providedIn: 'root' })
export class SupportIncidentApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async list(stationId: string, limit = 50): Promise<unknown[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<unknown[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/support-incidents`,
      { headers, params }
    ));
  }

  async submit(stationId: string, body: Record<string, unknown>): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/support-incidents`,
      body,
      { headers }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يلزم تسجيل الدخول أولاً.');
    return new HttpHeaders({ Authorization: `Bearer ${token}`, Accept: 'application/json' });
  }
}
