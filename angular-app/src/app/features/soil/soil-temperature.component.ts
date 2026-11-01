import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

@Component({
  standalone: true,
  selector: 'metra-soil-temperature',
  imports: [CommonModule],
  template: `
    <div class="soil-page" dir="rtl">
      <header class="soil-header">
        <div><h1>نظام درجات حرارة التربة</h1><p>إدخال بيانات درجات حرارة التربة وفق نموذج الرصد الأصلي</p></div>
        <span class="preview-tag">وضع المعاينة</span>
      </header>
      <div class="notice"><strong>تنبيه:</strong> هذه معاينة للواجهة والتحقق داخل الصفحة. لا يوجد اتصال فعلي بقاعدة البيانات أو API، ولا يتم حفظ السجلات بشكل دائم.</div>
      <form #soilForm (submit)="preview($event, soilForm)">
        <section class="panel">
          <h2>المعلومات الأساسية</h2>
          <label class="field">التوقيت العالمي المكافئ (UTC)
            <select name="utcTime" required>
              <option value="" selected disabled>اختر الوقت العالمي (UTC)</option>
              <option value="00">00:00 UTC</option><option value="06">06:00 UTC</option>
              <option value="12">12:00 UTC</option><option value="18">18:00 UTC</option>
            </select>
            <small>يتم إدخال التوقيت العالمي فقط (UTC+0)</small>
          </label>
        </section>
        <section class="panel">
          <h2>درجات حرارة التربة <small>(النطاق: -20.0 إلى +50.0 درجة مئوية)</small></h2>
          <div class="fields">
            <label class="field">درجة حرارة تربة على عمق 5سم (سْ)
              <input #t5 name="soilTemp5cm" type="text" placeholder="±dd.d أو #" maxlength="5" required>
              <span class="signs"><button type="button" (click)="setSign(t5, '-')">سالب</button><button type="button" (click)="setSign(t5, '+')">موجب</button><button type="button" (click)="setMissing(t5)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 10سم (سْ)
              <input #t10 name="soilTemp10cm" type="text" placeholder="±dd.d أو #" maxlength="5" required>
              <span class="signs"><button type="button" (click)="setSign(t10, '-')">سالب</button><button type="button" (click)="setSign(t10, '+')">موجب</button><button type="button" (click)="setMissing(t10)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 20سم (سْ)
              <input #t20 name="soilTemp20cm" type="text" placeholder="±dd.d أو #" maxlength="5" required>
              <span class="signs"><button type="button" (click)="setSign(t20, '-')">سالب</button><button type="button" (click)="setSign(t20, '+')">موجب</button><button type="button" (click)="setMissing(t20)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 50سم (سْ)
              <input #t50 name="soilTemp50cm" type="text" placeholder="±dd.d أو #" maxlength="5" required>
              <span class="signs"><button type="button" (click)="setSign(t50, '-')">سالب</button><button type="button" (click)="setSign(t50, '+')">موجب</button><button type="button" (click)="setMissing(t50)">#</button></span>
            </label>
          </div>
        </section>
        <section class="panel">
          <h2>ملاحظات الراصد</h2>
          <label class="field">ملاحظات إضافية (اختياري)
            <textarea name="observerNotes" rows="3" maxlength="500" placeholder="يمكنك إضافة أي ملاحظات أو تعليقات إضافية هنا..." (input)="countNotes($event)"></textarea>
            <small>الحد الأقصى 500 حرف — {{ notesCount }}/500</small>
          </label>
        </section>
        <section class="panel">
          <h2>تأكيد المسؤولية</h2>
          <label class="agreement"><input name="responsibilityConfirmed" type="checkbox" required> أتعهد وأقر بأن البيانات المقدمة صحيحة ودقيقة، وأتحمل المسؤولية الكاملة عنها</label>
        </section>
        <div class="actions">
          <button type="button" class="test" (click)="fillTestData(t5,t10,t20,t50,soilForm)">إدخال بيانات تجريبية</button>
          <button type="submit" class="preview">معاينة التقرير</button>
          <button type="button" class="submit" disabled title="يتطلب ربط API وقاعدة البيانات">إرسال إلى قاعدة البيانات — غير متاح في المعاينة</button>
        </div>
      </form>
      <section class="panel result" *ngIf="previewText"><h2>معاينة التقرير</h2><pre>{{ previewText }}</pre></section>
    </div>
  `,
  styles: [`
    .soil-page{max-width:1100px;margin:0 auto;padding:20px;color:#3f3025}
    .soil-header{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:24px;background:linear-gradient(135deg,#8b4513,#654321);color:#fff;border-radius:14px}
    h1{margin:0;font-size:1.65rem}.soil-header p{margin:8px 0 0}.preview-tag{background:#fff;color:#654321;padding:7px 12px;border-radius:20px;white-space:nowrap}
    .notice{margin:16px 0;padding:12px 16px;background:#fff4df;border-right:4px solid #a0522d;border-radius:8px;line-height:1.8}
    .panel{background:#fff;border:1px solid #e4d8cc;border-radius:12px;padding:22px;margin:16px 0;box-shadow:0 3px 12px #6543210d}
    h2{font-size:1.15rem;color:#654321;margin:0 0 18px;padding-bottom:10px;border-bottom:2px solid #a0522d}h2 small{font-size:.85rem;font-weight:400}
    .fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}.field{display:flex;flex-direction:column;gap:8px;font-weight:600}
    input[type=text],select,textarea{width:100%;box-sizing:border-box;border:1px solid #cfc5bc;border-radius:8px;background:#fff;color:#212529;padding:11px;font:inherit}
    input:focus,select:focus,textarea:focus{outline:2px solid #a0522d55;border-color:#a0522d}
    small{font-weight:400;color:#76695f}.signs{display:flex;gap:8px}.signs button,.actions button{border:0;border-radius:7px;padding:9px 13px;cursor:pointer}.signs button{background:#f0e6dc;color:#654321}
    .agreement{display:flex;gap:10px;align-items:flex-start;line-height:1.8}.actions{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}.actions button{color:#fff}.test{background:#8b6a28}.preview{background:#8b4513}.submit{background:#777;cursor:not-allowed!important}
    .result pre{white-space:pre-wrap;font:inherit;line-height:1.9}.result{border-color:#a0522d}
    @media(max-width:700px){.fields{grid-template-columns:1fr}.soil-page{padding:12px}.soil-header{align-items:flex-start;flex-direction:column}}
  `]
})
export class SoilTemperatureComponent {
  notesCount = 0;
  previewText = '';

