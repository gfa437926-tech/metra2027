import { CommonModule } from '@angular/common';
import { AfterViewInit, Component, ElementRef, ViewChild } from '@angular/core';

interface AgricultureField {
  id: string;
  label: string;
  placeholder: string;
  pattern: string;
  maxLength: number;
  required?: boolean;
  min?: number;
  max?: number;
  temperature?: boolean;
  title?: string;
}

@Component({
  standalone: true,
  selector: 'metra-agriculture',
  imports: [CommonModule],
  template: `
    <div class="agri-page" dir="rtl">
      <header class="page-head">
        <div><h1>النشرات الزراعية الشهرية</h1><p>إدخال البيانات الزراعية الشهرية وتتبع التغيرات</p></div>
        <span class="mode">وضع المعاينة</span>
      </header>
      <div class="notice"><strong>نسخة معاينة:</strong> التحقق والمعاينة يعملان داخل الصفحة. لا يوجد اتصال فعلي بقاعدة البيانات أو API، ولا يتم حفظ التقارير بشكل دائم.</div>

      <form #agriForm (submit)="preview($event, agriForm)" novalidate>
        <section class="panel">
          <h2>التعريف بالمحطة والراصد</h2>
          <div class="identity-note">
            <strong>تاريخ اليوم:</strong> {{ today }}
            <p>بيانات اسم الراصد والمحطة والصفة الوظيفية غير متاحة في وضع المعاينة؛ لن تُعرض بيانات افتراضية على أنها بيانات حقيقية.</p>
          </div>
          <div class="stats-note">
            <strong>إحصائيات تقارير المحطة اليوم</strong>
            <span>غير متاحة في المعاينة — تتطلب ربط قاعدة البيانات ومصدر الإحصائيات الأصلي.</span>
          </div>
          <div class="fields one">
            <label class="field">تاريخ التقرير
              <input name="reportDate" type="date" [value]="today" [min]="minDate" [max]="today" required>
            </label>
          </div>
        </section>

        <section class="panel" *ngFor="let section of sections">
          <h2>{{ section.title }}</h2>
          <div class="fields">
            <label class="field" *ngFor="let field of section.fields">
              {{ field.label }}
              <input #fieldInput [id]="field.id" [name]="field.id" type="text"
                [placeholder]="field.placeholder" [attr.maxlength]="field.maxLength"
                [attr.pattern]="field.pattern" [required]="!!field.required"
                [attr.inputmode]="'numeric'" [title]="field.title || field.label"
                (blur)="field.temperature ? formatTemperature(fieldInput) : null; validateField(fieldInput, field)"
                (input)="clearFieldError(fieldInput)">
              <span class="signs" *ngIf="field.temperature">
                <button type="button" (click)="setSign(fieldInput, '-')">-</button>
                <button type="button" (click)="setSign(fieldInput, '+')">+</button>
              </span>
              <small class="error" [id]="field.id + 'Error'"></small>
            </label>
          </div>
        </section>

        <section class="panel">
          <h2>الظواهر الجوية</h2>
          <div class="fields">
            <label class="field" *ngFor="let item of phenomena">
              {{ item.label }}
              <select [id]="item.id" [name]="item.id" required>
                <option value="" selected disabled>اختر</option>
                <option value="0">لا</option>
                <option value="1">نعم</option>
              </select>
            </label>
          </div>
        </section>

        <section class="panel">
          <h2>ملاحظات الراصد</h2>
          <label class="field">ملاحظات الراصد
            <textarea name="observerNotes" rows="3" placeholder="أدخل أي ملاحظات إضافية حول الظروف الجوية أو ملاحظات الرصد..."></textarea>
          </label>
        </section>

        <section class="panel">
          <h2>المسؤولية</h2>
          <label class="agreement">
            <input type="checkbox" name="responsibilityAgreement" required>
            أقر بأنني قمت بإدخال جميع البيانات بدقة وأتحمل المسؤولية الكاملة عن صحة المعلومات المقدمة. كما أتعهد بأن أي خطأ في البيانات سيكون تحت مسؤوليتي الشخصية.
          </label>
        </section>

        <div class="actions">
          <button type="button" class="draft" (click)="saveDraft(agriForm)">حفظ المسودة</button>
          <button type="button" class="test" (click)="fillTestData(agriForm)">إدخال بيانات تجريبية</button>
          <button type="submit" class="preview-btn">معاينة التقرير</button>
          <button type="button" class="submit" disabled title="يتطلب ربط API وقاعدة البيانات">إرسال التقرير — غير متاح في المعاينة</button>
          <button type="button" class="submit" disabled title="تتطلب المشاركة اعتماد التقرير وربط بيانات الراصد">مشاركة عبر واتساب — غير متاحة في المعاينة</button>
        </div>
        <p class="draft-status" *ngIf="draftStatus">{{ draftStatus }}</p>
      </form>

      <section class="panel" *ngIf="previewText">
        <h2>معاينة التقرير</h2>
        <pre>{{ previewText }}</pre>
      </section>
    </div>
  `,
  styles: [`
    .agri-page{max-width:1200px;margin:0 auto;padding:20px;color:#263746}
    .page-head{display:flex;justify-content:space-between;align-items:center;gap:16px;padding:22px 26px;background:linear-gradient(135deg,#27ae60 0%,#2c3e50 100%);color:#fff;border-radius:15px 15px 0 0}
    h1{margin:0;font-size:1.6rem}.page-head p{margin:7px 0 0;color:#e1eaf0}.mode{background:#fff;color:#123b52;border-radius:20px;padding:7px 13px;white-space:nowrap}
    .notice{margin:16px 0;padding:13px 16px;border-right:4px solid #b8860b;background:#fff8e9;border-radius:8px;line-height:1.8}
    .identity-note,.stats-note{padding:13px 15px;margin:12px 0;border-radius:8px;background:#f1f5f8;line-height:1.8}
    .stats-note{display:flex;flex-direction:column;gap:4px;background:#eaf1f5;color:#123b52}
    .stats-note span{font-size:.92rem;color:#536875}
    .draft-status{padding:10px 14px;border-right:3px solid #8b6a28;background:#fff8e9;border-radius:6px}
    .panel{background:rgba(255,255,255,.96);border:1px solid #e0e0e0;border-right:5px solid #27ae60;border-radius:12px;padding:22px;margin:16px 0;box-shadow:0 6px 15px rgba(0,0,0,.1);transition:all .3s ease}
    h2{font-size:1.2rem;color:#2c3e50;border-bottom:2px solid #ecf0f1;padding-bottom:10px;margin:0 0 18px}
    .fields{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:17px}.fields.one{grid-template-columns:minmax(220px,1fr);max-width:420px}
    .field{display:flex;flex-direction:column;gap:7px;font-weight:600;min-width:0}
    input[type=text],input[type=date],select,textarea{box-sizing:border-box;width:100%;padding:10px 11px;border:1px solid #bdcbd4;border-radius:7px;background:#fff;color:#263746;font:inherit}
    input:focus,select:focus,textarea:focus{outline:2px solid #27ae6040;border-color:#27ae60}
    .signs{display:flex;gap:7px}.signs button{border:1px solid #c7d3db;background:#eef3f6;color:#123b52;border-radius:6px;padding:5px 13px;cursor:pointer}
    .error{color:#b42318;min-height:0;font-weight:400}.agreement{display:flex;align-items:flex-start;gap:10px;line-height:1.9}
    .actions{display:flex;gap:10px;flex-wrap:wrap;margin:18px 0}.actions button{border:0;border-radius:7px;padding:11px 16px;color:white;cursor:pointer;font:inherit}
    .draft{background:#647987}.test{background:#8b6a28}.preview-btn{background:#123b52}.submit{background:#777;cursor:not-allowed!important}
    pre{white-space:pre-wrap;font:inherit;line-height:1.9}
    @media(max-width:850px){.fields{grid-template-columns:repeat(2,minmax(0,1fr))}}
    @media(max-width:580px){.agri-page{padding:11px}.page-head{align-items:flex-start;flex-direction:column}.fields,.fields.one{grid-template-columns:1fr}}
  `]
})
export class AgricultureComponent implements AfterViewInit {
  @ViewChild('agriForm') private formRef!: ElementRef<HTMLFormElement>;
  previewText = '';
  draftStatus = '';
  readonly today = this.toDateInput(new Date());
  readonly minDate = this.toDateInput(new Date(new Date().setFullYear(new Date().getFullYear() - 1)));

