import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface StationUserItem {
  user_id: string;
  first_name: string;
  father_name: string | null;
  last_name: string;
  phone: string | null;
  account_state: string | null;
  state_reason: string | null;
  assignment_id: string;
  assignment_role_code: string;
  assignment_status: string;
  valid_from: string;
  valid_to: string | null;
  station_id: string;
  role_name_ar: string | null;
  role_name_en: string | null;
}

@Injectable({ providedIn: 'root' })
export class StationUserDirectoryApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getUsers(stationId: string, limit = 250): Promise<StationUserItem[]> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    if (!this.isUuid(stationId)) throw new Error('يجب اختيار محطة صحيحة أولاً.');
    if (!Number.isInteger(limit) || limit < 1 || limit > 500) throw new Error('حد المستخدمين غير صالح.');
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول أولاً.');
    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
    const params = new HttpParams().set('limit', String(limit));
    return firstValueFrom(this.http.get<StationUserItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/users`,
      { headers, params }
    ));
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }
}
