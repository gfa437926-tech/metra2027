import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import { StationContextService } from '../../core/station/station-context.service';
import { ActivatedRoute } from '@angular/router';

/**
 * Climate aggregates are not implemented until formulas and report APIs are approved.
 * This page must not accept or display invented meteorological values.
 */
@Component({
  standalone: true,
  selector: 'metra-climate-reports',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header>
        <div>
          <h1>التقارير المناخية</h1>
          <p>التجميع المناخي (معدلات، قيم قصوى، اكتمال) غير مفعّل حتى اعتماد الصيغ وعقود API.</p>
        </div>
        <span class="badge">غير مربوط بأرصاد مجمّعة</span>
      </header>

      <div class="banner warn">
        لن تُعرض أرقام مناخية افتراضية. استخدم مسارات الرصد الفعلية للإدخال والمراجعة.
      </div>

      <div class="toolbar">
        <label>
          المحطة (للتنقل فقط)
          <select [(ngModel)]="stationId" (ngModelChange)="remember($event)">
            <option value="">— اختر محطة —</option>
            <option *ngFor="let s of stations" [value]="s.id">{{ s.name_ar }}</option>
          </select>
        </label>
      </div>

      <div class="links">
        <a routerLink="/reports/hourly" [queryParams]="qp">إدخال ساعي</a>
        <a routerLink="/reports/daily" [queryParams]="qp">إدخال يومي</a>
        <a routerLink="/observations/workflow" [queryParams]="qp">مراجعة النشرات</a>
        <a routerLink="/reports/monthly" [queryParams]="qp">التقرير الشهري الإداري</a>
        <a routerLink="/admin/manual-archive" [queryParams]="qp">تأكيد أرشفة Excel</a>
      </div>

      <section class="card">
        <h2>ما ينقص للتفعيل</h2>
        <ul>
          <li>اعتماد صيغ التجميع والمناخ من مالك المشروع.</li>
          <li>واجهة API قراءة مجاميع ضمن نطاق المحطة.</li>
          <li>اختبارات مطابقة للأرصاد المصدرية (UTC فقط).</li>
        </ul>
      </section>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:960px;margin:0 auto}
    header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px;flex-wrap:wrap}
    h1{margin:0 0 6px;font-size:1.4rem} h2{margin:0 0 10px}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .badge{background:#fff3cd;color:#856404;padding:8px 12px;border-radius:8px;font-weight:700;height:fit-content}
    .banner{padding:12px;border-radius:10px;margin-bottom:12px}
    .banner.warn{background:#fff7e8;color:#8a5a12}
    .toolbar{margin-bottom:12px}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64}
    select{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .links{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:14px}
    .links a{color:#1f6f8b;font-weight:700;text-decoration:none}
    .card{border:1px solid #e4ebf0;border-radius:12px;padding:14px;background:#fff}
    ul{margin:0;padding-right:18px;line-height:1.9;color:#4d5b64}
  `]
})
export class ClimateReportsComponent implements OnInit {
  private readonly stationsApi = inject(ObservationApiService);
  private readonly stationContext = inject(StationContextService);
  private readonly route = inject(ActivatedRoute);

  stations: StationDirectoryItem[] = [];
  stationId = '';

  get qp(): Record<string, string> {
    return this.stationId ? { stationId: this.stationId } : {};
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
