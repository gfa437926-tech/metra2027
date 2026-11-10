import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';

type LayerKey = 'none' | 'elevation' | 'coordinates';

/** Read-only Weather Forecasting Centre: catalogue + geographic compare (UTC). */
@Component({
  standalone: true,
  selector: 'metra-forecasting-center',
  imports: [CommonModule, FormsModule],
  template: `
    <section class="page" dir="rtl">
      <header class="head">
        <div>
          <h1>مركز التنبؤ الجوي</h1>
          <p>متابعة محطات الكتالوج المعتمد، المقارنة الجغرافية، والتفاصيل — دون تعديل السجلات. الأوقات UTC.</p>
        </div>
        <span class="badge">اطلاع فقط</span>
      </header>

      <div class="banner info">
        مصدر المحطات: دليل METRA المعتمد. قيم الرصد اللحظية (حرارة، رياح، …) تُعرض فقط عند توفر عقد لقطة معتمد؛ حالياً تُعلَّم كـ «غير متاح» ولا تُختلق أرقام.
      </div>

      <div class="toolbar">
        <label>تصفية النوع
          <select [(ngModel)]="typeFilter" (ngModelChange)="applyFilters()">
            <option value="">الكل</option>
            <option value="classic">classic</option>
            <option value="automatic">automatic</option>
            <option value="synoptic">synoptic</option>
          </select>
        </label>
        <label>الحد الأدنى للارتفاع (م)
          <input type="number" [(ngModel)]="minElevation" (ngModelChange)="applyFilters()" />
        </label>
        <label>الحد الأقصى للارتفاع (م)
          <input type="number" [(ngModel)]="maxElevation" (ngModelChange)="applyFilters()" />
        </label>
        <label>طبقة العرض
          <select [(ngModel)]="layer">
            <option value="none">قائمة</option>
            <option value="coordinates">خريطة إحداثيات</option>
            <option value="elevation">تلوين بالارتفاع</option>
          </select>
        </label>
        <button type="button" (click)="reload()" [disabled]="loading">تحديث</button>
      </div>

      <div class="stats">
        <article><strong>{{ filtered.length }}</strong><span>محطات معروضة</span></article>
        <article><strong>{{ withCoords }}</strong><span>بإحداثيات</span></article>
        <article><strong>{{ withoutCoords }}</strong><span>بدون إحداثيات</span></article>
        <article><strong>{{ selectedIds.size }}</strong><span>مختارة للمقارنة</span></article>
      </div>

      <p class="error" *ngIf="error">{{ error }}</p>
      <p *ngIf="loading">جارٍ التحميل…</p>

      <div class="map" *ngIf="layer !== 'none' && filtered.length">
        <svg viewBox="0 0 400 240" role="img" aria-label="إسقاط نسبي للمحطات ذات الإحداثيات">
          <rect width="400" height="240" fill="#eef5f9"/>
          <ng-container *ngFor="let s of mappable">
            <circle
              [attr.cx]="project(s).x"
              [attr.cy]="project(s).y"
              r="5"
              [attr.fill]="layer === 'elevation' ? elevColor(s) : '#1f6f8b'"
              (click)="openDetail(s)"
              style="cursor:pointer" />
            <title>{{ s.name_ar }} · {{ code(s) }}</title>
          </ng-container>
        </svg>
        <small>إسقاط نسبي داخل الصندوق المحيط بالإحداثيات المتاحة فقط — ليس خريطة أساس خارجية.</small>
      </div>

      <div class="compare-bar" *ngIf="selectedIds.size >= 2">
        <button type="button" (click)="runCompare()" [disabled]="comparing">مقارنة المحطات المختارة</button>
        <button type="button" class="ghost" (click)="clearSelection()">مسح الاختيار</button>
      </div>

      <div class="compare-result" *ngIf="compareResult">
        <h2>نتيجة المقارنة (UTC {{ compareResult.comparedAtUtc }})</h2>
        <table>
          <thead>
            <tr>
              <th>من</th><th>إلى</th><th>المسافة (كم)</th><th>فرق الارتفاع (م)</th>
            </tr>
          </thead>
          <tbody>
            <tr *ngFor="let p of compareResult.pairs">
              <td>{{ shortId(p.fromStationId) }}</td>
              <td>{{ shortId(p.toStationId) }}</td>
              <td>{{ p.distanceKm != null ? (p.distanceKm | number:'1.1-1') : 'غير متاح' }}</td>
              <td>{{ p.elevationDifferenceM != null ? (p.elevationDifferenceM | number:'1.0-0') : 'غير متاح' }}</td>
            </tr>
          </tbody>
        </table>
        <p class="note">{{ compareResult.noteAr }}</p>
      </div>

      <table class="stations" *ngIf="filtered.length">
        <thead>
          <tr>
            <th></th>
            <th>المحطة</th>
            <th>الرمز</th>
            <th>النوع</th>
            <th>الارتفاع</th>
            <th>الإحداثيات</th>
            <th>الرصد</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let s of filtered" [class.active]="detail?.id === s.id">
            <td>
              <input type="checkbox" [checked]="selectedIds.has(s.id)" (change)="toggleSelect(s.id, $any($event))" />
            </td>
            <td>{{ s.name_ar }}</td>
            <td>{{ code(s) }}</td>
            <td>{{ s.station_type }}</td>
            <td>{{ s.elevation_m != null ? s.elevation_m : 'غير متاح' }}</td>
            <td>{{ coordLabel(s) }}</td>
            <td><span class="pill">غير متاح</span></td>
            <td><button type="button" (click)="openDetail(s)">تفاصيل</button></td>
          </tr>
        </tbody>
      </table>

      <aside class="detail" *ngIf="detail">
        <h2>{{ detail.name_ar }}</h2>
        <p>المعرّف: {{ detail.id }}</p>
        <p>الرمز المحلي: {{ detail.local_station_code || 'غير متاح' }}</p>
        <p>WMO: {{ detail.wmo_station_id || 'غير متاح' }}</p>
        <p>النوع: {{ detail.station_type }} · الحالة: {{ detail.operational_status }}</p>
        <p>الارتفاع: {{ detail.elevation_m != null ? detail.elevation_m + ' م' : 'غير متاح' }}</p>
        <p>الإحداثيات: {{ coordLabel(detail) }}</p>
        <p>مصدر الإحداثيات: {{ coordSource(detail) }}</p>
        <h3>عناصر الرصد</h3>
        <ul>
          <li>الحرارة / الرطوبة / الضغط / الرياح / الهطول / الرؤية / الغيوم: <strong>غير متاح</strong> (بانتظار عقد لقطة التنبؤ)</li>
        </ul>
        <p class="note">واجهة اطلاع فقط — لا تعديل أو اعتماد من هنا.</p>
        <button type="button" class="ghost" (click)="detail = null">إغلاق</button>
      </aside>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1200px;margin:0 auto}
    .head{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:12px}
    h1{margin:0 0 6px;font-size:1.35rem} p{margin:0;color:#5c6b75;line-height:1.65}
    .badge{background:#e8f5ee;color:#1f6b3c;padding:8px 12px;border-radius:8px;font-weight:700;height:fit-content}
    .banner{padding:12px;border-radius:10px;margin-bottom:12px}.banner.info{background:#eef6fa;color:#1f4d63}
    .toolbar{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;align-items:end}
    label{display:flex;flex-direction:column;gap:4px;font-size:12px;color:#4d5b64}
    select,input{border:1px solid #d5dee4;border-radius:8px;padding:8px 10px;font:inherit;min-width:120px}
    button{border:0;background:#1f6f8b;color:#fff;border-radius:8px;padding:9px 14px;font:inherit;cursor:pointer}
    button.ghost{background:#eef2f5;color:#334}
    .stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:14px}
    .stats article{background:#fff;border:1px solid #e4ebef;border-radius:10px;padding:12px;text-align:center}
    .stats strong{display:block;font-size:1.4rem;color:#1f6f8b}
    .map{background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:10px;margin-bottom:12px}
    .map svg{width:100%;height:auto;display:block}
    table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #e4ebef;border-radius:12px;overflow:hidden}
    th,td{padding:10px;border-bottom:1px solid #eef2f5;text-align:right;font-size:13px}
    tr.active{background:#f3fafc}
    .pill{background:#fff3cd;color:#856404;padding:2px 8px;border-radius:999px;font-size:12px}
    .detail{margin-top:16px;background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:16px}
    .error{color:#8a1f2d}.note{color:#687780;font-size:13px}
    .compare-bar{display:flex;gap:8px;margin:12px 0}
    @media(max-width:800px){.stats{grid-template-columns:repeat(2,minmax(0,1fr))}}
  `]
})
export class ForecastingCenterComponent implements OnInit {
  private readonly stationsApi = inject(ObservationApiService);

