import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import { StationContextService } from '../../core/station/station-context.service';

/** Agricultural monthly bulletin remains unbound until contract + formulas are approved. */
@Component({
  standalone: true,
  selector: 'metra-agriculture',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header>
        <div>
          <h1>النشرات الزراعية</h1>
          <p>لا يوجد مسار حفظ خادمي معتمد للنشرة الزراعية الشهرية في هذه النسخة.</p>
        </div>
        <span class="badge">غير مربوط</span>
      </header>
      <div class="banner warn">
        الشاشة لا تقبل إرسالاً إلى الخادم ولا تعرض إحصاءات وهمية.
      </div>
      <label>
        المحطة (للتنقل)
        <select [(ngModel)]="stationId" (ngModelChange)="remember($event)">
          <option value="">— اختر محطة —</option>
          <option *ngFor="let s of stations" [value]="s.id">{{ s.name_ar }}</option>
        </select>
      </label>
      <section class="form-card">
        <h2>مسودة النشرة الزراعية الشهرية</h2>
        <p>المدخلات أدناه للمعاينة فقط؛ لم يعتمد بعد عقد الحقول أو قواعد التصنيف الزراعي.</p>
        <div class="fields">
          <label>الفترة المرجعية<input type="month" [(ngModel)]="referenceMonth" name="referenceMonth"></label>
          <label>حالة المحصول<select [(ngModel)]="cropCondition" name="cropCondition"><option value="">اختر الحالة</option><option value="normal">طبيعي</option><option value="stressed">إجهاد ظاهر</option><option value="damaged">أضرار ملاحظة</option><option value="unknown">غير محدد</option></select></label>
          <label>حالة التربة<input [(ngModel)]="soilCondition" name="soilCondition"></label>
          <label>ملاحظات الري<input [(ngModel)]="irrigationNote" name="irrigationNote"></label>
        </div>
        <label>الآفات أو الملاحظات الحقلية<textarea [(ngModel)]="fieldNotes" name="fieldNotes" rows="3"></textarea></label>
        <button type="button" (click)="preview()">معاينة محلية دون حفظ</button>
        <p class="preview" *ngIf="previewMessage" role="status">{{ previewMessage }}</p>
      </section>
      <div class="links">
        <a routerLink="/reports/daily" [queryParams]="qp">النشرات اليومية</a>
        <a routerLink="/reports/monthly" [queryParams]="qp">التقرير الشهري الإداري</a>
        <a routerLink="/admin/manual-archive" [queryParams]="qp">تأكيد أرشفة Excel</a>
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
    .links{display:flex;flex-wrap:wrap;gap:12px}.links a{color:#1f6f8b;font-weight:700;text-decoration:none}\n    .form-card{margin:16px 0;padding:16px;border:1px solid #e4ebef;border-radius:12px;background:#fff;display:grid;gap:12px}.form-card h2{margin:0;font-size:17px}.form-card p{font-size:12px}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}textarea,input,select{border:1px solid #d5dee4;border-radius:8px;padding:9px;font:inherit}button{border:0;border-radius:8px;background:#287caf;color:#fff;padding:10px;font:inherit}.preview{background:#edf7ef;padding:10px;border-radius:8px}\n    @media(max-width:650px){.fields{grid-template-columns:1fr}}
  `]
})
export class AgricultureComponent implements OnInit {
  private readonly stationsApi = inject(ObservationApiService);
  private readonly stationContext = inject(StationContextService);
  private readonly route = inject(ActivatedRoute);
  stations: StationDirectoryItem[] = [];
  stationId = '';
  referenceMonth = '';
  cropCondition = '';
  soilCondition = '';
  irrigationNote = '';
  fieldNotes = '';
  previewMessage = '';
  preview(): void {
    if (!this.stationId || !this.referenceMonth) {
      this.previewMessage = 'اختر محطة وفترة مرجعية لمعاينة المسودة.';
      return;
    }
    this.previewMessage = 'مسودة محلية فقط. لم يتم اعتماد بيانات زراعية أو إرسالها إلى الخادم.';
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
