import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
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

@Component({
  standalone: true,
  selector: 'metra-manual-archive',
  imports: [CommonModule, FormsModule],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <h1>تأكيد الأرشفة اليدوية لملفات Excel</h1>
          <p>
            يسجّل المدقق أنه أرشف ملف Excel يدوياً حتى لا يُنسى الإجراء.
            لا يرحّل التطبيق بيانات النشرات إلى قاعدة أرشيف، ولا يتصل بقاعدة الأرشيف.
          </p>
        </div>
        <button type="button" class="primary" [disabled]="loading" (click)="reload()">تحديث</button>
      </header>

      <div class="banner warn">
        التخزين الحالي للدفتر إداري مؤقت على الخادم إلى حين اعتماد مخطط قاعدة البيانات وترحيله بموافقتك.
        لا تُنقل أرصاد تلقائياً.
      </div>

      <div class="toolbar">
        <label>
          المحطة
          <select [(ngModel)]="stationId" (ngModelChange)="onStationChange($event)">
            <option value="">— اختر محطة —</option>
            <option *ngFor="let s of stations" [value]="s.id">{{ s.name_ar }}</option>
          </select>
        </label>
        <label>
          شهر الملخص (UTC)
          <input type="month" [(ngModel)]="monthInput" (change)="loadSummary()" />
        </label>
      </div>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner ok" *ngIf="feedback">{{ feedback }}</div>
      <div class="banner info" *ngIf="loading">جاري التحميل...</div>

      <div class="grid" *ngIf="stationId">
        <section class="card">
          <h2>تسجيل تأكيد أرشفة</h2>
          <label>نوع التقرير
            <select [(ngModel)]="form.reportKind">
              <option value="hourly">ساعي</option>
              <option value="daily">يومي</option>
              <option value="monthly">شهري</option>
              <option value="rainfall">مطري</option>
              <option value="climate">مناخي</option>
              <option value="other">أخرى</option>
            </select>
          </label>
          <label>بداية الفترة (UTC تاريخ)
            <input type="date" [(ngModel)]="form.periodStartUtc" />
          </label>
          <label>نهاية الفترة (UTC تاريخ)
            <input type="date" [(ngModel)]="form.periodEndUtc" />
          </label>
          <label>اسم ملف Excel
            <input [(ngModel)]="form.excelFileName" placeholder="example-2026-11.xlsx" />
          </label>
          <label>ملاحظة (اختياري)
            <textarea rows="3" [(ngModel)]="form.note" maxlength="2000"></textarea>
          </label>
          <button type="button" class="primary" [disabled]="saving" (click)="confirm()">تأكيد الأرشفة اليدوية</button>
        </section>

        <section class="card">
          <h2>ملخص الشهر (UTC)</h2>
          <div class="banner info" *ngIf="!summary">لا ملخص بعد.</div>
          <dl *ngIf="summary">
            <div><dt>الشهر</dt><dd>{{ summary.year }}-{{ summary.month | number:'2.0' }}</dd></div>
            <div><dt>عدد التأكيدات</dt><dd>{{ summary.confirmationCount }}</dd></div>
            <div><dt>أنواع التقارير</dt><dd>{{ summary.reportKinds.join('، ') || '—' }}</dd></div>
          </dl>
          <p class="footnote">الملخص إداري من دفتر التأكيد فقط، وليس حساب نواقص أرصاد معتمد حتى تُقرّ صيغ التجميع.</p>
        </section>
      </div>

      <section class="card" *ngIf="stationId">
        <h2>سجل التأكيدات</h2>
        <div class="banner info" *ngIf="!loading && rows.length===0">لا تأكيدات مسجّلة لهذه المحطة.</div>
        <div class="table-wrap" *ngIf="rows.length">
          <table>
            <thead>
              <tr>
                <th>النوع</th>
                <th>الفترة (UTC)</th>
                <th>الملف</th>
                <th>المؤكّد</th>
                <th>وقت التأكيد (UTC)</th>
                <th>ملاحظة</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let r of rows">
                <td>{{ r.reportKind }}</td>
                <td class="ltr">{{ r.periodStartUtc }} → {{ r.periodEndUtc }}</td>
                <td>{{ r.excelFileName }}</td>
                <td class="ltr">{{ r.actorUserId }}</td>
                <td class="ltr">{{ r.confirmedAtUtc }}</td>
                <td>{{ r.note || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1100px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px}
    h1{margin:0 0 6px;font-size:1.4rem} h2{margin:0 0 12px;font-size:1.05rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .toolbar{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-bottom:12px}
    .grid{display:grid;grid-template-columns:1.2fr 1fr;gap:14px;margin-bottom:14px}
    .card{border:1px solid #e4ebf0;border-radius:12px;padding:14px;background:#fff}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64;margin-bottom:10px}
    input,select,textarea{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .primary{background:#1f6f8b;color:#fff;border:0;border-radius:8px;padding:10px 14px;cursor:pointer}
    .banner{padding:12px;border-radius:10px;margin-bottom:10px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.ok{background:#e8f6ee;color:#1f6b3c}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .banner.warn{background:#fff7e8;color:#8a5a12}
    .table-wrap{overflow:auto}
    table{width:100%;border-collapse:collapse;min-width:720px}
    th,td{padding:10px;border-bottom:1px solid #edf1f4;text-align:right;font-size:13px}
    th{background:#f5f8fa;color:#5b6a74}
    .ltr{direction:ltr;text-align:right}
    dl{margin:0;display:grid;gap:8px}
    dl > div{display:flex;justify-content:space-between;gap:10px;border-bottom:1px solid #f0f3f5;padding:6px 0}
    dt{color:#6a7882} dd{margin:0;font-weight:700}
    .footnote{margin-top:10px;font-size:11px;color:#7a8791}
    @media(max-width:900px){.grid,.toolbar{grid-template-columns:1fr}}
  `]
})
export class ManualArchiveComponent implements OnInit {
  private readonly api = inject(ManualArchiveApiService);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);

  stations: StationDirectoryItem[] = [];
  stationId = '';
  rows: ManualArchiveConfirmation[] = [];
  summary: ManualArchiveMonthlySummary | null = null;
  loading = false;
  saving = false;
  error = '';
  feedback = '';
  monthInput = new Date().toISOString().slice(0, 7);

  form = {
    reportKind: 'daily',
    periodStartUtc: new Date().toISOString().slice(0, 10),
    periodEndUtc: new Date().toISOString().slice(0, 10),
    excelFileName: '',
    note: ''
  };

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    void this.loadStations().then(() => this.reload());
  }

  onStationChange(id: string): void {
    if (this.stationContext.isUuid(id)) this.stationContext.remember(id);
    void this.reload();
  }

  async loadStations(): Promise<void> {
    try {
      if (this.stationsApi.isConfigured) this.stations = await this.stationsApi.getAllStations();
    } catch { this.stations = []; }
  }

  async reload(): Promise<void> {
    this.error = '';
    this.feedback = '';
    this.rows = [];
    this.summary = null;
    if (!this.stationId) return;
    this.loading = true;
    try {
      this.rows = await this.api.list(this.stationId);
      await this.loadSummary();
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تحميل دفتر الأرشفة.';
    } finally {
      this.loading = false;
    }
  }

  async loadSummary(): Promise<void> {
    if (!this.stationId || !this.monthInput.includes('-')) return;
    const [y, m] = this.monthInput.split('-').map(Number);
    try {
      this.summary = await this.api.monthlySummary(this.stationId, y, m);
    } catch {
      this.summary = null;
    }
  }

  async confirm(): Promise<void> {
    this.error = '';
    this.feedback = '';
    if (!this.stationId) {
      this.error = 'اختر محطة أولاً.';
      return;
    }
    if (!this.form.excelFileName.trim()) {
      this.error = 'اسم ملف Excel مطلوب.';
      return;
    }
    this.saving = true;
    try {
      await this.api.confirm(this.stationId, {
        reportKind: this.form.reportKind,
        periodStartUtc: this.form.periodStartUtc,
        periodEndUtc: this.form.periodEndUtc,
        excelFileName: this.form.excelFileName.trim(),
        note: this.form.note.trim() || undefined
      });
      this.feedback = 'تم تسجيل تأكيد الأرشفة اليدوية.';
      this.form.excelFileName = '';
      this.form.note = '';
      await this.reload();
    } catch (e: any) {
      const msg = e?.error?.error === 'duplicate_archive_confirmation'
        ? 'تأكيد مكرر لنفس الملف والفترة والنوع.'
        : (e instanceof Error ? e.message : 'تعذر تسجيل التأكيد.');
      this.error = msg;
    } finally {
      this.saving = false;
    }
  }
}