  readonly sections: { title: string; fields: AgricultureField[] }[] = [
    { title: 'درجات الحرارة', fields: [
      this.temp('avgAirTemp','معدل درجة الحرارة الهواء (سْ)','+25.5 أو -05.3',true),
      this.temp('maxAirTemp','القيمة العظمى لدرجة حرارة الهواء (سْ)','+32.1',true),
      this.temp('minAirTemp','القيمة الصغرى لدرجة حرارة الهواء (سْ)','+18.3',true),
      this.temp('minTemp2m','القيمة الصغرى على ارتفاع 2م (سْ)','+17.8'),
      this.temp('maxSoilSurfaceTemp','القيمة العظمى لدرجة حرارة سطح التربة (سْ)','+45.2'),
      this.temp('minSoilSurfaceTemp','القيمة الصغرى لدرجة حرارة سطح التربة (سْ)','+15.6')
    ]},
    { title: 'الرطوبة والحسابات', fields: [
      this.field('avgHumidity','معدل الرطوبة النسبية (%)','075 أو 085 أو 100',3,'^\d{3}$',true,0,100),
      this.field('minHumidity','القيمة الصغرى الرطوبة النسبية (%)','045',3,'^\d{3}$',false,0,100),
      this.field('avgEsE','معدل es-e','12.3',4,'^\d{1,2}\.\d$',false,0,99.9),
      this.field('minEsE','القيمة الصغرى لes-e','08.7',4,'^\d{1,2}\.\d$',false,0,99.9)
    ]},
    { title: 'السطوع الشمسي والغيوم', fields: [
      this.field('sunshineHours','مدة السطوع الشمس - ساعة','09.5',4,'^\d{1,2}\.\d$',false,0,12),
      this.field('totalCloudCover','معدل التغطية الكلية','03',2,'^\d{1,2}$',false,0,8),
      this.field('lowCloudCover','معدل تغطية الغيوم المنخفضة','02',2,'^\d{1,2}$',false,0,8)
    ]},
    { title: 'الهطول والرياح', fields: [
      this.field('precipitation','الهطول (مم)','000.0',5,'^\d{1,3}\.\d$',false,0,999.9),
      this.field('maxWindSpeed','أكبر سرعة رياح من المخطط','15',2,'^\d{1,2}$',false,0,36),
      this.field('classAEvaporation','التبخر من CLASS-A','08.2',4,'^\d{1,2}\.\d$',false,0,99.9),
      this.field('avgWindSpeed2m','معدل سرعة الرياح على ارتفاع 2 م','05.7',4,'^\d{1,2}\.\d$',false,0,36)
    ]},
    { title: 'درجات حرارة التربة', fields: [
      this.temp('avgSoilTemp5cm','معدل حرارة تربة على عمق 5 سم (سْ)','+24.3'),
      this.temp('avgSoilTemp10cm','معدل حرارة تربة على عمق 10 سم (سْ)','+23.1'),
      this.temp('avgSoilTemp20cm','معدل درجة حرارة تربة على عمق 20 سم (سْ)','+21.8'),
      this.temp('avgSoilTemp50cm','معدل درجة حرارة تربة على عمق 50 سم (سْ)','+20.5'),
      this.temp('fieldSoilTemp5cm','درجة حرارة تربة الحقل على عمق 5 سم (سْ)','+25.1'),
      this.temp('fieldSoilTemp10cm','حرارة تربة الحقل على عمق 10 سم (سْ)','+23.9'),
      this.field('logEvaporation','التبخر من السجل','07.5',4,'^\d{1,2}\.\d$',false,0,99.9)
    ]}
  ];

