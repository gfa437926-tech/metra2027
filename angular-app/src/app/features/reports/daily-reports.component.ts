import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

type DailyStatus = 'draft' | 'submitted';
interface DailyPreview { reference: string; date: string; reportType: string; station: string; status: DailyStatus; values: Record<string,string>; }

@Component({
  standalone: true,
  selector: 'metra-daily-reports',
  imports: [CommonModule],
  template: `
    <div class="page" dir="rtl">
      <header class="page-head"><div class="head-icon"><i class="fa-regular fa-calendar-days"></i></div><div><h1>النشرات اليومية</h1><p>تسجيل ملخص الحالة الجوية وعناصر الرصد اليومية</p></div><span class="preview-tag"><i class="fa-solid fa-flask"></i> وضع تجريبي</span></header>
      <div class="demo-warning"><i class="fa-solid fa-circle-info"></i><div><strong>معاينة تجريبية وليست نظام حفظ فعلياً.</strong><span>التحقق وإنشاء المسودات يتمان داخل الصفحة فقط؛ لا يوجد اتصال بقاعدة البيانات أو API.</span></div></div>
      <section class="type-panel">
        <strong>نوع التقرير</strong>
        <div class="type-options">
          <label><input type="radio" name="reportType" value="24h" [checked]="reportType === '24h'" (change)="setType('24h')"> ملخص يومي بتاريخ اليوم السابق</label>
          <label><input type="radio" name="reportType" value="06utc" [checked]="reportType === '06utc'" (change)="setType('06utc')"> 06 UTC</label>
          <label><input type="radio" name="reportType" value="18utc" [checked]="reportType === '18utc'" (change)="setType('18utc')"> 18 UTC</label>
        </div>
        <p>{{ typeDescription }}</p>
      </section>

      <form #dailyForm (submit)="submit($event, dailyForm)">
        <section class="panel"><h2><i class="fa-solid fa-calendar-check"></i> معلومات النشرة</h2><div class="grid">
          <label>التاريخ<input type="date" name="currentDate" [value]="today" required></label>
          <label>المحطة<input name="station" required maxlength="50" placeholder="اسم أو رمز المحطة"></label>
          <label>اسم الراصد<input name="observer" required maxlength="100" placeholder="اسم الراصد"></label>
        </div></section>

        <section class="panel"><h2><i class="fa-solid fa-temperature-half"></i> درجات الحرارة العظمى والصغرى</h2><div class="grid">
          <div class="daily-field"><label>القيمة الصغرى في النهايات (سْ)<input #minTempField name="minTemp" maxlength="6" placeholder="-05.3" required (blur)="formatField($event)"><small>الصيغة -dd.d أو dd.d، أو # عند عدم توفر البيانات</small></label><div class="field-actions"><button type="button" class="sign-toggle" (click)="toggleTemperatureSign(minTempField)" [disabled]="minTempField.value === '#'">{{ minTempField.value.startsWith('-') ? '+' : '−' }}</button><button type="button" class="no-data-btn" [class.active]="isNoData('minTemp')" (click)="toggleNoData(minTempField, 'minTemp')">{{ isNoData('minTemp') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>القيمة العظمى في النهايات (سْ)<input #maxTempField name="maxTemp" maxlength="6" placeholder="25.7" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="sign-toggle" (click)="toggleTemperatureSign(maxTempField)" [disabled]="maxTempField.value === '#'">{{ maxTempField.value.startsWith('-') ? '+' : '−' }}</button><button type="button" class="no-data-btn" [class.active]="isNoData('maxTemp')" (click)="toggleNoData(maxTempField, 'maxTemp')">{{ isNoData('maxTemp') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>كمية الهطول لأقرب مم<input #precipitationField name="precipitation" maxlength="5" placeholder="012.5" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('precipitation')" (click)="toggleNoData(precipitationField, 'precipitation')">{{ isNoData('precipitation') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>أكبر سماكة ثلج لأقرب سم<input #snowThicknessField name="snowThickness" maxlength="3" placeholder="015" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('snowThickness')" (click)="toggleNoData(snowThicknessField, 'snowThickness')">{{ isNoData('snowThickness') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>الأثر (T)<input #precipitationTraceField name="precipitationTrace" maxlength="1" placeholder="T" (blur)="formatField($event)"><small>الحرف T أو t عند وجود أثر فقط</small></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('precipitationTrace')" (click)="toggleNoData(precipitationTraceField, 'precipitationTrace')">{{ isNoData('precipitationTrace') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
        </div></section>

        <section class="panel" *ngIf="reportType === '24h'"><h2><i class="fa-solid fa-sun"></i> التبخر وسطوع الشمس</h2><div class="grid">
          <div class="daily-field"><label>مجموع التبخر اليومي لأقرب عشر مم<input #evaporationField name="evaporation" maxlength="4" placeholder="12.5" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('evaporation')" (click)="toggleNoData(evaporationField, 'evaporation')">{{ isNoData('evaporation') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>مجموع مدة سطوع الشمس الحقيقي<input #sunshineDurationField name="sunshineDuration" maxlength="4" placeholder="08.5" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('sunshineDuration')" (click)="toggleNoData(sunshineDurationField, 'sunshineDuration')">{{ isNoData('sunshineDuration') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>النسبة المئوية لسطوع الشمس<input #sunshinePercentageField name="sunshinePercentage" maxlength="3" placeholder="075" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('sunshinePercentage')" (click)="toggleNoData(sunshinePercentageField, 'sunshinePercentage')">{{ isNoData('sunshinePercentage') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
        </div></section>

        <section class="panel" *ngIf="reportType === '24h'"><h2><i class="fa-solid fa-wind"></i> هبات الرياح</h2><div class="grid">
          <div class="daily-field"><label>أكبر نفحة للرياح (م/ثا)<input #maxGustSpeedField name="maxGustSpeed" maxlength="2" placeholder="15" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('maxGustSpeed')" (click)="toggleNoData(maxGustSpeedField, 'maxGustSpeed')">{{ isNoData('maxGustSpeed') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>اتجاه أكبر نفحة للرياح (درجة)<input #maxGustDirectionField name="maxGustDirection" maxlength="2" placeholder="25" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('maxGustDirection')" (click)="toggleNoData(maxGustDirectionField, 'maxGustDirection')">{{ isNoData('maxGustDirection') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>وقت حدوث أكبر نفحة (ساعة)<input #maxGustTimeField name="maxGustTime" maxlength="4" placeholder="14.5" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('maxGustTime')" (click)="toggleNoData(maxGustTimeField, 'maxGustTime')">{{ isNoData('maxGustTime') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
        </div></section>

        <section class="panel" *ngIf="reportType === '24h'"><h2><i class="fa-solid fa-droplet"></i> الرطوبة النسبية</h2><div class="grid">
          <div class="daily-field"><label>أكبر كمية رطوبة (%)<input #maxHumidityField name="maxHumidity" maxlength="3" placeholder="085" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('maxHumidity')" (click)="toggleNoData(maxHumidityField, 'maxHumidity')">{{ isNoData('maxHumidity') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>زمن حدوث أكبر رطوبة النسبة (ساعة)<input #maxHumidityTimeField name="maxHumidityTime" maxlength="4" placeholder="06.0" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('maxHumidityTime')" (click)="toggleNoData(maxHumidityTimeField, 'maxHumidityTime')">{{ isNoData('maxHumidityTime') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>أصغر كمية رطوبة (%)<input #minHumidityField name="minHumidity" maxlength="2" placeholder="35" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('minHumidity')" (click)="toggleNoData(minHumidityField, 'minHumidity')">{{ isNoData('minHumidity') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
          <div class="daily-field"><label>زمن حدوث أصغر رطوبة النسبة (ساعة)<input #minHumidityTimeField name="minHumidityTime" maxlength="4" placeholder="14.0" required (blur)="formatField($event)"></label><div class="field-actions"><button type="button" class="no-data-btn" [class.active]="isNoData('minHumidityTime')" (click)="toggleNoData(minHumidityTimeField, 'minHumidityTime')">{{ isNoData('minHumidityTime') ? 'إعادة إدخال البيانات' : 'لا تتوفر معلومات' }}</button></div></div>
        </div></section>

        <section class="panel" *ngIf="reportType === '24h'"><h2><i class="fa-solid fa-cloud-bolt"></i> الظواهر الجوية</h2>
          <div class="phenomena">@for (item of phenomena; track item.id) {<label><input type="checkbox" [name]="item.id" value="1">{{ item.label }}</label>}</div>
          <label class="notes-label">ملاحظات الراصد<textarea name="observerNotes" rows="3" placeholder="تفاصيل إضافية عن الظواهر والحالة الجوية..."></textarea></label>
        </section>
        <label class="agreement"><input type="checkbox" name="responsibilityAgreement" required> أقر بأنني قمت بإدخال جميع البيانات بدقة وأتحمل المسؤولية الكاملة عن صحة المعلومات المقدمة. كما أتعهد بأن أي خطأ في البيانات سيكون تحت مسؤوليتي الشخصية.</label>
        <div class="actions">
          <button class="secondary" type="button" (click)="saveDraft($event, dailyForm)"><i class="fa-solid fa-save"></i> حفظ مسودة</button>
          <button class="test" type="button" (click)="fillTestData(dailyForm)"><i class="fa-solid fa-vial"></i> إدخال بيانات تجريبية</button>
          <button class="info" type="button" (click)="previewData(dailyForm)"><i class="fa-solid fa-eye"></i> معاينة التقرير</button>
          <a class="whatsapp" *ngIf="whatsAppUrl" [href]="whatsAppUrl" target="_blank" rel="noopener"><i class="fa-brands fa-whatsapp"></i> مشاركة عبر واتساب</a>
          <button class="primary" type="submit" disabled title="يتطلب ربط API وقاعدة البيانات"><i class="fa-solid fa-paper-plane"></i> إرسال إلى قاعدة البيانات — غير متاح في المعاينة</button>
          <button class="secondary" type="reset" (click)="resetState(dailyForm)">مسح الحقول</button>
        </div>
      </form>

      <section class="panel preview-panel" *ngIf="reportPreview"><h2><i class="fa-solid fa-eye"></i> معاينة التقرير</h2><pre class="report-preview">{{reportPreview}}</pre></section>
      <div class="validation-box error-box" *ngIf="issues.length"><strong><i class="fa-solid fa-triangle-exclamation"></i> ملاحظات التحقق</strong><ul><li *ngFor="let issue of issues">{{ issue }}</li></ul></div>
      <div class="validation-box success-box" *ngIf="message" role="status"><i class="fa-solid fa-circle-check"></i> {{ message }}</div>

      <section class="panel preview-panel" *ngIf="previews.length"><h2><i class="fa-solid fa-inbox"></i> مسودات النشرات التجريبية</h2>
        <article class="preview-row" *ngFor="let item of previews"><div><strong>{{ item.reference }}</strong><p>{{ typeLabel(item.reportType) }} · {{ item.station }} · {{ item.date }}</p></div><span class="status" [class.submitted]="item.status === 'submitted'">{{ item.status === 'draft' ? 'مسودة' : 'بانتظار المراجعة' }}</span><button *ngIf="item.status === 'draft'" type="button" class="send-btn" (click)="sendForReview(item)">إرسال للمراجعة</button></article>
      </section>
      <p class="footnote">تمت مواءمة الحقول المطلوبة وأنماط الترميز مع نموذج daily.html وملف daily_validation.js الأصلي. لا تزال هذه المعاينة بحاجة إلى اختبار ميداني ومطابقة قاعدة البيانات قبل التشغيل الفعلي.</p>
    </div>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}.page-head{display:flex;align-items:center;gap:18px;background:linear-gradient(135deg,#3498db,#2471a3);color:#fff;padding:24px 28px;border-radius:16px;margin-bottom:18px;box-shadow:0 8px 24px #3498db30}.head-icon{width:62px;height:62px;border-radius:15px;background:#ffffff25;display:grid;place-items:center;font-size:30px}.page-head h1{margin:0 0 5px;font-size:27px}.page-head p{margin:0;opacity:.9}.preview-tag{margin-right:auto;background:#fff3cd;color:#856404;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700;white-space:nowrap}.demo-warning{display:flex;gap:12px;align-items:flex-start;padding:13px 16px;margin-bottom:18px;border-radius:9px;background:#eaf4fb;border-right:4px solid #3498db;color:#245575}.demo-warning>i{font-size:19px}.demo-warning div{display:grid;gap:4px}.demo-warning span{font-size:12px}.type-panel{background:#fff;border:1px solid #e5eaee;border-radius:12px;padding:17px 20px;margin-bottom:18px}.type-options{display:flex;flex-wrap:wrap;gap:18px;margin:12px 0}.type-options label{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:700}.type-panel p{color:#2980b9;font-size:12px}.panel{background:#fff;border:1px solid #e5eaee;border-radius:14px;padding:22px;margin-bottom:18px;box-shadow:0 5px 18px #2638490a}.panel h2{font-size:18px;margin:0 0 20px;padding-bottom:12px;border-bottom:2px solid #edf1f4;color:#34495e}.panel h2 i{color:#3498db;margin-left:9px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.daily-field{display:flex;flex-direction:column;gap:7px;min-width:0}.daily-field>label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.field-actions{display:flex;gap:7px;flex-wrap:wrap}.no-data-btn,.sign-toggle{border:1px solid #c8dce8;border-radius:7px;background:#f3f8fb;color:#28658a;padding:6px 10px;font:inherit;font-size:11px;cursor:pointer}.no-data-btn.active{background:#e8f5ec;border-color:#8ac79d;color:#267443}.sign-toggle{min-width:42px;font-weight:800}.grid label,.notes-label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.grid input,.notes-label textarea{width:100%;box-sizing:border-box;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;background:#fbfcfd;color:#2c3e50;font:inherit;font-weight:400;outline:none}.grid input:focus,.notes-label textarea:focus{border-color:#3498db;box-shadow:0 0 0 3px #3498db20}.grid small{font-size:10px;color:#84919a;font-weight:400}.phenomena{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:20px}.phenomena label{display:flex;align-items:center;gap:8px;background:#f7f9fb;padding:11px;border-radius:8px;font-size:13px}.agreement{display:flex;align-items:center;gap:9px;background:#f4f8fb;padding:14px 16px;border-radius:9px;margin:15px 0;font-size:13px}.actions{display:flex;gap:10px;flex-wrap:wrap}.actions .test,.actions .info,.actions .whatsapp{border:0;border-radius:9px;padding:12px 20px;font:inherit;font-weight:700;cursor:pointer;text-decoration:none;display:inline-flex;align-items:center;gap:7px}.actions .test{background:#fff3cd;color:#856404}.actions .info{background:#d9edf7;color:#245575}.actions .whatsapp{background:#25d366;color:#fff}.report-preview{white-space:pre-wrap;direction:rtl;text-align:right;background:#f7f9fb;border:1px solid #e5eaee;border-radius:8px;padding:14px;font:13px/1.8 inherit;max-height:420px;overflow:auto}.actions button,.send-btn{border:0;border-radius:9px;padding:12px 20px;font:inherit;font-weight:700;cursor:pointer}.primary,.send-btn{background:#2980b9;color:#fff}.secondary{background:#ecf0f1;color:#34495e}.validation-box{margin-top:16px;padding:14px 16px;border-radius:9px;font-size:13px}.error-box{background:#fff0ef;border-right:4px solid #dc3545;color:#9d2929}.error-box ul{margin:8px 0 0;padding-right:20px}.success-box{background:#eaf7ef;border-right:4px solid #27ae60;color:#218348}.preview-row{display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #edf0f2}.preview-row>div{flex:1}.preview-row p{margin:5px 0 0;color:#84919a;font-size:12px}.status{padding:5px 10px;border-radius:20px;background:#edf0f2;color:#59636b;font-size:11px}.status.submitted{background:#fff3cd;color:#946200}.footnote{font-size:12px;color:#8a969e;margin-top:18px}@media(max-width:850px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.phenomena{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid,.phenomena{grid-template-columns:1fr}.page-head{padding:18px;flex-wrap:wrap}.page-head h1{font-size:22px}.head-icon{width:50px;height:50px}.panel{padding:16px}.actions{flex-direction:column}.preview-row{align-items:flex-start;flex-wrap:wrap}}
  `]
})
export class DailyReportsComponent {
  readonly today = new Date().toISOString().slice(0,10);
  readonly phenomena = [
    {id:'thunderstorm',label:'عواصف رعدية'},{id:'hail',label:'برد'},{id:'snow',label:'ثلوج'},
    {id:'rain',label:'أمطار'},{id:'frost',label:'صقيع'},{id:'fog',label:'ضباب'},
    {id:'mist',label:'شابورة'},{id:'dustStorm',label:'عواصف ترابية أو رملية'},
    {id:'blowingDust',label:'غبار متصاعد'},{id:'haze',label:'سديم'},{id:'stormyWind',label:'رياح عاصفة'}
  ];
  reportType = '24h';
  issues: string[] = [];
  message = '';
  previews: DailyPreview[] = [];
  private nextReference = 1;
  reportPreview = '';
  whatsAppUrl = '';

