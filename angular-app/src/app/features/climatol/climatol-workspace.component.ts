import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';

type ClimatolView = 'setup' | 'pipeline' | 'diagnostics' | 'versions';

@Component({
  standalone: true,
  selector: 'metra-climatol-workspace',
  imports: [CommonModule, FormsModule],
  template: `
    <main class="workspace" dir="rtl">
      <header><div><span class="eyebrow">METRA 2027 · التحليل المناخي</span><h1>تجانس السلاسل المناخية — Climatol</h1>
        <p>إعداد مجموعة المحطات والسلاسل ومراجعة التشخيصات والإصدارات دون تعديل السجلات الأصلية.</p></div>
        <span class="state">عامل المعالجة غير مربوط</span>
      </header>
      <div class="warning">لا يوجد Climatol worker أو API للمهام والنتائج. هذه واجهة إعداد فقط؛ لن يتم تشغيل خوارزمية أو عرض نتائج مصطنعة.</div>
      <nav class="tabs">
        <button type="button" [class.active]="view==='setup'" (click)="view='setup'">إعداد التحليل</button>
        <button type="button" [class.active]="view==='pipeline'" (click)="view='pipeline'">خطوات المعالجة</button>
        <button type="button" [class.active]="view==='diagnostics'" (click)="view='diagnostics'">التشخيص</button>
        <button type="button" [class.active]="view==='versions'" (click)="view='versions'">الإصدارات</button>
      </nav>
      @if (view === 'setup') {
        <section class="panel">
          <h2>1. المحطات الداخلة في مجموعة التجانس</h2>
          <div class="toolbar"><input type="search" [(ngModel)]="search" placeholder="ابحث باسم المحطة أو الرمز">
            <button type="button" (click)="loadStations()" [disabled]="loading">تحديث دليل المحطات</button></div>
          @if (loading) { <p>جارٍ تحميل المحطات المعتمدة…</p> }
          @if (error) { <p class="error" role="alert">{{ error }}</p> }
          @if (!loading && stations.length === 0) { <div class="empty">لا توجد محطات معتمدة متاحة.</div> }
          <div class="station-list">
            @for (station of filteredStations; track station.id) {
              <label class="station">
                <input type="checkbox" [checked]="selectedStations.has(station.id)" (change)="toggleStation(station.id, $any($event.target).checked)">
                <span><strong>{{ station.name_ar }}</strong><small>{{ station.local_station_code || station.id }} · الارتفاع {{ station.elevation_m ?? 'غير متاح' }} م</small></span>
              </label>
            }
          </div>
          <p class="selected">المحطات المحددة: {{ selectedStations.size }}</p>
          <h2>2. المتغيرات المناخية</h2>
          <div class="variables">
            @for (variable of variables; track variable.code) {
              <label><input type="checkbox" [checked]="selectedVariables.has(variable.code)" (change)="toggleVariable(variable.code, $any($event.target).checked)">{{ variable.label }}</label>
            }
          </div>
          <h2>3. الفترة الزمنية UTC</h2>
          <div class="fields"><label>من<input type="date" [(ngModel)]="periodStart"></label><label>إلى<input type="date" [(ngModel)]="periodEnd"></label></div>
          <h2>4. مجموعة المرجع وطريقة المعالجة</h2>
          <div class="fields">
            <label>مجموعة المرجع<select [(ngModel)]="referenceMode"><option value="regional">محطات إقليمية متقاربة</option><option value="elevation">مراعاة نطاقات الارتفاع</option><option value="network">شبكة المحطات المختارة</option></select></label>
            <label>منهج المعالجة<select [(ngModel)]="method"><option value="climatol">Climatol — تجانس</option><option value="diagnostic">تشخيص أولي فقط</option></select></label>
          </div>
          <label class="check"><input type="checkbox" [(ngModel)]="includeIncomplete"> إظهار السلاسل غير المكتملة ضمن التشخيص (لا يعني قبولها)</label>
          <button type="button" disabled>تشغيل التجانس — بانتظار العامل الخادمي</button>
          <small>الإعداد الحالي في الواجهة فقط: {{ selectedStations.size }} محطة، {{ selectedVariables.size }} متغير. لا يتم حفظ مهمة.</small>
        </section>
      } @else if (view === 'pipeline') {
        <section class="panel"><h2>سير المعالجة المقترح</h2>
          <article class="step"><b>1</b><div><strong>فحص المصدر</strong><p>هوية المحطة والمتغير والوحدة والتقويم والتوقيت UTC والقيم المفقودة وبصمة الملف.</p></div></article>
          <article class="step"><b>2</b><div><strong>فحص جودة السلاسل</strong><p>الاستمرارية والتكرارات والقيم المستحيلة والفجوات والتغيرات الوصفية.</p></div></article>
          <article class="step"><b>3</b><div><strong>اختيار السلاسل المرجعية</strong><p>التقارب الجغرافي والارتفاع والارتباط وطول التداخل.</p></div></article>
          <article class="step"><b>4</b><div><strong>التشغيل المعزول</strong><p>تنفيذ إصدار محدد في عامل منفصل عن API الرئيسي.</p></div></article>
          <article class="step"><b>5</b><div><strong>مراجعة التشخيص</strong><p>نقاط الانقطاع والمقاطع غير المتجانسة والمؤشرات وحدود الثقة.</p></div></article>
          <article class="step"><b>6</b><div><strong>اعتماد النتائج</strong><p>مراجعة بشرية وحفظ إصدار جديد دون تعديل القيم الأصلية.</p></div></article>
        </section>
      } @else if (view === 'diagnostics') {
        <section class="panel"><h2>لوحة التشخيص</h2><div class="empty"><strong>لا توجد نتائج تشخيص</strong><p>تظهر الرسوم ونقاط الانقطاع بعد تنفيذ مهمة معتمدة واستلام نتائج العامل.</p></div>
          <div class="metrics"><span>فجوات البيانات <b>بانتظار الخادم</b></span><span>ارتباط المحطات <b>بانتظار الخادم</b></span><span>نقاط الانقطاع <b>بانتظار الخادم</b></span><span>بصمة البيانات <b>غير متوفرة</b></span></div>
        </section>
      } @else {
        <section class="panel"><h2>إصدارات المعالجة</h2><div class="empty"><strong>لا توجد إصدارات محفوظة</strong><p>تتطلب إدارة الإصدارات API للمهام والنتائج وبصمات البيانات وإصدار البرنامج.</p></div>
          <ul><li>بيانات المصدر وبصمة SHA-256.</li><li>إصدار Climatol والمعايير والفترة UTC.</li><li>نتائج قابلة لإعادة الإنتاج وسجل التنفيذ.</li><li>اعتماد بشري وخطة تراجع.</li></ul>
        </section>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.workspace{max-width:1200px;margin:auto;padding:12px}header{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:25px;margin:7px 0}h2{font-size:16px;margin:12px 0}.state{height:max-content;background:#fff4df;color:#8c5b12;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700}.warning{background:#fff7e8;border:1px solid #f0dfb9;border-right:4px solid #d49a37;padding:13px;border-radius:9px;margin:14px 0;line-height:1.7}.tabs{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px}.tabs button,.toolbar button{border:1px solid #dce5eb;background:#fff;border-radius:8px;padding:9px 13px;color:#506675;cursor:pointer}.tabs button.active{background:#287caf;color:#fff}.panel{background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:18px;display:grid;gap:12px}.toolbar{display:flex;gap:10px}.toolbar input{flex:1}.station-list{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:8px;max-height:300px;overflow:auto}.station{display:flex;gap:9px;align-items:center;padding:10px;border:1px solid #e5edf1;border-radius:8px}.station span{display:grid;gap:3px}.station small,small{font-size:11px;color:#7e8d96}.selected{color:#287caf;font-weight:700}.variables{display:flex;gap:15px;flex-wrap:wrap}.variables label,.check{display:flex;align-items:center;gap:7px}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}label{display:grid;gap:6px;font-size:12px;font-weight:700;color:#5e707c}input,select{border:1px solid #d8e2e8;border-radius:8px;padding:9px;font:inherit;min-width:0}.variables label input,.check input,.station input{width:auto}.panel>button{border:0;border-radius:8px;padding:11px;background:#287caf;color:#fff;font:inherit;font-weight:700}.panel>button:disabled{opacity:.55}.empty{border:1px dashed #cddae2;border-radius:10px;background:#f7fafc;padding:24px;text-align:center}.empty p{color:#75848e;margin-top:6px}.step{display:flex;gap:12px;padding:12px;border:1px solid #e5edf1;border-radius:9px}.step>b{width:30px;height:30px;display:grid;place-items:center;border-radius:50%;background:#eaf4fa;color:#287caf}.step p{color:#71818b;margin:4px 0 0}.metrics{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}.metrics span{display:flex;justify-content:space-between;padding:12px;background:#f7fafc;border-radius:8px;font-size:12px}.error{color:#a33b35}@media(max-width:700px){.fields,.metrics{grid-template-columns:1fr}}
  `]
})
export class ClimatolWorkspaceComponent implements OnInit {
  private readonly api = inject(ObservationApiService);
  view: ClimatolView = 'setup';
  stations: StationDirectoryItem[] = [];
  selectedStations = new Set<string>();
  selectedVariables = new Set<string>(['temperature']);
  search = '';
  periodStart = '';
  periodEnd = '';
  referenceMode = 'regional';
  method = 'climatol';
  includeIncomplete = false;
  loading = false;
  error = '';
  readonly variables = [
    { code: 'temperature', label: 'درجة الحرارة' },
    { code: 'pressure', label: 'الضغط الجوي' },
    { code: 'precipitation', label: 'الهطول' },
    { code: 'humidity', label: 'الرطوبة النسبية' },
    { code: 'wind_speed', label: 'سرعة الرياح' }
  ];

  get filteredStations(): StationDirectoryItem[] {
    const query = this.search.trim().toLocaleLowerCase();
    return this.stations.filter(s => !query ||
      `${s.name_ar} ${s.local_station_code ?? ''}`.toLocaleLowerCase().includes(query));
  }

  ngOnInit(): void { void this.loadStations(); }

  async loadStations(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      this.stations = (await this.api.getAllStations())
        .filter(s => s.approval_status === 'approved' && s.operational_status === 'active' && !s.is_demo);
    } catch {
      this.error = 'تعذر تحميل دليل المحطات المعتمد. أعد المحاولة أو تحقق من صلاحياتك.';
    } finally { this.loading = false; }
  }

  toggleStation(id: string, checked: boolean): void {
    const next = new Set(this.selectedStations);
    if (checked) next.add(id); else next.delete(id);
    this.selectedStations = next;
  }

  toggleVariable(code: string, checked: boolean): void {
    const next = new Set(this.selectedVariables);
    if (checked) next.add(code); else next.delete(code);
    this.selectedVariables = next;
  }
}