  stations: StationDirectoryItem[] = [];
  filtered: StationDirectoryItem[] = [];
  loading = false;
  error: string | null = null;
  typeFilter = '';
  minElevation: number | null = null;
  maxElevation: number | null = null;
  layer: LayerKey = 'none';
  selectedIds = new Set<string>();
  detail: StationDirectoryItem | null = null;
  comparing = false;
  compareResult: {
    comparedAtUtc: string;
    pairs: Array<{
      fromStationId: string;
      toStationId: string;
      distanceKm: number | null;
      elevationDifferenceM: number | null;
    }>;
    noteAr: string;
  } | null = null;

  get withCoords(): number {
    return this.filtered.filter((s) => this.coords(s)).length;
  }
  get withoutCoords(): number {
    return this.filtered.length - this.withCoords;
  }
  get mappable(): StationDirectoryItem[] {
    return this.filtered.filter((s) => this.coords(s));
  }

  ngOnInit(): void {
    void this.reload();
  }

  async reload(): Promise<void> {
    this.loading = true;
    this.error = null;
    try {
      if (!this.stationsApi.isConfigured) {
        this.error = 'API أو المصادقة غير مضبوطين.';
        this.stations = [];
      } else {
        this.stations = await this.stationsApi.getAllStations();
      }
      this.applyFilters();
    } catch {
      this.error = 'تعذر تحميل دليل المحطات.';
      this.stations = [];
      this.filtered = [];
    } finally {
      this.loading = false;
    }
  }