  get typeDescription(): string {
    if (this.reportType === '06utc') return 'نشرة الساعة 06:00 UTC؛ تُطلب الحرارة والهطول والثلوج فقط من حقول الملخص.';
    if (this.reportType === '18utc') return 'نشرة الساعة 18:00 UTC؛ تُطلب الحرارة والهطول والثلوج فقط من حقول الملخص.';
    return 'ملخص 24 ساعة؛ جميع عناصر الحرارة والهطول والتبخر والسطوع والرياح والرطوبة مطلوبة.';
  }

  setType(value: string): void { this.reportType = value; this.issues = []; this.message = ''; }
  private noDataFields = new Set<string>();
  isNoData(key: string): boolean { return this.noDataFields.has(key); }
  toggleNoData(field: HTMLInputElement, key: string): void {
    if (this.noDataFields.has(key)) {
      this.noDataFields.delete(key);
      const pattern = field.getAttribute('data-original-pattern');
      if (pattern !== null) field.setAttribute('pattern', pattern);
      field.required = field.getAttribute('data-original-required') === 'true';
      field.value = '';
      field.removeAttribute('data-original-pattern');
      field.removeAttribute('data-original-required');
    } else {
      const pattern = field.getAttribute('pattern');
      if (pattern !== null) { field.setAttribute('data-original-pattern', pattern); field.removeAttribute('pattern'); }
      field.setAttribute('data-original-required', String(field.required));
      field.value = '#';
      field.required = true;
      this.noDataFields.add(key);
    }
  }
  toggleTemperatureSign(field: HTMLInputElement): void {
    if (!field || !field.value || field.value === '#') return;
    field.value = field.value.startsWith('-') ? field.value.slice(1) : '-' + field.value;
  }

