import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export type RegistrationReviewStage = 'station' | 'system';
export type RegistrationDecision = 'approve' | 'reject';

export interface RegistrationRequestItem {
  id: string;
  user_id: string;
  requested_station_id: string;
  requested_role_code: string;
  status: string;
  phone_snapshot: string | null;
  terms_version: string;
  submitted_at: string;
  metra_user_profiles?: {
    first_name: string;
    father_name: string | null;
    last_name: string;
  } | null;
  metra_role_catalogue?: {
    name_ar: string | null;
    name_en: string | null;
  } | null;
  station_catalogue?: {
    name_ar: string | null;
    name_en: string | null;
    local_station_code: string | null;
  } | null;
}

@Injectable({ providedIn: 'root' })
export class RegistrationReviewApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getQueue(stationId: string, stage: RegistrationReviewStage, limit = 50): Promise<RegistrationRequestItem[]> {
    this.assertReady(stationId);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      throw new Error('حد طلبات التسجيل يجب أن يكون بين 1 و100.');
    }
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    const path = stage === 'station' ? 'registration-requests' : 'system-registration-requests';
    return firstValueFrom(this.http.get<RegistrationRequestItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/${path}`,
      { headers, params }
    ));
  }

  async decide(
    stationId: string,
    requestId: string,
    stage: RegistrationReviewStage,
    decision: RegistrationDecision,
    note?: string
  ): Promise<unknown> {
    this.assertReady(stationId);
    if (!this.isUuid(requestId)) throw new Error('معرّف طلب التسجيل غير صالح.');
    if (decision === 'reject' && !note?.trim()) throw new Error('سبب الرفض مطلوب.');
    if (note && (note.length > 2000 || note !== note.trim() || /[\\u0000-\\u001f\\u007f]/.test(note))) {
      throw new Error('ملاحظة المراجعة غير صالحة.');
    }
    const headers = await this.authHeaders();
    const path = stage === 'station' ? 'registration-requests' : 'system-registration-requests';
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/${path}/${encodeURIComponent(requestId)}/decision`,
      { decision, note: note ?? null },
      { headers }
    ));
  }

  private assertReady(stationId: string): void {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId)) throw new Error('يجب اختيار محطة صحيحة أولاً.');
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }

  private async authHeaders(): Promise<HttpHeaders> {
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول قبل مراجعة طلبات التسجيل.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
