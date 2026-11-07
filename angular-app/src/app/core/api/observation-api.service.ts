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

export interface StationDirectoryItem {
  id: string;
  local_station_code: string | null;
  wmo_station_id: string | null;
  name_ar: string;
  name_en: string | null;
  station_type: 'classic' | 'automatic' | 'synoptic' | string;
  operational_status: string;
  approval_status: string;
  is_demo: boolean;
  elevation_m: number | null;
  station_coordinates: Array<{
    latitude: number;
    longitude: number;
    coordinate_source: string | null;
    accuracy_m: number | null;
  }>;
}

export type ObservationType = 'daily' | 'hourly' | 'phenomenon';
export type ObservationDecision = 'approve' | 'return_for_correction';

export interface ObservationSubmission {
  idempotencyKey: string;
  observationType: ObservationType;
  observedAt: string;
  payload: Record<string, unknown>;
  submit: boolean;
}

@Injectable({ providedIn: 'root' })
export class ObservationApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getStations(limit = 250, offset = 0): Promise<StationDirectoryItem[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!Number.isInteger(limit) || limit < 1 || limit > 500 ||
        !Number.isInteger(offset) || offset < 0) {
      throw new Error('قيم ترقيم صفحات دليل المحطات غير صالحة.');
    }
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit)).set('offset', String(offset));
    return firstValueFrom(this.http.get<StationDirectoryItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations`, { headers, params }
    ));
  }

  async getAllStations(pageSize = 500): Promise<StationDirectoryItem[]> {
    const stations: StationDirectoryItem[] = [];
    let offset = 0;
    while (true) {
      const page = await this.getStations(pageSize, offset);
      stations.push(...page);
      if (page.length < pageSize) return stations;
      offset += page.length;
    }
  }

  async submitObservation(stationId: string, submission: ObservationSubmission): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId)) throw new Error('يجب اختيار محطة ذات معرّف صحيح قبل إرسال النشرة.');
    if (!submission.idempotencyKey.trim() || submission.idempotencyKey.length > 128) {
      throw new Error('مفتاح منع التكرار غير صالح.');
    }
    if (!['daily', 'hourly', 'phenomenon'].includes(submission.observationType)) {
      throw new Error('نوع النشرة غير مدعوم.');
    }
    if (!Number.isFinite(Date.parse(submission.observedAt)) ||
        !submission.payload || Array.isArray(submission.payload) ||
        typeof submission.payload !== 'object') {
      throw new Error('تاريخ الرصد أو محتوى النشرة غير صالح.');
    }

    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations`,
      {
        idempotencyKey: submission.idempotencyKey,
        observationType: submission.observationType,
        observedAt: submission.observedAt,
        payload: submission.payload,
        submit: submission.submit
      },
      { headers }
    ));
  }

  async getReviewQueue(stationId: string, limit = 50): Promise<ObservationQueueItem[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId) || limit < 1 || limit > 100) throw new Error('معرّف المحطة أو حد النتائج غير صالح.');
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<ObservationQueueItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations`,
      { headers, params }
    ));
  }

  async decide(stationId: string, observationId: string, decision: ObservationDecision, note?: string): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId) || !this.isUuid(observationId)) throw new Error('معرّف المحطة أو النشرة غير صالح.');
    if (decision === 'return_for_correction' && !note?.trim()) {
      throw new Error('يجب إدخال سبب الإرجاع قبل إعادة النشرة للتصحيح.');
    }
    if (note && note.length > 2000) throw new Error('سبب القرار يتجاوز الحد المسموح (2000 حرف).');
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations/${encodeURIComponent(observationId)}/decision`,
      { decision, note: note ?? null },
      { headers }
    ));
  }


  async resubmitObservation(
    stationId: string,
    observationId: string,
    payload?: Record<string, unknown>
  ): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId) || !this.isUuid(observationId)) {
      throw new Error('معرّف المحطة أو النشرة غير صالح.');
    }
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/observations/${encodeURIComponent(observationId)}/resubmit`,
      { payload: payload ?? null },
      { headers }
    ));
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }

  private async authHeaders(): Promise<HttpHeaders> {
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول قبل الوصول إلى بيانات المحطات.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
