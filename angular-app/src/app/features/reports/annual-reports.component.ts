import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import { StationContextService } from '../../core/station/station-context.service';

/** Annual climate summary is blocked until aggregation contracts are approved. */
@Component({
  standalone: true,
  selector: 'metra-annual-reports',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header>
        <div>
          <h1>التقارير السنوية</h1>
          <p>الملخصات السنوية والمقارنات غير مربوطة بمصدر أرصاد معتمد بعد.</p>
        </div>
        <span class="badge">غير مربوط</span>
      </header>

      <div class="banner warn">
        لا تُحتسب قيم مناخية سنوية في هذه الشاشة. أي «مؤشر» يظهر كغير متاح وليس صفراً.
      </div>

      <div class="toolbar">
        <label>
          المحطة
          <select [(ngModel)]="stationId" (ngModelChange)="remember($event)">
            <option value="">— اختر محطة —</option>
            <option *ngFor="let s of stations" [value]="s.id">{{ s.name_ar }}</option>
          </select>
        </label>
        <label>
          السنة (UTC)
          <select [(ngModel)]="year">
            <option *ngFor="let y of years" [value]="y">{{ y }}</option>
          </select>
        </label>
      </div>

      <section class="stats">
        <article><span>المحطة</span><strong>{{ stationLabel }}</strong></article>
        <article><span>السنة</span><strong>{{ year }}</strong></article>
        <article><span>معدل الحرارة</span><strong class="muted">غير متاح</strong></article>
        <article><span>مجموع الهطل</span><strong class="muted">غير متاح</strong></article>
      </section>

      <div class="links">
        <a routerLink="/reports/monthly" [queryParams]="qp">التقرير الشهري الإداري</a>
        <a routerLink="/reports/observation-status" [queryParams]="qp">حالة النشرات</a>
        <a routerLink="/admin/manual-archive" [queryParams]="qp">تأكيد أرشفة Excel</a>
      </div>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:960px;margin:0 auto}
    header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px;flex-wrap:wrap}
    h1{margin:0 0 6px;font-size:1.4rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .badge{background:#fff3cd;color:#856404;padding:8px 12px;border-radius:8px;font-weight:700;height:fit-content}
    .banner{padding:12px;border-radius:10px;margin-bottom:12px}
    .banner.warn{background:#fff7e8;color:#8a5a12}
    .toolbar{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-bottom:12px}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64}
    select{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:14px}
    .stats article{background:#fff;border:1px solid #e4ebf0;border-radius:12px;padding:12px;display:grid;gap:6px}
    .stats span{font-size:12px;color:#6a7882}
    .muted{color:#9aa6af}
    .links{display:flex;flex-wrap:wrap;gap:12px}
    .links a{color:#1f6f8b;font-weight:700;text-decoration:none}
    @media(max-width:800px){.stats,.toolbar{grid-template-columns:1fr}}
  `]
})
export class AnnualReportsComponent implements OnInit {
  private readonly stationsApi = inject(ObservationApiService);
  private readonly stationContext = inject(StationContextService);
  private readonly route = inject(ActivatedRoute);

  stations: StationDirectoryItem[] = [];
  stationId = '';
  year = new Date().getUTCFullYear();
  years = Array.from({ length: 8 }, (_, i) => this.year - i);

  get qp(): Record<string, string> {
    return this.stationId ? { stationId: this.stationId } : {};
  }

  get stationLabel(): string {
    const s = this.stations.find(x => x.id === this.stationId);
    return s?.name_ar || (this.stationId ? this.stationId : '—');
  }

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    void this.loadStations();
  }

  remember(id: string): void {
    if (this.stationContext.isUuid(id)) this.stationContext.remember(id);
  }

  async loadStations(): Promise<void> {
    try {
      if (this.stationsApi.isConfigured) this.stations = await this.stationsApi.getAllStations();
    } catch {
      this.stations = [];
    }
  }
}
