import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Component } from '@angular/core';

interface WeatherPhenomenon {
  report_id: string;
  phenomenon_type: string;
  phenomenon_date: string;
  start_time: string;
  end_time: string;
  phenomenon_duration?: string;
  intensity: string;
  station_name?: string;
  user_name?: string;
  user_email?: string;
  user_role?: string;
  submission_date?: string;
  submission_time?: string;
  general_notes?: string;
  hour_00_rain?: string | number;
  hour_00_snow?: string | number;
  hour_00_notes?: string;
  hour_06_rain?: string | number;
  hour_06_snow?: string | number;
  hour_06_notes?: string;
  hour_12_rain?: string | number;
  hour_12_snow?: string | number;
  hour_12_notes?: string;
  hour_18_rain?: string | number;
  hour_18_snow?: string | number;
  hour_18_notes?: string;
}

@Component({
  standalone: true,
  selector: 'metra-phenomena',
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page" dir="rtl">
      <header class="topbar">
        <div class="brand">
          <span class="brand-icon"><i class="fa-solid fa-cloud-sun-rain"></i></span>
          <div><h1>نظام إدارة البيانات الجوية</h1><p>عرض ظواهر المطر والثلج - البيانات التاريخية</p></div>
        </div>
        <div class="clock">
          <label>التاريخ الحالي</label><strong>{{ currentDate }}</strong>
          <label>الوقت الحالي</label><strong>{{ currentTime }}</strong>
          <label>التوقيت العالمي (UTC)</label><strong>{{ utcTime }}</strong>
        </div>
      </header>

      <section class="main-card">
        <div class="main-header">
          <h2><i class="fa-solid fa-cloud-rain"></i> عرض ظواهر المطر والثلج</h2>
          <p>عرض البيانات التاريخية للظواهر الجوية وكميات المطر والثلج حسب التوقيت العالمي (UTC)</p>
        </div>

        <section class="user-section">
          <h3 class="section-title"><i class="fa-solid fa-user-tie"></i> التعريف بالمحطة والراصد</h3>
          <div class="user-welcome">
            <strong>مرحباً، بيانات المستخدم غير متاحة</strong>
            <p>المحطة: غير متاحة | صفة العمل: غير متاحة</p>
          </div>
          <p class="source-warning">لم يتم ربط مصدر هوية المستخدم والمحطة أو مصدر بيانات الظواهر. لا تُعرض بيانات افتراضية على أنها بيانات فعلية.</p>
        </section>

        <section class="stats-cards" *ngIf="filteredPhenomena.length">
          <article class="stat-card"><i class="fa-solid fa-cloud-rain"></i><strong>{{ filteredPhenomena.length }}</strong><span>إجمالي الظواهر</span></article>
          <article class="stat-card"><i class="fa-solid fa-tint"></i><strong>{{ totalRain | number:'1.1-1' }}</strong><span>إجمالي كمية المطر (مم)</span></article>
          <article class="stat-card"><i class="fa-solid fa-snowflake"></i><strong>{{ totalSnow }}</strong><span>إجمالي كمية الثلج (سم)</span></article>
          <article class="stat-card"><i class="fa-solid fa-chart-line"></i><strong>{{ averageDuration | number:'1.1-1' }}</strong><span>متوسط المدة (ساعة)</span></article>
        </section>

        <section class="filter-section">
          <h3 class="section-title"><i class="fa-solid fa-filter"></i> فلاتر البحث والتصفية</h3>
          <div class="filters">
            <label>التاريخ<input type="date" [(ngModel)]="filterDate" (change)="applyFilters()"></label>
            <label>نوع الظاهرة
              <select [(ngModel)]="filterType" (change)="applyFilters()">
                <option value="">جميع الأنواع</option><option value="rain">مطر</option><option value="snow">ثلج</option>
                <option value="rain_snow">مطر وثلج معاً</option><option value="hail">برد</option>
                <option value="drizzle">رذاذ</option><option value="storm">عاصفة رعدية</option>
              </select>
            </label>
            <label>المحطة
              <select [(ngModel)]="filterStation" (change)="applyFilters()">
                <option value="">جميع المحطات</option>
                <option *ngFor="let station of stations" [value]="station">{{ station }}</option>
              </select>
            </label>
            <label>الشدة
              <select [(ngModel)]="filterIntensity" (change)="applyFilters()">
                <option value="">جميع الشدة</option><option value="light">خفيفة</option>
                <option value="moderate">متوسطة</option><option value="heavy">شديدة</option>
                <option value="very_heavy">شديدة جداً</option>
              </select>
            </label>
            <label>من تاريخ<input type="date" [(ngModel)]="filterStartDate" (change)="applyFilters()"></label>
            <label>إلى تاريخ<input type="date" [(ngModel)]="filterEndDate" (change)="applyFilters()"></label>
          </div>
          <div class="actions">
            <button class="primary" type="button" (click)="applyFilters()"><i class="fa-solid fa-magnifying-glass"></i> بحث</button>
            <button class="secondary" type="button" (click)="resetFilters()"><i class="fa-solid fa-rotate-left"></i> إعادة تعيين</button>
            <button class="success" type="button" (click)="exportAllData()" [disabled]="!filteredPhenomena.length"><i class="fa-solid fa-download"></i> تصدير البيانات</button>
            <button class="info" type="button" (click)="refreshData()" disabled title="يتطلب ربط مصدر البيانات"><i class="fa-solid fa-arrows-rotate"></i> تحديث</button>
          </div>
        </section>

        <div class="connection-state" *ngIf="!allPhenomena.length">
          <i class="fa-solid fa-database"></i>
          <h3>مصدر بيانات الظواهر غير مرتبط</h3>
          <p>لم يتم تحميل سجلات من جدول <code>weather_phenomena</code>. ستظهر البطاقات والإحصائيات والجداول بعد ربط واجهة API المعتمدة وقاعدة البيانات.</p>
        </div>
        <section class="phenomena-cards" *ngIf="filteredPhenomena.length">
          <article class="phenomenon-card" *ngFor="let phenomenon of filteredPhenomena">
            <header [style.background]="typeColor(phenomenon.phenomenon_type)">
              <div><strong><i [class]="typeIcon(phenomenon.phenomenon_type)"></i> {{ typeName(phenomenon.phenomenon_type) }}</strong><span>{{ phenomenon.phenomenon_date }}</span></div>
              <b>{{ intensityName(phenomenon.intensity) }}</b>
            </header>
            <div class="card-body">
              <p><strong>وقت البداية (UTC):</strong><span>{{ phenomenon.start_time }}</span></p>
              <p><strong>وقت النهاية (UTC):</strong><span>{{ phenomenon.end_time }}</span></p>
              <p><strong>المدة:</strong><span>{{ phenomenon.phenomenon_duration || 'غير محددة' }}</span></p>
              <p><strong>المحطة:</strong><span>{{ phenomenon.station_name || 'غير محددة' }}</span></p>
              <p><strong>إجمالي المطر:</strong><span>{{ phenomenonRain(phenomenon) | number:'1.1-1' }} مم</span></p>
              <p><strong>إجمالي الثلج:</strong><span>{{ phenomenonSnow(phenomenon) }} سم</span></p>
              <div class="card-actions">
                <button type="button" (click)="showDetail(phenomenon)">عرض التفاصيل</button>
                <button type="button" class="outline" (click)="showRainfallTable(phenomenon)">عرض جدول المطر</button>
              </div>
            </div>
          </article>
        </section>
        <p class="no-data" *ngIf="allPhenomena.length && !filteredPhenomena.length">لا توجد بيانات</p>

        <section class="rainfall-table-section" *ngIf="selectedTable">
          <h3 class="section-title"><i class="fa-solid fa-table"></i> جدول تأشيرات المطر والثلج</h3>
          <div class="table-heading">جدول تأشيرات المطر والثلج (UTC) - {{ typeName(selectedTable.phenomenon_type) }} - تاريخ: {{ selectedTable.phenomenon_date }}</div>
          <div class="table-scroll"><table><thead><tr><th>الساعة (UTC)</th><th>كمية المطر (مم)<br>ddd.d</th><th>كمية الثلج (سم)<br>ddd</th><th>ملاحظات</th></tr></thead>
            <tbody><tr *ngFor="let hour of hours"><td>{{ hour }}:00</td><td>{{ rainAt(selectedTable, hour) }}</td><td>{{ snowAt(selectedTable, hour) }}</td><td>{{ notesAt(selectedTable, hour) || '---' }}</td></tr></tbody>
          </table></div>
          <div class="actions"><button class="primary" type="button" (click)="printRainfallTable()"><i class="fa-solid fa-print"></i> طباعة الجدول</button><button class="success" type="button" (click)="exportRainfallData()"><i class="fa-solid fa-download"></i> تصدير كملف CSV</button></div>
        </section>

        <section class="detail-panel" *ngIf="selectedDetail">
          <div class="detail-head"><h3>تفاصيل الظاهرة الجوية</h3><button type="button" (click)="selectedDetail=null">إغلاق</button></div>
          <h4>معلومات الظاهرة</h4>
          <div class="detail-grid">
            <p><strong>نوع الظاهرة:</strong> {{ typeName(selectedDetail.phenomenon_type) }}</p>
            <p><strong>التاريخ:</strong> {{ selectedDetail.phenomenon_date }}</p>
            <p><strong>وقت البداية (UTC):</strong> {{ selectedDetail.start_time }}</p>
            <p><strong>وقت النهاية (UTC):</strong> {{ selectedDetail.end_time }}</p>
            <p><strong>المدة:</strong> {{ selectedDetail.phenomenon_duration || 'غير محددة' }}</p>
            <p><strong>الشدة:</strong> {{ intensityName(selectedDetail.intensity) }}</p>
          </div>
          <h4>معلومات التسجيل</h4>
          <div class="detail-grid">
            <p><strong>معرف التقرير:</strong> {{ selectedDetail.report_id }}</p>
            <p><strong>المحطة:</strong> {{ selectedDetail.station_name || 'غير محددة' }}</p>
            <p><strong>الراصد:</strong> {{ selectedDetail.user_name || 'غير محدد' }}</p>
            <p><strong>البريد الإلكتروني:</strong> {{ selectedDetail.user_email || 'غير محدد' }}</p>
            <p><strong>الصفة:</strong> {{ selectedDetail.user_role || 'غير محدد' }}</p>
            <p><strong>تاريخ الإرسال:</strong> {{ selectedDetail.submission_date || 'غير محدد' }} {{ selectedDetail.submission_time || '' }}</p>
          </div>
          <h4>الملاحظات العامة</h4><p>{{ selectedDetail.general_notes || 'لا توجد ملاحظات عامة' }}</p>
          <h4>بيانات الفترات الساعية (UTC)</h4>
          <div class="table-scroll"><table><thead><tr><th>الساعة (UTC)</th><th>كمية المطر (مم) ddd.d</th><th>كمية الثلج (سم) ddd</th><th>ملاحظات</th></tr></thead>
            <tbody><tr *ngFor="let hour of hours"><td>{{ hour }}:00</td><td>{{ rainAt(selectedDetail, hour) || '000.0' }}</td><td>{{ snowAt(selectedDetail, hour) || '000' }}</td><td>{{ notesAt(selectedDetail, hour) || 'لا توجد' }}</td></tr></tbody>
          </table></div>
          <div class="actions"><button class="primary" type="button" (click)="printDetail()"><i class="fa-solid fa-print"></i> طباعة التقرير</button></div>
        </section>

        <details class="help">
          <summary>مساعدة - عرض ظواهر المطر والثلج</summary>
          <h4>كيفية استخدام النظام:</h4>
          <ol>
            <li><strong>تصفية البيانات:</strong> يمكنك استخدام الفلاتر المتاحة للبحث عن بيانات محددة حسب التاريخ، نوع الظاهرة، المحطة، أو الشدة.</li>
            <li><strong>عرض التفاصيل:</strong> انقر على زر "عرض التفاصيل" في أي بطاقة ظاهرة لعرض معلومات كاملة عنها.</li>
            <li><strong>جدول المطر والثلج:</strong> انقر على زر "عرض جدول المطر" لعرض جدول تفصيلي لكميات المطر والثلج لكل ساعة.</li>
            <li><strong>تصدير البيانات:</strong> استخدم زر "تصدير البيانات" لحفظ البيانات بصيغ مختلفة (JSON، CSV).</li>
            <li><strong>تحديث البيانات:</strong> استخدم زر "تحديث" لتحميل أحدث البيانات من قاعدة البيانات بعد ربط المصدر.</li>
          </ol>
          <h4>معلومات تقنية:</h4>
          <ul><li>جميع الأوقات معروضة بالتوقيت العالمي (UTC).</li><li>كمية المطر: تعرض بصيغة ddd.d (ثلاثة أرقام قبل الفاصلة، رقم واحد بعدها).</li><li>كمية الثلج: تعرض بصيغة ddd (ثلاثة أرقام صحيحة).</li><li>يتم تحديث البيانات تلقائياً كل 5 دقائق بعد ربط المصدر.</li></ul>
        </details>
      </section>
    </div>
  `,
  styles: [`
    .page{max-width:1400px;margin:0 auto;color:#333;font-family:'Segoe UI',Tahoma,Arial,sans-serif}
    .topbar{background:linear-gradient(135deg,#3498db 0%,#2c3e50 100%);color:#fff;padding:18px 22px;border-radius:10px;margin-bottom:20px;display:flex;justify-content:space-between;align-items:center;gap:18px;flex-wrap:wrap}
    .brand{display:flex;align-items:center;gap:14px}.brand-icon{width:52px;height:52px;background:#fff;color:#3498db;border-radius:50%;display:grid;place-items:center;font-size:25px}.brand h1{font-size:1.25rem;margin:0;font-weight:700}.brand p{font-size:.86rem;margin:5px 0 0;opacity:.9}
    .clock{display:flex;gap:8px;align-items:center;flex-wrap:wrap;font-size:.8rem}.clock label{opacity:.8}.clock strong{margin-left:7px;font-family:monospace}
    .main-card{background:#fff;border-radius:10px;box-shadow:0 4px 12px rgba(0,0,0,.08);padding:25px}
    .main-header{margin-bottom:26px;padding-bottom:15px;border-bottom:2px solid #f0f0f0}.main-header h2{font-size:1.5rem;color:#2c3e50;font-weight:700;display:flex;gap:10px;align-items:center;margin:0}.main-header h2 i{color:#3498db}.main-header p{color:#7f8c8d;margin:7px 0 0}
    .section-title{font-size:1.08rem;color:#2c3e50;font-weight:600;margin:0 0 18px;display:flex;align-items:center;gap:10px;border-bottom:1px solid #dee2e6;padding-bottom:10px}.section-title i{color:#3498db}
    .user-section{margin-bottom:25px}.user-welcome{background:#f8f9fa;padding:14px 16px;border-radius:8px}.user-welcome p{margin:5px 0 0;color:#687780}.source-warning{color:#805b17;background:#fff8e9;border-right:4px solid #f39c12;padding:10px 13px;border-radius:6px;line-height:1.7}
    .stats-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:18px;margin-bottom:28px}.stat-card{background:#fff;border-radius:10px;padding:18px;text-align:center;box-shadow:0 4px 8px rgba(0,0,0,.1);display:grid;gap:7px}.stat-card i{font-size:1.7rem;color:#3498db}.stat-card strong{font-size:2rem;color:#2c3e50}.stat-card span{color:#7f8c8d;font-size:.9rem}
    .filter-section{background:#f8f9fa;border-radius:8px;padding:20px;margin-bottom:25px;border-right:5px solid #3498db}.filters{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px}.filters label{font-weight:600;color:#2c3e50;display:flex;flex-direction:column;gap:7px}.filters input,.filters select{width:100%;box-sizing:border-box;border-radius:6px;border:1px solid #ced4da;padding:10px 12px;background:#fff;color:#34495e;font:inherit}.filters input:focus,.filters select:focus{outline:2px solid #3498db40;border-color:#3498db}
    .actions{display:flex;justify-content:center;gap:9px;flex-wrap:wrap;margin-top:18px}.actions button,.card-actions button{border:0;border-radius:6px;padding:10px 17px;color:#fff;font:inherit;font-weight:600;cursor:pointer}.actions button:disabled{opacity:.48;cursor:not-allowed}.primary{background:#3498db}.secondary{background:#6c757d}.success{background:#27ae60}.info{background:#17a2b8}
    .connection-state,.no-data{padding:45px 20px;text-align:center;color:#7f8c8d;background:#fafbfc;border:1px dashed #cbd3d9;border-radius:9px;margin:22px 0}.connection-state>i{font-size:3rem;color:#bdc3c7}.connection-state h3{color:#2c3e50;font-size:1.2rem;margin:14px 0 8px}.connection-state p{max-width:760px;margin:auto;line-height:1.8}
    .phenomena-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:20px;margin-bottom:28px}.phenomenon-card{background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 4px 12px rgba(0,0,0,.1)}.phenomenon-card header{padding:15px;color:#fff;display:flex;justify-content:space-between;align-items:center;gap:10px}.phenomenon-card header div{display:grid;gap:7px}.phenomenon-card header strong{font-size:1.05rem}.phenomenon-card header span{font-size:.85rem;opacity:.9}.phenomenon-card header b{font-size:.82rem;background:#ffffff25;border-radius:18px;padding:5px 10px;white-space:nowrap}
    .card-body{padding:15px}.card-body p{display:flex;justify-content:space-between;gap:12px;margin:0 0 10px}.card-body p strong{color:#2c3e50}.card-body p span{color:#34495e;text-align:left}.card-actions{display:flex;gap:8px;justify-content:center;margin-top:16px}.card-actions button{background:#3498db;padding:8px 12px;font-size:.85rem}.card-actions button.outline{background:#fff;color:#34495e;border:1px solid #ced4da}
    .rainfall-table-section,.detail-panel{margin-top:28px;background:#fff;border:1px solid #e5e9ec;border-radius:9px;padding:18px}.table-heading{background:#2c3e50;color:#fff;padding:13px;border-radius:7px 7px 0 0;font-weight:600}.table-scroll{overflow-x:auto}table{width:100%;border-collapse:collapse;background:#fff}th,td{border:1px solid #dee2e6;padding:12px;text-align:center;min-width:110px}th{background:#ecf0f1;color:#2c3e50}td{font-family:monospace}
    .detail-panel h4{color:#2c3e50;border-bottom:1px solid #dee2e6;padding-bottom:7px;margin:20px 0 12px}.detail-head{display:flex;justify-content:space-between;align-items:center}.detail-head h3{margin:0;color:#2c3e50}.detail-head button{border:0;background:#6c757d;color:white;border-radius:6px;padding:7px 12px}.detail-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 18px}.detail-grid p{margin:6px 0}.help{margin-top:28px;background:#f8f9fa;border-radius:8px;padding:16px 20px;line-height:1.9}.help summary{font-weight:700;color:#2c3e50;cursor:pointer}.help h4{font-size:1rem;margin:15px 0 5px}
    @media(max-width:850px){.filters{grid-template-columns:repeat(2,minmax(0,1fr))}.topbar{align-items:flex-start}.clock{max-width:100%}}@media(max-width:580px){.filters,.detail-grid{grid-template-columns:1fr}.main-card{padding:15px}.phenomena-cards{grid-template-columns:1fr}.card-body p{font-size:.9rem}}
  `]
})
export class PhenomenaComponent {
  readonly hours = ['00', '06', '12', '18'];
  readonly allPhenomena: WeatherPhenomenon[] = [];
  filterDate = '';
  filterType = '';
  filterStation = '';
  filterIntensity = '';
  filterStartDate = '';
  filterEndDate = '';
  selectedDetail: WeatherPhenomenon | null = null;
  selectedTable: WeatherPhenomenon | null = null;
  currentDate = '';
  currentTime = '';
  utcTime = '';

  constructor() { this.updateDateTime(); }

  get stations(): string[] {
    return [...new Set(this.allPhenomena.map(p => p.station_name).filter((x): x is string => !!x))].sort();
  }

  get filteredPhenomena(): WeatherPhenomenon[] {
    return this.allPhenomena.filter(p =>
      (!this.filterDate || p.phenomenon_date === this.filterDate) &&
      (!this.filterType || p.phenomenon_type === this.filterType) &&
      (!this.filterStation || (p.station_name || '').toLocaleLowerCase().includes(this.filterStation.toLocaleLowerCase())) &&
      (!this.filterIntensity || p.intensity === this.filterIntensity) &&
      (!this.filterStartDate || p.phenomenon_date >= this.filterStartDate) &&
      (!this.filterEndDate || p.phenomenon_date <= this.filterEndDate)
    );
  }

  get totalRain(): number { return this.filteredPhenomena.reduce((sum, p) => sum + this.phenomenonRain(p), 0); }
  get totalSnow(): number { return this.filteredPhenomena.reduce((sum, p) => sum + this.phenomenonSnow(p), 0); }
  get averageDuration(): number {
    if (!this.filteredPhenomena.length) return 0;
    return this.filteredPhenomena.reduce((sum, p) => sum + this.durationHours(p), 0) / this.filteredPhenomena.length;
  }

  private updateDateTime(): void {
    const now = new Date();
    this.currentDate = now.toLocaleDateString('ar-SA');
    this.currentTime = now.toLocaleTimeString('en-GB', { hour12: false });
    this.utcTime = now.toISOString().slice(11, 19);
  }

  applyFilters(): void {
    this.selectedDetail = null;
    this.selectedTable = null;
  }

  resetFilters(): void {
    this.filterDate = this.filterType = this.filterStation = this.filterIntensity = '';
    this.filterStartDate = this.filterEndDate = '';
    this.applyFilters();
  }

  refreshData(): void {
    // Intentionally unavailable until the approved API is connected.
  }

  typeName(type: string): string {
    const names: Record<string, string> = { rain: 'مطر', snow: 'ثلج', rain_snow: 'مطر وثلج معاً', hail: 'برد', drizzle: 'رذاذ', storm: 'عاصفة رعدية' };
    return names[type] || type || 'غير محدد';
  }

  intensityName(intensity: string): string {
    const names: Record<string, string> = { light: 'خفيفة', moderate: 'متوسطة', heavy: 'شديدة', very_heavy: 'شديدة جداً' };
    return names[intensity] || intensity || 'غير محددة';
  }

  typeColor(type: string): string {
    const colors: Record<string, string> = { rain: '#3498db', snow: '#7f8c8d', rain_snow: '#9b59b6', hail: '#34495e', drizzle: '#3498db', storm: '#e74c3c' };
    return colors[type] || '#3498db';
  }

  typeIcon(type: string): string {
    const icons: Record<string, string> = { rain: 'fa-solid fa-cloud-rain', snow: 'fa-solid fa-snowflake', rain_snow: 'fa-solid fa-cloud-rain', hail: 'fa-solid fa-cloud-meatball', drizzle: 'fa-solid fa-cloud-rain', storm: 'fa-solid fa-bolt' };
    return icons[type] || 'fa-solid fa-cloud';
  }

  phenomenonRain(p: WeatherPhenomenon): number {
    return this.hours.reduce((sum, h) => sum + (Number(this.rainAt(p, h)) || 0), 0);
  }
  phenomenonSnow(p: WeatherPhenomenon): number {
    return this.hours.reduce((sum, h) => sum + (Number.parseInt(String(this.snowAt(p, h)), 10) || 0), 0);
  }
  rainAt(p: WeatherPhenomenon, h: string): string { return String(p[`hour_${h}_rain` as keyof WeatherPhenomenon] ?? '000.0'); }
  snowAt(p: WeatherPhenomenon, h: string): string { return String(p[`hour_${h}_snow` as keyof WeatherPhenomenon] ?? '000'); }
  notesAt(p: WeatherPhenomenon, h: string): string { return String(p[`hour_${h}_notes` as keyof WeatherPhenomenon] ?? ''); }

  private durationHours(p: WeatherPhenomenon): number {
    if (!p.start_time || !p.end_time) return 0;
    const [sh, sm] = p.start_time.split(':').map(Number);
    const [eh, em] = p.end_time.split(':').map(Number);
    let mins = eh * 60 + em - (sh * 60 + sm);
    if (mins < 0) mins += 1440;
    return mins / 60;
  }

  showDetail(p: WeatherPhenomenon): void { this.selectedDetail = p; this.selectedTable = null; }
  showRainfallTable(p: WeatherPhenomenon): void { this.selectedTable = p; this.selectedDetail = null; }

  exportAllData(): void {
    if (!this.filteredPhenomena.length) return;
    const data = { export_date: new Date().toISOString(), total_records: this.filteredPhenomena.length, phenomena: this.filteredPhenomena };
    this.download(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }), `ظواهر_مطر_ثلج_${new Date().toISOString().slice(0, 10)}.json`);
  }

  exportRainfallData(): void {
    if (!this.selectedTable) return;
    const p = this.selectedTable;
    const rows = [
      ['جدول تأشيرات المطر والثلج', '', '', ''],
      ['نوع الظاهرة', this.typeName(p.phenomenon_type), '', ''],
      ['التاريخ', p.phenomenon_date, '', ''],
      ['المحطة', p.station_name || 'غير محددة', '', ''],
      ['الراصد', p.user_name || 'غير محدد', '', ''],
      ['وقت البداية (UTC)', p.start_time, '', ''],
      ['وقت النهاية (UTC)', p.end_time, '', ''],
      [],
      ['الساعة (UTC)', 'كمية المطر (مم)', 'كمية الثلج (سم)', 'ملاحظات'],
      ...this.hours.map(h => [h + ':00', this.rainAt(p, h), this.snowAt(p, h), this.notesAt(p, h)])
    ];
    const csv = '\uFEFF' + rows.map(row => row.map(value => this.csvCell(value)).join(',')).join('\r\n');
    this.download(new Blob([csv], { type: 'text/csv;charset=utf-8' }), `تأشيرات_مطر_ثلج_${p.phenomenon_date}.csv`);
  }

  private csvCell(value: unknown): string {
    const text = String(value ?? '');
    const safe = /^[\s\u0000-\u001f]*[=+\-@]/.test(text) ? `'${text}` : text;
    return `"${safe.replace(/"/g, '""')}"`;
  }

  private download(blob: Blob, filename: string): void {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  }

  printRainfallTable(): void {
    if (!this.selectedTable) return;
    this.printContent('جدول تأشيرات المطر والثلج (UTC)', this.tableHtml(this.selectedTable));
  }

  printDetail(): void {
    if (!this.selectedDetail) return;
    const p = this.selectedDetail;
    const html = `<h3>معلومات الظاهرة</h3><p>نوع الظاهرة: ${this.escapeHtml(this.typeName(p.phenomenon_type))}</p><p>التاريخ: ${this.escapeHtml(p.phenomenon_date)}</p><p>وقت البداية (UTC): ${this.escapeHtml(p.start_time)}</p><p>وقت النهاية (UTC): ${this.escapeHtml(p.end_time)}</p><p>المدة: ${this.escapeHtml(p.phenomenon_duration || 'غير محددة')}</p><p>الشدة: ${this.escapeHtml(this.intensityName(p.intensity))}</p>${this.tableHtml(p)}`;
    this.printContent('تفاصيل الظاهرة الجوية', html);
  }

  private escapeHtml(value: unknown): string {
    const entities: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    };
    return String(value ?? '').replace(/[&<>"']/g, character => entities[character] ?? character);
  }

  private tableHtml(p: WeatherPhenomenon): string {
    return `<table><thead><tr><th>الساعة (UTC)</th><th>كمية المطر (مم) ddd.d</th><th>كمية الثلج (سم) ddd</th><th>ملاحظات</th></tr></thead><tbody>${this.hours.map(h => `<tr><td>${this.escapeHtml(h)}:00</td><td>${this.escapeHtml(this.rainAt(p,h))}</td><td>${this.escapeHtml(this.snowAt(p,h))}</td><td>${this.escapeHtml(this.notesAt(p,h))}</td></tr>`).join('')}</tbody></table>`;
  }

  private printContent(title: string, html: string): void {
    const win = window.open('', '_blank');
    if (!win) return;
    const safeTitle = this.escapeHtml(title);
    win.document.write(`<!doctype html><html dir="rtl"><head><meta charset="utf-8"><title>${safeTitle}</title><style>body{font-family:Arial,sans-serif;padding:20px}h2{text-align:center;color:#2c3e50}table{width:100%;border-collapse:collapse;margin-top:20px}th,td{border:1px solid #ddd;padding:10px;text-align:center}th{background:#2c3e50;color:#fff}</style></head><body><h2>${safeTitle}</h2>${html}</body></html>`);
    win.document.close(); win.focus(); win.print();
  }
}
