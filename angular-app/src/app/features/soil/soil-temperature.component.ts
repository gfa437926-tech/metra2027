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
      <section class="form-card">
        <h2>مسودة قياس حرارة التربة</h2>
        <p>يجب اعتماد أعماق القياس والوحدات والحساسات وقواعد التحقق قبل الحفظ التشغيلي.</p>
        <div class="fields">
          <label>عمق القياس (سم)<input type="number" min="0" step="any" [(ngModel)]="depthCm" name="depthCm"></label>
          <label>درجة الحرارة (°C)<input type="number" step="any" [(ngModel)]="temperatureC" name="temperatureC"></label>
          <label>معرّف الحساس<input [(ngModel)]="sensorId" name="sensorId"></label>
          <label>وقت القياس UTC<input [(ngModel)]="observedAtUtc" name="observedAtUtc" placeholder="YYYY-MM-DDTHH:mm:ssZ" dir="ltr"></label>
        </div>
        <button type="button" (click)="preview()">معاينة محلية دون حفظ</button>
        <p class="preview" *ngIf="previewMessage" role="status">{{ previewMessage }}</p>
      </section>
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
    .links{display:flex;flex-wrap:wrap;gap:12px}.links a{color:#1f6f8b;font-weight:700;text-decoration:none}\n    .form-card{margin:16px 0;padding:16px;border:1px solid #e4ebef;border-radius:12px;background:#fff;display:grid;gap:12px}.form-card h2{margin:0;font-size:17px}.form-card p{font-size:12px}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}input{border:1px solid #d5dee4;border-radius:8px;padding:9px;font:inherit}button{border:0;border-radius:8px;background:#287caf;color:#fff;padding:10px;font:inherit}.preview{background:#edf7ef;padding:10px;border-radius:8px}\n    @media(max-width:650px){.fields{grid-template-columns:1fr}}
  `]
})
export class SoilTemperatureComponent implements OnInit {
  private readonly stationsApi = inject(ObservationApiService);
  private readonly stationContext = inject(StationContextService);
  private readonly route = inject(ActivatedRoute);
  stations: StationDirectoryItem[] = [];
  stationId = '';
  depthCm = '';
  temperatureC = '';
  sensorId = '';
  observedAtUtc = '';
  previewMessage = '';
  preview(): void {
    if (!this.stationId || !this.depthCm || !this.temperatureC || !this.observedAtUtc) {
      this.previewMessage = 'أكمل المحطة والعمق والحرارة ووقت القياس UTC.';
      return;
    }
    if (!this.observedAtUtc.endsWith('Z') || Number.isNaN(Date.parse(this.observedAtUtc))) {
      this.previewMessage = 'يجب إدخال وقت UTC بصيغة ISO 8601 منتهية بالحرف Z.';
      return;
    }
    this.previewMessage = 'معاينة محلية فقط. لم يتم اعتماد أو حفظ قياس حرارة التربة.';
  }
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
