import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface AssignableStationRole {
  role_code: 'observer' | 'station_auditor';
  name_ar: string;
  name_en: string | null;
}

export interface StationAssignmentSubmission {
  userId: string;
  roleCode: 'observer' | 'station_auditor';
  reason: string;
  validFrom: string;
  validTo: string | null;
}

@Injectable({ providedIn: 'root' })
export class StationAssignmentApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getAssignableRoles(stationId: string): Promise<AssignableStationRole[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AssignableStationRole[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/assignable-roles`,
      { headers }
    ));
  }

  async request(stationId: string, request: StationAssignmentSubmission): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/assignments`,
      {
        userId: request.userId,
        roleCode: request.roleCode,
        reason: request.reason,
        validFrom: request.validFrom,
        validTo: request.validTo
      },
      { headers }
    ));
  }

  async decide(
    stationId: string, assignmentId: string, decision: 'approve' | 'reject', note: string
  ): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/assignments/${encodeURIComponent(assignmentId)}/decision`,
      { decision, note: note || null },
      { headers }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول أولاً.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
