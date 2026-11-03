import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface ObservationQueueItem {
  id: string;
  station_id: string;
  created_by: string;
  observation_type: 'daily' | 'hourly' | 'phenomenon' | string;
  observed_at: string;
  payload: Record<string, unknown>;
  status: 'submitted';
  submitted_at: string | null;
  created_at: string;
}

export type ObservationDecision = 'approve' | 'return_for_correction';

@Injectable({ providedIn: 'root' })
export class ObservationApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getReviewQueue(stationId: string, limit = 50): Promise<ObservationQueueItem[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!stationId || limit < 1 || limit > 100) throw new Error('معرّف المحطة أو حد النتائج غير صالح.');
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<ObservationQueueItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations`,
      { headers, params }
    ));
  }

  async decide(stationId: string, observationId: string, decision: ObservationDecision, note?: string): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!stationId || !observationId) throw new Error('معرّف المحطة أو النشرة غير صالح.');
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations/${encodeURIComponent(observationId)}/decision`,
      { decision, note: note ?? null },
      { headers }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول قبل الوصول إلى بيانات المحطات.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
