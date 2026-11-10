import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import {
  ManualArchiveApiService,
  ManualArchiveConfirmation,
  ManualArchiveMonthlySummary
} from '../../core/api/manual-archive-api.service';
import { StationContextService } from '../../core/station/station-context.service';

/**
 * Monthly administrative view.
 * Does NOT invent climate aggregations until formulas are approved.
 * Sources: station directory + manual archive confirmation ledger only.
 */
@Component({
  standalone: true,
  selector: 'metra-monthly-reports',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <h1>التقارير الشهرية (إدارية)</h1>
          <p>
            تعرض هذه الشاشة ملخص تأكيدات أرشفة Excel اليدوية ضمن المحطة المختارة.
            لا تُعرض مجاميع أرصاد مناخية حتى تُعتمد صيغ التجميع رسمياً.
          </p>
        </div>
        <div class="header-actions">
          <a routerLink="/admin/manual-archive" [queryParams]="stationId ? { stationId: stationId } : {}">دفتر الأرشفة</a>
          <button type="button" class="primary" [disabled]="loading || !stationId" (click)="reload()">تحديث</button>
        </div>
      </header>

      <div class="banner warn">
        مصدر الأرقام هنا إداري (تأكيدات أرشفة فقط). أي خانة أرصاد غير مربوطة تظهر كـ «غير متاح» وليست صفراً وهمياً.
      </div>

      <div class="toolbar">
        <label>
          المحطة
          <select [(ngModel)]="stationId" (ngModelChange)="onStationChange($event)">
            <option value="">— اختر محطة —</option>
            <option *ngFor="let s of stations" [value]="s.id">
              {{ s.name_ar }} ({{ s.local_station_code || s.id }})
            </option>
          </select>
        </label>
        <label>
          الشهر (UTC)
          <input type="month" [(ngModel)]="monthInput" (change)="reload()" />
        </label>
      </div>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner info" *ngIf="loading">جاري التحميل من الخادم...</div>
      <div class="banner info" *ngIf="!loading && !stationId">اختر محطة مصرّحاً بها لعرض الملخص الإداري.</div>

      <section class="stats" *ngIf="stationId && !loading">
        <article>
          <span>تأكيدات الأرشفة في الشهر</span>
          <strong>{{ summary?.confirmationCount ?? '—' }}</strong>
        </article>
        <article>
          <span>أنواع التقارير المؤكدة</span>
          <strong>{{ (summary?.reportKinds?.length) || 0 }}</strong>
        </article>
        <article>
          <span>مجاميع الأرصاد المناخية</span>
          <strong class="muted">غير متاح</strong>
        </article>
        <article>
          <span>مرجع الزمن</span>
          <strong>UTC فقط</strong>
        </article>
      </section>

      <section class="card" *ngIf="stationId && summary">
        <h2>ملخص تأكيدات الأرشفة — {{ summary.year }}-{{ pad(summary.month) }}</h2>
        <p *ngIf="summary.reportKinds.length">الأنواع: {{ summary.reportKinds.join('، ') }}</p>
        <p *ngIf="!summary.reportKinds.length">لا أنواع مؤكدة في هذا الشهر.</p>
      </section>

      <section class="card" *ngIf="stationId">
        <h2>سجل التأكيدات (حتى 50)</h2>
        <div class="banner info" *ngIf="!loading && rows.length === 0">لا تأكيدات في دفتر الأرشفة لهذه المحطة.</div>
        <div class="table-wrap" *ngIf="rows.length">
          <table>
            <thead>
              <tr>
                <th>النوع</th>
                <th>الفترة (UTC)</th>
                <th>الملف</th>
                <th>وقت التأكيد (UTC)</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let r of rows">
                <td>{{ r.reportKind }}</td>
                <td class="ltr">{{ r.periodStartUtc }} → {{ r.periodEndUtc }}</td>
                <td>{{ r.excelFileName }}</td>
                <td class="ltr">{{ r.confirmedAtUtc }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1100px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px;flex-wrap:wrap}
    .header-actions{display:flex;gap:12px;align-items:center}
    .header-actions a{color:#1f6f8b;font-weight:700;text-decoration:none}
    h1{margin:0 0 6px;font-size:1.4rem} h2{margin:0 0 10px;font-size:1.05rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .toolbar{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-bottom:12px}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64}
    input,select{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .primary{background:#1f6f8b;color:#fff;border:0;border-radius:8px;padding:10px 14px;cursor:pointer}
    .banner{padding:12px;border-radius:10px;margin-bottom:10px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .banner.warn{background:#fff7e8;color:#8a5a12}
    .stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:14px}
    .stats article{background:#fff;border:1px solid #e4ebf0;border-radius:12px;padding:12px;display:grid;gap:6px}
    .stats span{font-size:12px;color:#6a7882}
    .stats strong{font-size:1.25rem}
    .stats .muted{color:#9aa6af;font-size:1rem}
    .card{border:1px solid #e4ebf0;border-radius:12px;padding:14px;background:#fff;margin-bottom:12px}
    .table-wrap{overflow:auto}
    table{width:100%;border-collapse:collapse;min-width:640px}
    th,td{padding:10px;border-bottom:1px solid #edf1f4;text-align:right;font-size:13px}
    th{background:#f5f8fa;color:#5b6a74}
    .ltr{direction:ltr;text-align:right}
    @media(max-width:900px){.stats,.toolbar{grid-template-columns:1fr 1fr}.stats{grid-template-columns:1fr}}
  `]
})
export class MonthlyReportsComponent implements OnInit {
  private readonly archiveApi = inject(ManualArchiveApiService);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);

  stations: StationDirectoryItem[] = [];
  stationId = '';
  monthInput = new Date().toISOString().slice(0, 7);
  rows: ManualArchiveConfirmation[] = [];
  summary: ManualArchiveMonthlySummary | null = null;
  loading = false;
  error = '';

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    void this.loadStations().then(() => this.reload());
  }

  pad(n: number): string {
    return String(n).padStart(2, '0');
  }

  onStationChange(id: string): void {
    if (this.stationContext.isUuid(id)) this.stationContext.remember(id);
    void this.reload();
  }

  async loadStations(): Promise<void> {
    try {
      if (this.stationsApi.isConfigured) {
        this.stations = await this.stationsApi.getAllStations();
      }
    } catch {
      this.stations = [];
    }
  }

  async reload(): Promise<void> {
    this.error = '';
    this.rows = [];
    this.summary = null;
    if (!this.stationId) return;
    this.loading = true;
    try {
      if (!this.archiveApi.isConfigured) {
        throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة أولاً.');
      }
      this.rows = await this.archiveApi.list(this.stationId, 50);
      if (this.monthInput.includes('-')) {
        const [y, m] = this.monthInput.split('-').map(Number);
        this.summary = await this.archiveApi.monthlySummary(this.stationId, y, m);
        // Filter list display to selected month when periodStart matches (best-effort administrative filter).
        const ym = `${y}-${String(m).padStart(2, '0')}`;
        this.rows = this.rows.filter(r => String(r.periodStartUtc).startsWith(ym));
      }
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تحميل التقرير الشهري الإداري.';
    } finally {
      this.loading = false;
    }
  }
}
