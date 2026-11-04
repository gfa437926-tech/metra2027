import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface RequestableRole {
  role_code: string;
  name_ar: string;
  name_en: string | null;
}

export interface RegistrationStatus {
  account_state: string | null;
  state_reason: string | null;
  request_id: string | null;
  request_status: string | null;
  submitted_at: string | null;
  review_note: string | null;
}

export interface RegistrationSubmission {
  firstName: string;
  fatherName: string;
  lastName: string;
  phone: string | null;
  roleCode: string;
  stationId: string;
  termsVersion: 'metra-terms-2026-11';
  idempotencyKey: string;
}

@Injectable({ providedIn: 'root' })
export class RegistrationSubmissionApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getRequestableRoles(): Promise<RequestableRole[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<RequestableRole[]>(
      `${metraConfig.apiBaseUrl}/api/v1/registration-roles`, { headers }
    ));
  }

  async getMyStatus(): Promise<RegistrationStatus> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<RegistrationStatus>(
      `${metraConfig.apiBaseUrl}/api/v1/account/registration-status`, { headers }
    ));
  }

  async submit(request: RegistrationSubmission): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/registration-requests`, request, { headers }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول أولاً لإكمال طلب التسجيل.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