  readonly phenomena = [
    { id: 'dew', label: 'ندى' }, { id: 'fog', label: 'ضباب' },
    { id: 'hail', label: 'برد' }, { id: 'sandstorm', label: 'عواصف رملية أو ترابية' }
  ];

  ngAfterViewInit(): void {
    try {
      const saved = localStorage.getItem('agriculturalReportDraft');
      if (!saved) return;
      const draft = JSON.parse(saved) as { data?: Record<string, string | boolean> };
      if (!draft.data) return;
      const form = this.formRef.nativeElement;
      for (const [name, value] of Object.entries(draft.data)) {
        const control = form.elements.namedItem(name);
        if (control instanceof HTMLInputElement && control.type === 'checkbox') {
          control.checked = Boolean(value);
        } else if (control instanceof HTMLInputElement || control instanceof HTMLSelectElement || control instanceof HTMLTextAreaElement) {
          control.value = String(value);
        }
      }
      this.draftStatus = 'تم استعادة مسودة محفوظة محلياً من هذا المتصفح. لم يتم تحميلها من الخادم.';
    } catch {
      this.draftStatus = 'تعذر استعادة المسودة المحلية.';
    }
  }

  private field(id: string, label: string, placeholder: string, maxLength: number, pattern: string, required = false, min?: number, max?: number): AgricultureField {
    return { id, label, placeholder, maxLength, pattern, required, min, max };
  }

  private temp(id: string, label: string, placeholder: string, required = false): AgricultureField {
    return { id, label, placeholder, maxLength: 6, pattern: '^[+-]?\d{1,2}(\.\d)?$', required, min: -20, max: 60, temperature: true, title: 'درجة الحرارة: ±dd.d أو ±d.d' } as AgricultureField;
  }

