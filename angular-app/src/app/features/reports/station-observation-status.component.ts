import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { StationContextService } from '../../core/station/station-context.service';
import { StationPickerComponent } from '../../core/station/station-picker.component';
import { ObservationApiService, ObservationQueueItem } from '../../core/api/observation-api.service';

@Component({
  standalone: true,
  imports: [CommonModule, StationPickerComponent],
  template: `
    <div class="page" dir="rtl">
      <header>
        <div>
          <span class="eyebrow">التقارير</span>
          <h1>حالة نشرات المحطة</h1>
          <p>ملخص النشرات المرسلة والمُرجَعة ضمن صلاحية المحطة فقط. الأوقات UTC.</p>
        </div>
        <button type="button" (click)="load()" [disabled]="loading || !stationId">تحديث</button>
      </header>
      <metra-station-picker [stationId]="stationId" (stationIdChange)="onStationPicked($event)"></metra-station-picker>

      <section class="notice" *ngIf="!api.isConfigured">يلزم ضبط عنوان API وتسجيل الدخول.</section>
      <section class="notice" *ngIf="api.isConfigured && !stationId">اختر محطة أو افتح مع <code>?stationId=UUID</code>.</section>
      <section class="notice error" *ngIf="error">{{ error }}</section>
      <section class="cards" *ngIf="stationId && !loading">
        <div class="card"><strong>{{ submittedCount }}</strong><span>مرسلة للمراجعة</span></div>
        <div class="card"><strong>{{ hourlySubmitted }}</strong><span>ساعي مرسل</span></div>
        <div class="card"><strong>{{ dailySubmitted }}</strong><span>يومي مرسل</span></div>
        <div class="card"><strong>{{ returnedCount }}</strong><span>مُرجَعة للتصحيح</span></div>
      </section>
      <section class="panel" *ngIf="!loading && stationId">
        <h2>آخر النشرات المرسلة</h2>
        <ul>
          <li *ngFor="let row of submitted">{{ row.observation_type }} — {{ formatUtc(row.observed_at) }} — {{ row.id }}</li>
          <li *ngIf="submitted.length === 0">لا توجد.</li>
        </ul>
        <h2>نشراتك المُرجَعة</h2>
        <ul>
          <li *ngFor="let row of returned">{{ row.observation_type }} — {{ formatUtc(row.observed_at) }} — {{ row['review_note'] || '—' }}</li>
          <li *ngIf="returned.length === 0">لا توجد.</li>
        </ul>
      </section>
    </div>
  `,
  styles: [`
    .page{max-width:960px;margin:0 auto;padding:1rem}
    header{display:flex;justify-content:space-between;gap:1rem;margin-bottom:1rem}
    .cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1rem;margin-bottom:1rem}
    .card{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:1rem;display:grid;gap:.35rem}
    .card strong{font-size:1.6rem}
    .panel{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:1rem}
    .notice{padding:.75rem 1rem;border-radius:8px;background:#f8fafc;margin-bottom:.75rem}
    .notice.error{background:#fef2f2;color:#991b1b}
    button{font:inherit;padding:.5rem .8rem;border:0;border-radius:8px;background:#0f766e;color:#fff;cursor:pointer}
    button:disabled{opacity:.6}
    @media(max-width:800px){.cards{grid-template-columns:1fr 1fr}}
  `]
})
export class StationObservationStatusComponent implements OnInit {
  readonly api = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);
  stationId = '';
  loading = false;
  error = '';
  submitted: ObservationQueueItem[] = [];
  returned: ObservationQueueItem[] = [];

  get submittedCount(): number { return this.submitted.length; }
  get returnedCount(): number { return this.returned.length; }
  get hourlySubmitted(): number {
    return this.submitted.filter(r => r.observation_type === 'hourly').length;
  }
  get dailySubmitted(): number {
    return this.submitted.filter(r => r.observation_type === 'daily').length;
  }

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    this.route.queryParamMap.subscribe((params) => {
      const fromQuery = params.get('stationId')?.trim() ?? '';
      if (this.stationContext.isUuid(fromQuery)) {
        this.stationContext.remember(fromQuery);
        this.stationId = fromQuery;
      } else {
        this.stationId = this.stationContext.resolveStationId(this.route);
      }
      if (this.stationId && this.api.isConfigured) void this.load();
    });
  }

  onStationPicked(stationId: string): void {
    this.stationId = stationId;
    this.error = '';
    if (this.stationId && this.api.isConfigured) void this.load();
  }

  formatUtc(value: string | null | undefined): string {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    const y = date.getUTCFullYear();
    const m = String(date.getUTCMonth() + 1).padStart(2, '0');
    const d = String(date.getUTCDate()).padStart(2, '0');
    const hh = String(date.getUTCHours()).padStart(2, '0');
    const mm = String(date.getUTCMinutes()).padStart(2, '0');
    return `${y}-${m}-${d} ${hh}:${mm} UTC`;
  }

  async load(): Promise<void> {
    if (!this.stationId || !this.api.isConfigured || this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      const [submitted, returned] = await Promise.all([
        this.api.getReviewQueue(this.stationId, 100),
        this.api.getReturnedObservations(this.stationId, 100),
      ]);
      this.submitted = submitted;
      this.returned = returned;
    } catch (error: unknown) {
      this.submitted = [];
      this.returned = [];
      if (error instanceof HttpErrorResponse) {
        if (error.status === 403) this.error = 'ليست لديك صلاحية تقارير هذه المحطة.';
        else if (error.status === 401) this.error = 'يلزم تسجيل الدخول.';
        else this.error = `تعذر تحميل التقرير (HTTP ${error.status}).`;
      } else {
        this.error = error instanceof Error ? error.message : 'خطأ غير متوقع.';
      }
    } finally {
      this.loading = false;
    }
  }
}