  typeLabel(value: string): string { return value === '24h' ? 'ملخص 24 ساعة' : value === '06utc' ? 'رصد 06 UTC' : 'رصد 18 UTC'; }
  resetState(form?: HTMLFormElement): void {
    this.issues = []; this.message = ''; this.noDataFields.clear(); this.clearPreview();
    form?.querySelectorAll<HTMLInputElement>('[data-original-pattern], [data-original-required]').forEach(field => {
      const pattern = field.getAttribute('data-original-pattern');
      if (pattern !== null) field.setAttribute('pattern', pattern);
      const required = field.getAttribute('data-original-required');
      if (required !== null) field.required = required === 'true';
      field.removeAttribute('data-original-pattern');
      field.removeAttribute('data-original-required');
    });
  }

  formatField(event: FocusEvent): void {
    const field = event.target as HTMLInputElement;
    if (!field || !field.value.trim() || field.value.trim() === '#') return;
    const value = field.value.trim();
    const digits = (s: string) => s.replace(/\D/g, '');
    const decimal = (s: string, width: number) => {
      const n = Number(s.replace(/[^\d.]/g, ''));
      if (!Number.isFinite(n)) return value;
      const bounded = Math.max(0, n);
      return String(Math.floor(bounded)).padStart(width, '0') + '.' + bounded.toFixed(1).split('.')[1];
    };
    switch (field.name) {
      case 'minTemp': case 'maxTemp': {
        const negative = value.startsWith('-');
        const n = Math.min(50, Math.abs(Number(value.replace(/[^\d.]/g, ''))));
        if (Number.isFinite(n)) field.value = (negative ? '-' : '') + String(Math.floor(n)).padStart(2,'0') + '.' + n.toFixed(1).split('.')[1];
        break;
      }
      case 'precipitation': field.value = decimal(value,3); break;
      case 'evaporation': case 'sunshineDuration': case 'maxGustTime': case 'maxHumidityTime': case 'minHumidityTime': field.value = decimal(value,2); break;
      case 'snowThickness': field.value = digits(value).slice(0,3).padStart(3,'0'); break;
      case 'sunshinePercentage': case 'maxHumidity': field.value = digits(value).slice(0,3).padStart(3,'0'); break;
      case 'maxGustSpeed': case 'maxGustDirection': case 'minHumidity': field.value = digits(value).slice(0,2).padStart(2,'0'); break;
      case 'precipitationTrace': field.value = value.toUpperCase() === 'T' ? 'T' : value; break;
    }
  }

