import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface EquipmentFaultItem {
  id: string;
  station_id: string;
  reporter_user_id: string;
  equipment_category: string;
  equipment_name: string;
  description: string;
  severity: string;
  status: string;
  is_operationally_blocking: boolean;
  occurred_at: string;
  assigned_to: string | null;
  progress_percent: number;
  progress_note: string | null;
  created_at: string;
  updated_at: string;
}

export interface EquipmentFaultSubmission {
  equipmentCategory: string;
  equipmentName: string;
  description: string;
  severity: 'Low' | 'Medium' | 'High' | 'Critical' | string;
  occurredAt: string;
  isOperationallyBlocking?: boolean;
}

@Injectable({ providedIn: 'root' })
export class EquipmentFaultApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async list(stationId: string, limit = 50): Promise<EquipmentFaultItem[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId) || limit < 1 || limit > 100) throw new Error('معرّف المحطة أو حد النتائج غير صالح.');
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<EquipmentFaultItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/equipment-faults`,
      { headers, params }
    ));
  }

  async submit(stationId: string, body: EquipmentFaultSubmission): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId)) throw new Error('معرّف المحطة غير صالح.');
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/equipment-faults`,
      body,
      { headers }
    ));
  }

  async transition(
    stationId: string,
    faultId: string,
    toStatus: string,
    note?: string,
    progressPercent?: number,
    assignedTo?: string
  ): Promise<unknown> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId) || !this.isUuid(faultId)) throw new Error('معرّف المحطة أو البلاغ غير صالح.');
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/equipment-faults/${encodeURIComponent(faultId)}/transitions`,
      { toStatus, note, progressPercent, assignedTo },
      { headers }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يلزم تسجيل الدخول أولاً.');
    return new HttpHeaders({
      Authorization: `Bearer ${token}`,
      Accept: 'application/json'
    });
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }
}
