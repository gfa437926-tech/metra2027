import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import { StationContextService } from '../../core/station/station-context.service';

/** Soil temperature entry is blocked until an approved observation contract exists. */
@Component({
  standalone: true,
  selector: 'metra-soil-temperature',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header>
        <div>
          <h1>درجات حرارة التربة</h1>
          <p>لا يوجد عقد API معتمد لحفظ درجات تربة كرصد تشغيلي في هذه النسخة.</p>
        </div>
        <span class="badge">غير مربوط</span>
      </header>
      <div class="banner warn">
        لن تُحفظ قيم تربة من هذه الشاشة. استخدم مسارات الرصد الساعي/اليومي المعتمدة عند توفر الحقول في العقد.
      </div>
      <label>
        المحطة (للتنقل)
        <select [(ngModel)]="stationId" (ngModelChange)="remember($event)">
          <option value="">— اختر محطة —</option>
          <option *ngFor="let s of stations" [value]="s.id">{{ s.name_ar }}</option>
        </select>
      </label>
      <div class="links">
        <a routerLink="/reports/hourly" [queryParams]="qp">النشرات الساعية</a>
        <a routerLink="/reports/daily" [queryParams]="qp">النشرات اليومية</a>
        <a routerLink="/observations/workflow" [queryParams]="qp">مراجعة النشرات</a>
      </div>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:900px;margin:0 auto}
    header{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:12px}
    h1{margin:0 0 6px;font-size:1.35rem} p{margin:0;color:#5c6b75;line-height:1.7}
    .badge{background:#fff3cd;color:#856404;padding:8px 12px;border-radius:8px;font-weight:700;height:fit-content}
    .banner{padding:12px;border-radius:10px;margin-bottom:12px}.banner.warn{background:#fff7e8;color:#8a5a12}
    label{display:flex;flex-direction:column;gap:6px;margin-bottom:12px;font-size:12px;color:#4d5b64}
    select{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .links{display:flex;flex-wrap:wrap;gap:12px}.links a{color:#1f6f8b;font-weight:700;text-decoration:none}
  `]
})
export class SoilTemperatureComponent implements OnInit {
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