  submit(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    this.issues = [];
    this.message = '';
    if (!form.reportValidity()) return;
    const fd = new FormData(form);
    const values: Record<string,string> = {};
    fd.forEach((v,k) => { if (typeof v === 'string') values[k] = v.trim(); });

    const required = this.reportType === '24h'
      ? ['minTemp','maxTemp','precipitation','snowThickness','evaporation','sunshineDuration','sunshinePercentage','maxGustSpeed','maxGustDirection','maxGustTime','maxHumidity','maxHumidityTime','minHumidity','minHumidityTime']
      : ['minTemp','maxTemp','precipitation','snowThickness'];
    for (const key of required) if (!values[key]) this.issues.push(this.label(key) + ': هذا الحقل مطلوب لهذا النوع من التقرير.');

    const rules: Record<string,{pattern:RegExp,min:number,max:number,label:string}> = {
      minTemp:{pattern:/^-?\d{2}\.\d$/,min:-20,max:50,label:'الحرارة الصغرى'},
      maxTemp:{pattern:/^-?\d{2}\.\d$/,min:-20,max:50,label:'الحرارة العظمى'},
      precipitation:{pattern:/^\d{3}\.\d$/,min:0,max:999.9,label:'الهطول'},
      snowThickness:{pattern:/^\d{3}$/,min:0,max:999,label:'سماكة الثلج'},
      evaporation:{pattern:/^\d{2}\.\d$/,min:0,max:99.9,label:'التبخر'},
      sunshineDuration:{pattern:/^\d{2}\.\d$/,min:0,max:24,label:'مدة سطوع الشمس'},
      sunshinePercentage:{pattern:/^\d{3}$/,min:0,max:100,label:'نسبة سطوع الشمس'},
      maxGustSpeed:{pattern:/^\d{2}$/,min:0,max:36,label:'سرعة هبات الرياح'},
      maxGustDirection:{pattern:/^\d{2}$/,min:0,max:36,label:'اتجاه هبات الرياح'},
      maxGustTime:{pattern:/^\d{2}\.\d$/,min:0,max:23.9,label:'وقت الهبات القصوى'},
      maxHumidity:{pattern:/^\d{3}$/,min:0,max:100,label:'الرطوبة العظمى'},
      minHumidity:{pattern:/^\d{2}$/,min:0,max:99,label:'الرطوبة الصغرى'},
      maxHumidityTime:{pattern:/^\d{2}\.\d$/,min:0,max:23.9,label:'وقت الرطوبة العظمى'},
      minHumidityTime:{pattern:/^\d{2}\.\d$/,min:0,max:23.9,label:'وقت الرطوبة الصغرى'}
    };
    for (const [key,rule] of Object.entries(rules)) {
      const v = values[key] ?? '';
      if (!v || v === '#') continue;
      const n = Number(v);
      if (!rule.pattern.test(v) || !Number.isFinite(n) || n < rule.min || n > rule.max)
        this.issues.push(rule.label + ': التنسيق أو القيمة خارج المجال المقبول.');
    }
    if (values['precipitationTrace'] && values['precipitationTrace'] !== '#' && !/^[Tt]$/.test(values['precipitationTrace']))
      this.issues.push('أثر الهطول: أدخل T فقط أو اترك الحقل فارغاً.');
    if (values['minTemp'] && values['maxTemp'] && values['minTemp'] !== '#' && values['maxTemp'] !== '#' && Number(values['maxTemp']) < Number(values['minTemp']))
      this.issues.push('درجة الحرارة العظمى يجب أن تكون أكبر من أو تساوي درجة الحرارة الصغرى.');
    if (values['maxHumidity'] && values['minHumidity'] && values['maxHumidity'] !== '#' && values['minHumidity'] !== '#' && Number(values['minHumidity']) > Number(values['maxHumidity']))
      this.issues.push('الرطوبة الصغرى لا يمكن أن تتجاوز الرطوبة العظمى.');
    if (this.issues.length) return;

    const reference = 'D-' + String(this.nextReference++).padStart(4,'0');
    this.previews.unshift({reference,date:values['currentDate'] ?? this.today,reportType:this.reportType,station:values['station'] ?? '',status:'draft',values});
    this.message = 'اجتازت النشرة فحوص المعاينة وأُنشئت كمسودة مؤقتة داخل هذه الصفحة فقط.';
    this.resetState(form); form.reset();
  }