  setSign(field: HTMLInputElement, sign: string): void {
    if (field.value === '#') return;
    const value = field.value.replace(/^[+-]/, '');
    field.value = sign + value;
  }

  setMissing(field: HTMLInputElement): void {
    field.value = '#';
  }

  countNotes(event: Event): void {
    this.notesCount = (event.target as HTMLTextAreaElement).value.length;
  }

  fillTestData(t5: HTMLInputElement, t10: HTMLInputElement, t20: HTMLInputElement, t50: HTMLInputElement, form: HTMLFormElement): void {
    t5.value = '+24.3';
    t10.value = '+23.1';
    t20.value = '+21.8';
    t50.value = '+20.5';
    (form.elements.namedItem('utcTime') as HTMLSelectElement).value = '06';
    (form.elements.namedItem('observerNotes') as HTMLTextAreaElement).value = 'بيانات تجريبية لا تمثل رصداً فعلياً.';
    this.notesCount = (form.elements.namedItem('observerNotes') as HTMLTextAreaElement).value.length;
  }

  preview(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const data = new FormData(form);
    const labels: Record<string, string> = {
      utcTime: 'التوقيت العالمي المكافئ (UTC)',
      soilTemp5cm: 'درجة حرارة تربة على عمق 5سم (سْ)',
      soilTemp10cm: 'درجة حرارة تربة على عمق 10سم (سْ)',
      soilTemp20cm: 'درجة حرارة تربة على عمق 20سم (سْ)',
      soilTemp50cm: 'درجة حرارة تربة على عمق 50سم (سْ)',
      observerNotes: 'ملاحظات إضافية (اختياري)'
    };
    this.previewText = Object.entries(labels).map(([key, label]) => `${label}: ${String(data.get(key) ?? '—')}`).join('\\n');
    this.previewText += '\\nتأكيد المسؤولية: تم التأكيد';
  }
}
