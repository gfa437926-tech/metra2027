import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { isApiConfigured, metraConfig } from '../supabase/supabase.config';
import { SupabaseAuthService } from '../supabase/supabase-auth.service';

export interface ManualArchiveConfirmation {
  id: string;
  stationId: string;
  actorUserId: string;
  reportKind: string;
  periodStartUtc: string;
  periodEndUtc: string;
  excelFileName: string;
  note: string | null;
  confirmedAtUtc: string;
}

export interface ManualArchiveMonthlySummary {
  year: number;
  month: number;
  confirmationCount: number;
  reportKinds: string[];
}

@Injectable({ providedIn: 'root' })
export class ManualArchiveApiService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(SupabaseAuthService);

  get isConfigured(): boolean {
    return isApiConfigured() && this.auth.isConfigured;
  }

  async list(stationId: string, limit = 50): Promise<ManualArchiveConfirmation[]> {
    const headers = await this.authHeaders();
    const params = new HttpParams().set('limit', String(limit));
    const rows = await firstValueFrom(this.http.get<any[]>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/archive-confirmations`,
      { headers, params }
    ));
    return (rows ?? []).map(r => this.mapRow(r));
  }

  async confirm(stationId: string, body: {
    reportKind: string;
    periodStartUtc: string;
    periodEndUtc: string;
    excelFileName: string;
    note?: string;
  }): Promise<ManualArchiveConfirmation> {
    const headers = await this.authHeaders();
    const row = await firstValueFrom(this.http.post<any>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/archive-confirmations`,
      body,
      { headers }
    ));
    return this.mapRow(row);
  }

  async monthlySummary(stationId: string, year: number, month: number): Promise<ManualArchiveMonthlySummary> {
    const headers = await this.authHeaders();
    const params = new HttpParams().set('year', String(year)).set('month', String(month));
    return firstValueFrom(this.http.get<ManualArchiveMonthlySummary>(
      `${metraConfig.apiBaseUrl}/api/v1/stations/${encodeURIComponent(stationId)}/archive-confirmations/monthly-summary`,
      { headers, params }
    ));
  }

  private mapRow(r: any): ManualArchiveConfirmation {
    return {
      id: r.id ?? r.Id,
      stationId: r.stationId ?? r.StationId,
      actorUserId: r.actorUserId ?? r.ActorUserId,
      reportKind: r.reportKind ?? r.ReportKind,
      periodStartUtc: r.periodStartUtc ?? r.PeriodStartUtc,
      periodEndUtc: r.periodEndUtc ?? r.PeriodEndUtc,
      excelFileName: r.excelFileName ?? r.ExcelFileName,
      note: r.note ?? r.Note ?? null,
      confirmedAtUtc: r.confirmedAtUtc ?? r.ConfirmedAtUtc
    };
  }

  private async authHeaders(): Promise<HttpHeaders> {
    if (!this.isConfigured) throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة أولاً.');
    const token = await this.auth.getAccessToken();
    if (!token) throw new Error('يجب تسجيل الدخول قبل تأكيد الأرشفة.');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }
}