  private toDateInput(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  saveDraft(form: HTMLFormElement): void {
    try {
      const values: Record<string, string | boolean> = {};
      Array.from(form.elements).forEach(control => {
        if (control instanceof HTMLInputElement || control instanceof HTMLSelectElement || control instanceof HTMLTextAreaElement) {
          if (!control.name) return;
          values[control.name] = control instanceof HTMLInputElement && control.type === 'checkbox'
            ? control.checked
            : control.value;
        }
      });
      const draft = { data: values, savedAt: new Date().toISOString(), status: 'draft' };
      localStorage.setItem('agriculturalReportDraft', JSON.stringify(draft));
      this.draftStatus = 'حُفظت المسودة محلياً على هذا المتصفح فقط. لم تُرسل إلى الخادم أو قاعدة البيانات.';
    } catch {
      this.draftStatus = 'تعذر حفظ المسودة محلياً في هذا المتصفح.';
    }
  }

  formatTemperature(input: HTMLInputElement): void {
    const raw = input.value.trim();
    if (!raw) return;
    const match = raw.match(/^([+-]?)(\d{1,2})(?:\.(\d+))?$/);
    if (!match) return;
    const sign = match[1] || '+';
    const whole = match[2].padStart(2, '0');
    const decimal = (match[3] || '0').slice(0, 1);
    input.value = `${sign}${whole}.${decimal}`;
  }

  setSign(input: HTMLInputElement, sign: string): void {
    const value = input.value.replace(/^[+-]/, '');
    input.value = sign + value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  clearFieldError(input: HTMLInputElement): void {
    input.setCustomValidity('');
    const error = document.getElementById(input.id + 'Error');
    if (error) error.textContent = '';
  }

  validateField(input: HTMLInputElement, field: AgricultureField): void {
    const value = input.value.trim();
    if (!value) {
      input.setCustomValidity(field.required ? 'هذا الحقل مطلوب' : '');
      return;
    }
    let message = '';
    if (!new RegExp(field.pattern).test(value)) {
      message = field.temperature
        ? 'تنسيق درجة الحرارة غير صحيح. أمثلة: +25.5, -05.3, 25.5'
        : 'الصيغة غير صحيحة';
    } else {
      const numeric = Number(value);
      if (field.min !== undefined && numeric < field.min) message = `القيمة أقل من الحد الأدنى (${field.min})`;
      if (field.max !== undefined && numeric > field.max) message = `القيمة أكبر من الحد الأقصى (${field.max})`;
    }
    input.setCustomValidity(message);
    const error = document.getElementById(input.id + 'Error');
    if (error) error.textContent = message;
  }

  fillTestData(form: HTMLFormElement): void {
    const sample: Record<string,string> = {
      avgAirTemp:'+25.5', maxAirTemp:'+32.1', minAirTemp:'+18.3', minTemp2m:'+17.8',
      maxSoilSurfaceTemp:'+45.2', minSoilSurfaceTemp:'+15.6', avgHumidity:'075', minHumidity:'045',
      avgEsE:'12.3', minEsE:'08.7', sunshineHours:'09.5', totalCloudCover:'03', lowCloudCover:'02',
      precipitation:'000.0', maxWindSpeed:'15', classAEvaporation:'08.2', avgWindSpeed2m:'05.7',
      avgSoilTemp5cm:'+24.3', avgSoilTemp10cm:'+23.1', avgSoilTemp20cm:'+21.8',
      avgSoilTemp50cm:'+20.5', fieldSoilTemp5cm:'+25.1', fieldSoilTemp10cm:'+23.9', logEvaporation:'07.5'
    };
    for (const [id,value] of Object.entries(sample)) {
      const input = form.elements.namedItem(id) as HTMLInputElement | null;
      if (input) { input.value = value; input.setCustomValidity(''); }
      const error = document.getElementById(id + 'Error');
      if (error) error.textContent = '';
    }
    (form.elements.namedItem('reportDate') as HTMLInputElement).value = this.today;
    (form.elements.namedItem('dew') as HTMLSelectElement).value = '1';
    for (const id of ['fog', 'hail', 'sandstorm']) (form.elements.namedItem(id) as HTMLSelectElement).value = '0';
    (form.elements.namedItem('observerNotes') as HTMLTextAreaElement).value = 'بيانات تجريبية لا تمثل رصداً فعلياً.';
    (form.elements.namedItem('responsibilityAgreement') as HTMLInputElement).checked = true;
    form.querySelectorAll('.error').forEach(el => el.textContent = '');
  }

  preview(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    const fields = this.sections.flatMap(section => section.fields);
    for (const field of fields) {
      const input = form.elements.namedItem(field.id) as HTMLInputElement;
      this.validateField(input, field);
    }
    if (!form.reportValidity()) return;
    const data = new FormData(form);
    const labels: Record<string,string> = { reportDate: 'تاريخ التقرير', observerNotes: 'ملاحظات الراصد' };
    for (const section of this.sections) for (const field of section.fields) labels[field.id] = field.label;
    for (const item of this.phenomena) labels[item.id] = item.label;
    const lines = Object.entries(labels).map(([id,label]) => `${label}: ${String(data.get(id) ?? '—')}`);
    lines.push('تأكيد المسؤولية: تم التأكيد');
    this.previewText = lines.join('\\n');
  }
}
