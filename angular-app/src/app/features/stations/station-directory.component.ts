import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';

@Component({
  standalone: true,
  selector: 'metra-station-directory',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <h1>دليل المحطات</h1>
          <p>عرض المحطات من الكتالوج الجديد عبر واجهة API الخادم فقط (UTC للعمليات، بدون بيانات تجريبية مموّهة).</p>
        </div>
        <button type="button" class="primary" [disabled]="loading" (click)="reload()">تحديث</button>
      </header>

      <div class="toolbar">
        <label>
          بحث بالاسم أو الرمز
          <input type="search" [(ngModel)]="query" placeholder="مثال: طرابلس أو الرمز المحلي" />
        </label>
        <label>
          النوع
          <select [(ngModel)]="typeFilter">
            <option value="">الكل</option>
            <option value="classic">تقليدية</option>
            <option value="automatic">تلقائية</option>
            <option value="synoptic">سينوبتيك</option>
          </select>
        </label>
      </div>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner info" *ngIf="loading">جاري تحميل دليل المحطات...</div>
      <div class="banner info" *ngIf="!loading && !error && filtered.length === 0">لا توجد محطات مطابقة ضمن نطاق العرض.</div>

      <div class="table-wrap" *ngIf="filtered.length > 0">
        <table>
          <thead>
            <tr>
              <th>الاسم العربي</th>
              <th>الرمز المحلي</th>
              <th>WMO</th>
              <th>النوع</th>
              <th>الحالة التشغيلية</th>
              <th>الاعتماد</th>
              <th>الإحداثيات</th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let s of filtered">
              <td>
                <a class="name-link" [routerLink]="['/stations', s.id]"><strong>{{ s.name_ar }}</strong></a>
                <small *ngIf="s.name_en">{{ s.name_en }}</small>
              </td>
              <td><code>{{ s.local_station_code || '—' }}</code></td>
              <td><code>{{ s.wmo_station_id || '—' }}</code></td>
              <td>{{ s.station_type }}</td>
              <td>{{ s.operational_status }}</td>
              <td>{{ s.approval_status }}</td>
              <td class="coords">
                <ng-container *ngIf="s.station_coordinates?.length; else noCoords">
                  {{ s.station_coordinates[0].latitude }}, {{ s.station_coordinates[0].longitude }}
                </ng-container>
                <ng-template #noCoords>—</ng-template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="footnote">المصدر: <code>GET /api/v1/stations</code> بعد مصادقة JWT. لا تُعرض مفاتيح الخدمة في العميل.</p>
    </section>
  `,
  styles: [`
    .page{padding:18px 18px 28px;max-width:1200px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:14px}
    h1{margin:0 0 6px;font-size:1.45rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .primary{background:#1f6f8b;color:#fff;border:0;border-radius:10px;padding:10px 14px;font-weight:700;cursor:pointer}
    .primary:disabled{opacity:.6;cursor:default}
    .toolbar{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin:12px 0 16px}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64}
    input,select{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .banner{padding:12px 14px;border-radius:10px;margin-bottom:12px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .table-wrap{overflow:auto;border:1px solid #e4ebf0;border-radius:12px}
    table{width:100%;border-collapse:collapse;min-width:900px}
    th,td{padding:12px;border-bottom:1px solid #edf1f4;text-align:right;vertical-align:top;font-size:13px}
    th{background:#f5f8fa;color:#5b6a74}
    td small{display:block;color:#7a8791}
    code{direction:ltr;unicode-bidi:plaintext}
    .coords{direction:ltr;text-align:right}
    .name-link{color:#1f6f8b;text-decoration:none}.name-link:hover{text-decoration:underline}.footnote{margin-top:12px;font-size:11px;color:#7a8791}
    @media(max-width:800px){.toolbar{grid-template-columns:1fr}.page-header{flex-direction:column}}
  `]
})
export class StationDirectoryComponent implements OnInit {
  private readonly api = inject(ObservationApiService);

  stations: StationDirectoryItem[] = [];
  query = '';
  typeFilter = '';
  loading = false;
  error = '';

  get filtered(): StationDirectoryItem[] {
    const q = this.query.trim().toLowerCase();
    return this.stations.filter(s => {
      if (this.typeFilter && s.station_type !== this.typeFilter) return false;
      if (!q) return true;
      const hay = [
        s.name_ar,
        s.name_en ?? '',
        s.local_station_code ?? '',
        s.wmo_station_id ?? ''
      ].join(' ').toLowerCase();
      return hay.includes(q);
    });
  }

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (!this.api.isConfigured) {
        throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة قبل تحميل دليل المحطات.');
      }
      this.stations = await this.api.getAllStations();
    } catch (e) {
      this.stations = [];
      this.error = e instanceof Error ? e.message : 'تعذر تحميل دليل المحطات.';
    } finally {
      this.loading = false;
    }
  }
}
