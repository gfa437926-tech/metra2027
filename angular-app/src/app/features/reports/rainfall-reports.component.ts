import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

@Component({
  standalone: true,
  selector: 'metra-rainfall-reports',
  imports: [CommonModule],
  template: `
    <div class="rain-page" dir="rtl">
      <header class="page-head">
        <div><h1>النشرة المطرية اليومية</h1><p>تسجيل بيانات الهطول المطري والثلوج اليومية</p></div>
        <span class="mode">وضع المعاينة</span>
      </header>

      <form #rainForm (submit)="preview($event, rainForm)" novalidate>
      <section class="panel">
        <h2>معلومات الراصد</h2>
        <p class="notice">بيانات اسم الراصد والمحطة والصفة الوظيفية غير متصلة حالياً بمصدر هوية معتمد؛ لن نعرض قيماً افتراضية على أنها بيانات حقيقية.</p>
        <div class="fields">
          <label class="field">تاريخ الإرسال
            <input type="text" [value]="currentDate" readonly>
          </label>
          <label class="field">وقت النشرة (توقيت سورية)
            <input name="localTime" type="time" [value]="localTime" (change)="updateLocalTime($any($event.target).value)" min="08:30" max="09:30" step="300" required>
            <small>النشرة ترسل بين الساعة 08:30 و 09:30 صباحاً (توقيت سورية)</small>
          </label>
          <label class="field">الوقت العالمي (UTC)
            <input type="text" [value]="utcTime" readonly>
            <small>التوقيت العالمي المكافئ: {{ utcTime }}</small>
          </label>
        </div>
      </section>

        <section class="panel">
          <h2>بيانات الهطول المطري</h2>
          <div class="fields two">
            <label class="field important">كمية الهطول المطري (مم)
              <input name="rainAmount" type="text" [value]="rainAmount" placeholder="أدخل ###.# أو # لعدم توفر البيانات"
                maxlength="5" (focus)="clearNoData('rain')" (input)="rainAmount=$any($event.target).value; clearError($any($event.target))"
                (blur)="formatRainAmount($any($event.target))">
              <small>تنسيق الإدخال: ###.# (3 خانات صحيحة + فاصلة + خانة عشرية واحدة)</small>
              <small>المدى: من 000.0 إلى 999.9 مليمتر</small>
              <small>ملاحظة: استخدم # إذا لم تكن البيانات متوفرة</small>
            </label>
            <label class="field important">سماكة الثلوج (سم)
              <input name="snowDepth" type="text" [value]="snowDepth" placeholder="أدخل ### أو # لعدم توفر البيانات"
                maxlength="3" (focus)="clearNoData('snow')" (input)="snowDepth=$any($event.target).value; clearError($any($event.target))"
                (blur)="formatSnowDepth($any($event.target))">
              <small>تنسيق الإدخال: ### (3 خانات صحيحة فقط)</small>
              <small>المدى: من 000 إلى 999 سنتيمتر</small>
              <small>ملاحظة: استخدم # إذا لم تكن البيانات متوفرة</small>
            </label>
          </div>
          <label class="field date-field">تاريخ الرصد
            <input name="observationDate" type="date" [value]="observationDate" [min]="minDate" [max]="currentDate"
              (change)="observationDate=$any($event.target).value" required>
          </label>
        </section>

        <section class="panel">
          <h2>المسؤولية</h2>
          <label class="agreement">
            <input name="responsibilityAgreement" type="checkbox" [checked]="responsibilityAccepted"
              (change)="responsibilityAccepted=$any($event.target).checked" required>
            أقر بأن هذه النشرة ترسل بين الساعة 8:30 و 9:30 صباحاً وأتحمل المسؤولية الكاملة عن صحة المعلومات المقدمة.
          </label>
        </section>

        <div class="actions">
          <button type="button" class="test" (click)="fillTestData()">إدخال بيانات تجريبية</button>
          <button type="submit" class="preview">معاينة التقرير</button>
          <button type="button" class="disabled" disabled title="يتطلب ربط API وقاعدة البيانات">إرسال النشرة — غير متاح في المعاينة</button>
          <button type="button" class="disabled" disabled title="تُتاح المشاركة بعد اعتماد التقرير وربط الخدمة">مشاركة عبر واتساب — غير متاحة في المعاينة</button>
        </div>
      </form>

      <section class="panel result" *ngIf="previewText">
        <h2>معاينة النشرة</h2><pre>{{ previewText }}</pre>
      </section>
    </div>
  `,
  styles: [`
    .rain-page{max-width:1200px;margin:0 auto;color:#2c3e50}
    .page-head{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:24px 28px;background:linear-gradient(135deg,#3498db,#2c3e50);color:#fff;border-radius:15px 15px 0 0}
    h1{font-size:1.65rem;margin:0} .page-head p{margin:7px 0 0;opacity:.9}.mode{background:#fff3cd;color:#856404;padding:7px 12px;border-radius:8px;white-space:nowrap}
    .panel{background:rgba(255,255,255,.96);border:1px solid #e5e9ec;border-right:5px solid #3498db;border-radius:12px;padding:22px;margin:16px 0;box-shadow:0 6px 15px rgba(0,0,0,.08)}
    h2{font-size:1.2rem;color:#2c3e50;margin:0 0 18px;padding-bottom:10px;border-bottom:2px solid #ecf0f1}
    .notice{padding:12px 15px;background:#fff8e9;border-right:4px solid #f39c12;border-radius:8px;line-height:1.8}
    .fields{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:17px}.fields.two{grid-template-columns:repeat(2,minmax(0,1fr))}
    .field{display:flex;flex-direction:column;gap:8px;font-weight:600;min-width:0}.field input{width:100%;box-sizing:border-box;border:1px solid #d5dde2;border-radius:8px;padding:11px;background:#fff;font:inherit;color:#2c3e50}
    .field input:focus{outline:2px solid #3498db40;border-color:#3498db}.field small{font-size:.82rem;color:#687780;font-weight:400;line-height:1.5}
    .important input{direction:ltr;text-align:left;font-family:Consolas,monospace}.date-field{margin-top:18px;max-width:450px}
    .agreement{display:flex;gap:11px;align-items:flex-start;line-height:1.9}.actions{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}
    .actions button{border:0;border-radius:8px;padding:11px 16px;color:white;font:inherit;font-weight:600}.test{background:#f39c12}.preview{background:#2980b9}.disabled{background:#858e94;cursor:not-allowed}
    .result pre{white-space:pre-wrap;line-height:1.9;font:inherit}
    @media(max-width:800px){.fields,.fields.two{grid-template-columns:1fr}.rain-page{padding:0 3px}.page-head{align-items:flex-start;flex-direction:column}.mode{white-space:normal}}
  `]
})
export class RainfallReportsComponent {
  readonly currentDate = this.toDate(new Date());
  readonly minDate = this.toDate(new Date(Date.now() - 24 * 60 * 60 * 1000));
  observationDate = this.currentDate;
  localTime = '09:00';
  utcTime = '06:00';
  rainAmount = '#';
  snowDepth = '#';
  responsibilityAccepted = false;
  previewText = '';