  private readForm(form: HTMLFormElement): Record<string,string> {
    const values: Record<string,string> = {};
    new FormData(form).forEach((value,key) => { if (typeof value === 'string') values[key] = value.trim(); });
    return values;
  }
  private buildReportText(values: Record<string,string>): string {
    const labels: Record<string,string> = {currentDate:'التاريخ',station:'المحطة',observer:'اسم الراصد',minTemp:'القيمة الصغرى في النهايات (سْ)',maxTemp:'القيمة العظمى في النهايات (سْ)',precipitation:'كمية الهطول لأقرب مم',snowThickness:'أكبر سماكة ثلج لأقرب سم',precipitationTrace:'الأثر (T)',evaporation:'مجموع التبخر اليومي لأقرب عشر مم',sunshineDuration:'مجموع مدة سطوع الشمس الحقيقي',sunshinePercentage:'النسبة المئوية لسطوع الشمس',maxGustSpeed:'أكبر نفحة للرياح (م/ثا)',maxGustDirection:'اتجاه أكبر نفحة للرياح (درجة)',maxGustTime:'وقت حدوث أكبر نفحة (ساعة)',maxHumidity:'أكبر كمية رطوبة (%)',maxHumidityTime:'زمن حدوث أكبر رطوبة النسبة (ساعة)',minHumidity:'أصغر كمية رطوبة (%)',minHumidityTime:'زمن حدوث أصغر رطوبة النسبة (ساعة)',observerNotes:'ملاحظات الراصد'};
    const lines=['النشرات اليومية - '+this.typeLabel(this.reportType)];
    for (const [key,label] of Object.entries(labels)) if(values[key]) lines.push(label+': '+values[key]);
    return lines.join('\n');
  }
  saveDraft(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    const previousCount = this.previews.length;
    this.submit(event, form);
    if (this.previews.length > previousCount && this.previews[0]?.status === 'draft') {
      this.message = 'تم حفظ المسودة في ذاكرة الصفحة الحالية فقط؛ لا تُحفظ بعد إغلاق الصفحة.';
    }
  }
  fillTestData(form: HTMLFormElement): void {
    const sample: Record<string,string>={minTemp:'-05.3',maxTemp:'25.7',precipitation:'012.5',snowThickness:'015',precipitationTrace:'T',evaporation:'12.5',sunshineDuration:'08.5',sunshinePercentage:'075',maxGustSpeed:'15',maxGustDirection:'25',maxGustTime:'14.5',maxHumidity:'085',maxHumidityTime:'06.0',minHumidity:'35',minHumidityTime:'14.0',observerNotes:'بيانات تجريبية لأغراض الاختبار'};
    for(const [name,value] of Object.entries(sample)){const field=form.elements.namedItem(name) as HTMLInputElement|HTMLTextAreaElement|null;if(field)field.value=value;}
    for(const name of ['rain','fog','stormyWind']){const field=form.elements.namedItem(name) as HTMLInputElement|null;if(field)field.checked=true;}
    const agreement=form.elements.namedItem('responsibilityAgreement') as HTMLInputElement|null;if(agreement)agreement.checked=true;
    this.noDataFields.clear();this.message='تمت تعبئة بيانات تجريبية؛ راجعها قبل الحفظ أو المعاينة.';
  }
  previewData(form: HTMLFormElement): void {
    if(!form.reportValidity()) return;
    const values=this.readForm(form);this.reportPreview=this.buildReportText(values);
    this.whatsAppUrl='https://wa.me/?text='+encodeURIComponent(this.reportPreview);
    this.message='هذه معاينة للنص فقط؛ لم يتم إرسال التقرير أو حفظه.';
  }
  private clearPreview(): void { this.reportPreview='';this.whatsAppUrl=''; }
    sendForReview(item: DailyPreview): void { item.status = 'submitted'; this.message = 'تم إرسال ' + item.reference + ' للمراجعة في المعاينة فقط.'; }

  private label(key: string): string {
    const labels: Record<string,string> = {minTemp:'الحرارة الصغرى',maxTemp:'الحرارة العظمى',precipitation:'الهطول',snowThickness:'سماكة الثلوج',evaporation:'التبخر',sunshineDuration:'مدة سطوع الشمس',sunshinePercentage:'نسبة سطوع الشمس',maxGustSpeed:'سرعة هبات الرياح',maxGustDirection:'اتجاه الهبات',maxGustTime:'وقت الهبات القصوى',maxHumidity:'الرطوبة العظمى',maxHumidityTime:'وقت الرطوبة العظمى',minHumidity:'الرطوبة الصغرى',minHumidityTime:'وقت الرطوبة الصغرى'};
    return labels[key] ?? key;
  }
}