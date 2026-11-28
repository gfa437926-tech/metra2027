import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface StationAuditItem {
  id: number;
  entity_type: string;
  entity_id: string;
  action: string;
  actor_id: string | null;
  reason: string | null;
  occurred_at: string;
  target_user_id: string | null;
  role_code: string | null;
  previous_status: string | null;
  resulting_status: string | null;
  valid_from: string | null;
  valid_to: string | null;
}

@Injectable({ providedIn: 'root' })
export class StationAuditApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  async getAudit(stationId: string, limit = 100): Promise<StationAuditItem[]> {
    if (!isApiConfigured() || !this.auth.isConfigured) {
      throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    }
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(stationId)) {
      throw new Error('يجب اختيار محطة صحيحة أولاً.');
    }
    if (!Number.isInteger(limit) || limit < 1 || limit > 250) {
      throw new Error('حد سجل التدقيق يجب أن يكون بين 1 و250.');
    }
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول أولاً.');
    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<StationAuditItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/audit-log`,
      { headers, params }
    ));
  }
}