  private toDate(date: Date): string {
    return date.toISOString().split('T')[0];
  }

  updateLocalTime(value: string): void {
    this.localTime = value;
    if (!value) { this.utcTime = ''; return; }
    const [hours, minutes] = value.split(':').map(Number);
    this.utcTime = `${String((hours + 21) % 24).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }

  clearNoData(field: 'rain' | 'snow'): void {
    if (field === 'rain' && this.rainAmount === '#') this.rainAmount = '';
    if (field === 'snow' && this.snowDepth === '#') this.snowDepth = '';
  }

  clearError(input: HTMLInputElement): void {
    input.setCustomValidity('');
  }

  formatRainAmount(input: HTMLInputElement): void {
    const value = input.value.trim();
    if (!value || value === '#') { this.rainAmount = '#'; input.value = '#'; return; }
    const cleaned = value.replace(/[^0-9.]/g, '');
    if (!/^\d{1,3}(\.\d)?$/.test(cleaned)) return;
    const [whole, decimal] = cleaned.split('.');
    this.rainAmount = `${whole.padStart(3, '0')}.${decimal ? decimal.charAt(0) : '0'}`;
    input.value = this.rainAmount;
    input.setCustomValidity('');
  }

  formatSnowDepth(input: HTMLInputElement): void {
    const value = input.value.trim();
    if (!value || value === '#') { this.snowDepth = '#'; input.value = '#'; return; }
    const cleaned = value.replace(/[^0-9]/g, '');
    if (!/^\d{1,3}$/.test(cleaned)) return;
    this.snowDepth = cleaned.padStart(3, '0');
    input.value = this.snowDepth;
    input.setCustomValidity('');
  }

  fillTestData(): void {
    this.rainAmount = '012.4';
    this.snowDepth = '015';
    this.observationDate = this.currentDate;
    this.updateLocalTime('09:00');
    this.responsibilityAccepted = true;
    this.previewText = '';
  }

  preview(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    const rain = form.elements.namedItem('rainAmount') as HTMLInputElement;
    const snow = form.elements.namedItem('snowDepth') as HTMLInputElement;
    const date = form.elements.namedItem('observationDate') as HTMLInputElement;
    const time = form.querySelector('input[type="time"]') as HTMLInputElement | null;
    const agreement = form.elements.namedItem('responsibilityAgreement') as HTMLInputElement;

    const rainValue = rain.value.trim();
    const snowValue = snow.value.trim();
    const rainValid = rainValue === '#' || (/^\d{3}\.\d$/.test(rainValue) && Number(rainValue) >= 0 && Number(rainValue) <= 999.9);
    const snowValid = snowValue === '#' || (/^\d{3}$/.test(snowValue) && Number(snowValue) >= 0 && Number(snowValue) <= 999);
    rain.setCustomValidity(rainValid ? '' : 'يرجى إدخال كمية الهطول بالتنسيق ###.# (0 - 999.9 ملم) أو #');
    snow.setCustomValidity(snowValid ? '' : 'يرجى إدخال سماكة الثلوج بالتنسيق ### (0 - 999 سم) أو #');

    const [hours, minutes] = this.localTime.split(':').map(Number);
    const totalMinutes = hours * 60 + minutes;
    const timeValid = !!this.localTime && totalMinutes >= 510 && totalMinutes <= 570;
    const dateValid = !!date.value && date.value >= this.minDate && date.value <= this.currentDate;
    date.setCustomValidity(dateValid ? '' : 'يرجى تحديد تاريخ الرصد خلال اليوم أو اليوم السابق');
    if (time) time.setCustomValidity(timeValid ? '' : 'وقت النشرة يجب أن يكون بين 08:30 و 09:30 صباحاً');
    agreement.setCustomValidity(agreement.checked ? '' : 'يجب الموافقة على بيان المسؤولية');

    if (!form.reportValidity()) return;
    const values = [
      'النشرة المطرية اليومية',
      `تاريخ الإرسال: ${this.currentDate}`,
      `وقت النشرة (توقيت سورية): ${this.localTime}`,
      `الوقت العالمي (UTC): ${this.utcTime}`,
      `كمية الهطول المطري (مم): ${rainValue}`,
      `سماكة الثلوج (سم): ${snowValue}`,
      `تاريخ الرصد: ${date.value}`,
      'تأكيد المسؤولية: تم التأكيد'
    ];
    this.previewText = values.join('\n');
    this.rainAmount = rainValue;
    this.snowDepth = snowValue;
    this.observationDate = date.value;
  }
}
