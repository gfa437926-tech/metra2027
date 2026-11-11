import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';

type AuditorView = 'dashboard' | 'paper' | 'mechanical' | 'comparison' | 'review' | 'library' | 'training' | 'reports';

@Component({
  standalone: true,
  selector: 'metra-electronic-auditor-workspace',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="ea-page" dir="rtl">
      <header><div><span class="eyebrow">METRA 2027 · جودة السجلات</span><h1>التدقيق الإلكتروني</h1>
        <p>مقارنة السجلات الورقية والمخططات الميكانيكية والرصد الإلكتروني مع حفظ الأدلة والقرار البشري.</p></div>
        <span class="state">خدمات التدقيق غير مربوطة</span>
      </header>
      <div class="warning" role="status">لم تُربط بعد خدمات رفع الأصول أو OCR أو رقمنة المخططات أو إنشاء حالات التدقيق. لن تظهر نتائج مطابقة أو أرقام وهمية ولن تُعدّل النشرات الأصلية.</div>
      <nav class="tabs">
        <button type="button" [class.active]="view==='dashboard'" (click)="view='dashboard'">لوحة التدقيق</button>
        <button type="button" [class.active]="view==='paper'" (click)="view='paper'">السجلات الورقية</button>
        <button type="button" [class.active]="view==='mechanical'" (click)="view='mechanical'">المسجلات الميكانيكية</button>
        <button type="button" [class.active]="view==='comparison'" (click)="view='comparison'">المقارنة</button>
        <button type="button" [class.active]="view==='review'" (click)="view='review'">مراجعة القراءات</button>
        <button type="button" [class.active]="view==='library'" (click)="view='library'">المكتبة</button>
        <button type="button" [class.active]="view==='training'" (click)="view='training'">مختبر التدريب</button>
        <button type="button" [class.active]="view==='reports'" (click)="view='reports'">التقارير</button>
      </nav>
      @if (view === 'dashboard') {
        <section class="panel">
          <h2>ملخص الحالات</h2><div class="metrics"><span>واردة <b>—</b></span><span>مطابقة <b>—</b></span><span>اختلافات <b>—</b></span><span>بانتظار المراجع <b>—</b></span></div>
          <h2>سياق التدقيق</h2>
          <label>المحطة<select [(ngModel)]="stationId" name="station"><option value="">اختر محطة معتمدة</option>@for (s of stations; track s.id) { <option [value]="s.id">{{ s.name_ar }} — {{ s.local_station_code }}</option> }</select></label>
          <div class="fields"><label>تاريخ السجل UTC<input type="date" [(ngModel)]="caseDate" name="caseDate"></label><label>مسار التدقيق<select [(ngModel)]="track" name="track"><option value="paper">السجل الورقي</option><option value="mechanical">المسجل الميكانيكي</option><option value="combined">ثلاثي المصادر</option></select></label></div>
          <button type="button" disabled>إنشاء حالة — بانتظار API</button>
          <div class="empty">لا توجد حالات تدقيق متاحة ضمن الصلاحيات الحالية أو لم يتم ربط API الحالات.</div>
        </section>
      } @else if (view === 'paper') {
        <section class="panel"><h2>بيانات صفحة السجل الورقي</h2>
          <label>المحطة<select [(ngModel)]="stationId" name="paperStation"><option value="">اختر محطة</option>@for (s of stations; track s.id) { <option [value]="s.id">{{ s.name_ar }}</option> }</select></label>
          <div class="fields"><label>نوع السجل<select [(ngModel)]="registerType" name="registerType"><option value="daily">سجل يومي</option><option value="hourly">سجل ساعي</option></select></label><label>تاريخ السجل UTC<input type="date" [(ngModel)]="caseDate" name="paperDate"></label><label>رقم الصفحة<input [(ngModel)]="pageNumber" name="pageNumber" inputmode="numeric"></label></div>
          <label>اختيار ملف الصفحة (معاينة محلية فقط)<input type="file" accept="image/png,image/jpeg,application/pdf" (change)="selectPaperFile($event)"></label>
          @if (paperFileName) { <p class="file-meta">الملف المحدد: {{ paperFileName }} · {{ paperFileSize | number }} بايت — لم يُرفع.</p> }
          <div class="upload"><strong>رفع وحفظ الأصل</strong><p>زر الرفع غير مفعّل حتى اعتماد التخزين وAPI بصمة الأصل.</p></div>
          <button type="button" disabled>رفع الصفحة — بانتظار API التخزين</button>
          <ul><li>حفظ الأصل وبصمة SHA-256.</li><li>تصنيف القالب واستخراج الخانات ومواضعها.</li><li>مراجعة بشرية لكل قيمة مستخرجة.</li></ul>
        </section>
      } @else if (view === 'mechanical') {
        <section class="panel"><h2>تعريف الجهاز والمخطط</h2>
          <label>المحطة<select [(ngModel)]="stationId" name="chartStation"><option value="">اختر محطة</option>@for (s of stations; track s.id) { <option [value]="s.id">{{ s.name_ar }}</option> }</select></label>
          <label>نوع المسجل<select [(ngModel)]="instrument" name="instrument"><option value="thermograph">Thermograph — الحرارة</option><option value="hygrograph">Hygrograph — الرطوبة</option><option value="barograph">Barograph — الضغط</option><option value="pluviograph">Pluviograph — الهطول</option></select></label>
          <label>مرجع المعايرة وملاحظات المختص<textarea [(ngModel)]="calibrationNote" name="calibration" rows="3"></textarea></label>
          <label>اختيار ملف المخطط (معاينة محلية فقط)<input type="file" accept="image/png,image/jpeg,application/pdf" (change)="selectMechanicalFile($event)"></label>
          @if (mechanicalFileName) { <p class="file-meta">الملف المحدد: {{ mechanicalFileName }} · {{ mechanicalFileSize | number }} بايت — لم يُرفع.</p> }
          <div class="upload"><strong>رفع المخطط ورقمنته</strong><p>لا توجد خدمة رفع أو معايرة أو استخراج في هذه النسخة.</p></div>
          <button type="button" disabled>رفع المخطط — بانتظار API التخزين</button>
          <ul><li>تعريف المحاور والوحدات والمدى.</li><li>تحديد المنحنى ونقاط المعايرة.</li><li>مراجعة بشرية قبل المقارنة.</li></ul>
        </section>
      } @else if (view === 'comparison') {
        <section class="panel"><h2>مصادر المقارنة</h2>
          <label class="check"><input type="checkbox" [(ngModel)]="paperSource" name="paperSource"> السجل الورقي</label>
          <label class="check"><input type="checkbox" [(ngModel)]="mechanicalSource" name="mechanicalSource"> المسجل الميكانيكي</label>
          <label class="check"><input type="checkbox" [(ngModel)]="electronicSource" name="electronicSource"> الرصد الإلكتروني من METRA</label>
          <label>قاعدة محاذاة الوقت UTC<select [(ngModel)]="alignment" name="alignment"><option value="exact">تطابق وقت UTC</option><option value="nearest">أقرب عينة وفق سماحية معتمدة</option><option value="window">نافذة زمنية وفق سياسة المتغير</option></select></label>
          <div class="empty"><strong>لا توجد نتائج مقارنة</strong><p>ستعرض النتائج قيمة كل مصدر والفارق والوحدة وموضع الصورة وإصدار قاعدة التحقق.</p></div>
          <button type="button" disabled>تنفيذ المقارنة — بانتظار خدمة المقارنة</button>
        </section>
      } @else if (view === 'review') {
        <section class="panel"><h2>مراجعة القراءات</h2><div class="empty">لا توجد قراءات بانتظار المراجعة. تتطلب القائمة API وصلاحيات قراءة وتصحيح منفصلة عن الاعتماد.</div>
          <ul><li>مطابقة ضمن سماحية المتغير.</li><li>اختلاف يحتاج تفسيراً.</li><li>غير حاسم بسبب جودة الصورة أو التوقيت أو المعايرة.</li><li>مرفوض بسبب عدم وضوح الأصل أو عدم دعم القالب.</li></ul>
          <label>ملاحظة المراجع<textarea rows="3" disabled></textarea></label><button type="button" disabled>حفظ القرار — بانتظار API</button>
        </section>
      } @else if (view === 'library') {
        <section class="panel"><h2>مكتبة القوالب والأجهزة</h2><div class="empty">لا توجد قوالب أو أجهزة معتمدة في هذه الواجهة. يلزم توثيق الطراز والمقياس والمعايرة وإصدار القالب.</div>
          <ul><li>Thermograph</li><li>Hygrograph</li><li>Barograph</li><li>Pluviograph</li></ul>
        </section>
      } @else if (view === 'training') {
        <section class="panel"><h2>مختبر التدريب</h2><ol><li>مجموعة بيانات بصمات أصول الصور.</li><li>وسوم مرجعية معتمدة من المختص.</li><li>تقسيم تدريب/تحقق/اختبار دون تسرب.</li><li>تقييم على محطات وصور مستقلة.</li><li>ترقية نموذج بموافقة وخطة تراجع.</li></ol><div class="empty">لا توجد مجموعات تدريب أو إصدارات نموذج.</div></section>
      } @else {
        <section class="panel"><h2>تقارير التدقيق</h2><div class="empty">لا توجد تقارير. التقرير النهائي يتطلب الحالة والأدلة والفترة UTC والنتائج وإصدارات القواعد والقرار البشري.</div></section>
      }
      <footer><a routerLink="/">العودة للوحة التحكم</a> · <a routerLink="/stations">دليل المحطات</a> · <a routerLink="/observations/workflow">مراجعة النشرات</a></footer>
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.ea-page{max-width:1250px;margin:auto;padding:12px}header{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:25px;margin:7px 0}h2{font-size:17px;margin:0 0 12px}.state{height:max-content;background:#fff4df;color:#8c5b12;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700}.warning{background:#fff7e8;border:1px solid #f0dfb9;border-right:4px solid #d49a37;padding:13px;border-radius:9px;margin:14px 0;line-height:1.7}.tabs{display:flex;flex-wrap:wrap;gap:5px;margin-bottom:14px}.tabs button{border:1px solid #dce5eb;background:#fff;border-radius:8px;padding:8px 11px;color:#506675;cursor:pointer}.tabs button.active{background:#287caf;color:#fff}.panel{background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:18px;display:grid;gap:12px}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}label{display:grid;gap:6px;font-size:12px;font-weight:700;color:#5e707c}input,select,textarea{border:1px solid #d8e2e8;border-radius:8px;padding:9px;font:inherit;min-width:0}.check{display:flex;align-items:center;gap:8px}.check input{width:auto}.panel>button{border:0;border-radius:8px;padding:10px;background:#287caf;color:#fff;font:inherit;font-weight:700}.panel>button:disabled{opacity:.55}.empty,.upload{border:1px dashed #cddae2;border-radius:10px;background:#f7fafc;padding:22px;text-align:center}.empty p,.upload p{color:#75848e;margin-top:6px}.upload{display:grid;gap:5px}li{line-height:2;color:#566b79}footer{margin-top:16px;font-size:12px}footer a{color:#287caf;margin-inline:4px}@media(max-width:700px){.fields{grid-template-columns:1fr}}
  `]
})
export class ElectronicAuditorWorkspaceComponent implements OnInit {
  private readonly api = inject(ObservationApiService);
  stations: StationDirectoryItem[] = [];
  view: AuditorView = 'dashboard';
  stationId = '';
  caseDate = '';
  track = 'paper';
  registerType = 'daily';
  pageNumber = '';
  instrument = 'thermograph';
  calibrationNote = '';
  alignment = 'exact';
  paperSource = true;
  mechanicalSource = false;
  electronicSource = true;
  paperFileName = '';
  paperFileSize = 0;
  mechanicalFileName = '';
  mechanicalFileSize = 0;

  selectPaperFile(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.item(0);
    this.paperFileName = file?.name ?? '';
    this.paperFileSize = file?.size ?? 0;
  }

  selectMechanicalFile(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.item(0);
    this.mechanicalFileName = file?.name ?? '';
    this.mechanicalFileSize = file?.size ?? 0;
  }

  ngOnInit(): void {
    void this.api.getAllStations().then(rows => {
      this.stations = rows.filter(s => s.approval_status === 'approved' && s.operational_status === 'active' && !s.is_demo);
    }).catch(() => { this.stations = []; });
  }
}