  applyFilters(): void {
    this.filtered = this.stations.filter((s) => {
      if (this.typeFilter && s.station_type !== this.typeFilter) return false;
      if (this.minElevation != null && (s.elevation_m == null || s.elevation_m < this.minElevation)) return false;
      if (this.maxElevation != null && (s.elevation_m == null || s.elevation_m > this.maxElevation)) return false;
      return true;
    });
  }

  code(s: StationDirectoryItem): string {
    return s.local_station_code || s.wmo_station_id || '—';
  }

  coords(s: StationDirectoryItem): { latitude: number; longitude: number } | null {
    const c = s.station_coordinates?.[0];
    if (!c || typeof c.latitude !== 'number' || typeof c.longitude !== 'number') return null;
    if (c.latitude < -90 || c.latitude > 90 || c.longitude < -180 || c.longitude > 180) return null;
    return c;
  }

  coordLabel(s: StationDirectoryItem): string {
    const c = this.coords(s);
    return c ? `${c.latitude.toFixed(4)}, ${c.longitude.toFixed(4)}` : 'غير متاح';
  }

  coordSource(s: StationDirectoryItem): string {
    return s.station_coordinates?.[0]?.coordinate_source || 'غير متاح';
  }

  elevColor(s: StationDirectoryItem): string {
    const e = s.elevation_m;
    if (e == null) return '#94a3b8';
    if (e < 100) return '#38bdf8';
    if (e < 500) return '#0ea5e9';
    if (e < 1000) return '#0369a1';
    return '#0c4a6e';
  }

  project(s: StationDirectoryItem): { x: number; y: number } {
    const pts = this.mappable.map((x) => this.coords(x)!);
    if (!pts.length) return { x: 200, y: 120 };
    const lats = pts.map((p) => p.latitude);
    const lons = pts.map((p) => p.longitude);
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLon = Math.min(...lons);
    const maxLon = Math.max(...lons);
    const c = this.coords(s)!;
    const x = maxLon === minLon ? 200 : 20 + ((c.longitude - minLon) / (maxLon - minLon)) * 360;
    const y = maxLat === minLat ? 120 : 20 + ((maxLat - c.latitude) / (maxLat - minLat)) * 200;
    return { x, y };
  }

  toggleSelect(id: string, event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    if (checked) this.selectedIds.add(id);
    else this.selectedIds.delete(id);
    this.selectedIds = new Set(this.selectedIds);
  }

  clearSelection(): void {
    this.selectedIds = new Set();
    this.compareResult = null;
  }

  openDetail(s: StationDirectoryItem): void {
    this.detail = s;
  }

  shortId(id: string): string {
    return id.slice(0, 8);
  }

  runCompare(): void {
    if (this.selectedIds.size < 2) return;
    this.comparing = true;
    this.error = null;
    try {
      // Geographic compare from catalogue coordinates only (same rules as API Haversine).
      this.compareResult = this.localCompare([...this.selectedIds]);
    } finally {
      this.comparing = false;
    }
  }

  private localCompare(ids: string[]): {
    comparedAtUtc: string;
    pairs: Array<{
      fromStationId: string;
      toStationId: string;
      distanceKm: number | null;
      elevationDifferenceM: number | null;
    }>;
    noteAr: string;
  } {
    const selected = ids
      .map((id) => this.stations.find((s) => s.id === id))
      .filter((s): s is StationDirectoryItem => !!s);
    const pairs: Array<{
      fromStationId: string;
      toStationId: string;
      distanceKm: number | null;
      elevationDifferenceM: number | null;
    }> = [];
    for (let i = 0; i < selected.length; i++) {
      for (let j = i + 1; j < selected.length; j++) {
        const a = selected[i];
        const b = selected[j];
        const ca = this.coords(a);
        const cb = this.coords(b);
        pairs.push({
          fromStationId: a.id,
          toStationId: b.id,
          distanceKm: ca && cb ? this.haversine(ca.latitude, ca.longitude, cb.latitude, cb.longitude) : null,
          elevationDifferenceM:
            a.elevation_m != null && b.elevation_m != null ? b.elevation_m - a.elevation_m : null
        });
      }
    }
    return {
      comparedAtUtc: new Date().toISOString(),
      pairs,
      noteAr: 'مقارنة جغرافية/ارتفاعية محلية من الكتالوج. لا قيم رصد مخترعة.'
    };
  }

  private haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const toRad = (d: number) => (d * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
