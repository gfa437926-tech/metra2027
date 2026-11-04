import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface AuthorityItem {
  id: string;
  authority_code: string;
  name_ar: string;
  name_en: string;
  is_national: boolean;
  country_id: string;
  country_name_ar: string;
  country_name_en: string;
}
export interface AuthorityMembershipRole {
  role_code: string;
  name_ar: string;
  name_en: string;
  description_ar: string | null;
  description_en: string | null;
  is_requestable: boolean;
  display_order: number;
}
export interface AuthorityPermissionOption { permission_code: string; }
export type AuthorityAccessKind = 'membership' | 'permission_grant' | 'membership_active' | 'permission_grant_active';
export interface AuthorityAccessQueueItem {
  id: string;
  user_id: string;
  authority_id: string;
  role_code?: string;
  permission_code?: string;
  status: string;
  reason: string;
  requested_by: string;
  created_at: string;
  valid_from: string;
  valid_to: string | null;
}
export interface AuthorityAccessAuditItem {
  id: number;
  target_kind: AuthorityAccessKind;
  target_id: string;
  authority_id: string;
  subject_user_id: string;
  actor_user_id: string;
  action_code: string;
  from_status: string | null;
  to_status: string;
  reason: string;
  occurred_at: string;
}

@Injectable({ providedIn: 'root' })
export class AuthorityAccessApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async getAuthorities(): Promise<AuthorityItem[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AuthorityItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/authorities`, { headers }
    ));
  }

  async getMembershipRoles(authorityId: string): Promise<AuthorityMembershipRole[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AuthorityMembershipRole[]>(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/membership-roles`,
      { headers }
    ));
  }

  async getPermissionOptions(authorityId: string): Promise<AuthorityPermissionOption[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AuthorityPermissionOption[]>(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/permission-options`,
      { headers }
    ));
  }

  async requestMembership(authorityId: string, roleCode: string, reason: string, userId?: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/memberships`,
      { userId: userId?.trim() || null, roleCode, reason }, { headers }
    ));
  }

  async requestPermissionGrant(authorityId: string, permissionCode: string, reason: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/permission-grants`,
      { permissionCode, reason }, { headers }
    ));
  }

  async getQueue(authorityId: string, kind: AuthorityAccessKind): Promise<AuthorityAccessQueueItem[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AuthorityAccessQueueItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/access-queue`,
      { headers, params: { kind, limit: '100' } }
    ));
  }

  async decideMembership(authorityId: string, id: string, decision: 'approve' | 'reject', reason: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/memberships/${encodeURIComponent(id)}/decision`,
      { decision, reason }, { headers }
    ));
  }

  async decidePermissionGrant(authorityId: string, id: string, decision: 'approve' | 'reject', reason: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/permission-grants/${encodeURIComponent(id)}/decision`,
      { decision, reason }, { headers }
    ));
  }


  async revokeMembership(authorityId: string, id: string, reason: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/memberships/${encodeURIComponent(id)}/revocation`,
      { reason }, { headers }
    ));
  }

  async revokePermissionGrant(authorityId: string, id: string, reason: string): Promise<unknown> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.post(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/permission-grants/${encodeURIComponent(id)}/revocation`,
      { reason }, { headers }
    ));
  }

  async getAudit(authorityId: string): Promise<AuthorityAccessAuditItem[]> {
    const headers = await this.authHeaders();
    return firstValueFrom(this.http.get<AuthorityAccessAuditItem[]>(
      `${metraConfig.apiBaseUrl}/api/v1/authorities/${encodeURIComponent(authorityId)}/access-audit`,
      { headers, params: { limit: '200' } }
    ));
  }

  private async authHeaders(): Promise<HttpHeaders> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات Supabase العامة أولاً.');
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول أولاً.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
