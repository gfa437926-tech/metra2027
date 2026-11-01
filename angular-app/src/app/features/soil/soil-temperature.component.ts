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
              <option value="23">23:00 UTC</option><option value="02">02:00 UTC</option>
              <option value="05">05:00 UTC</option><option value="08">08:00 UTC</option>
              <option value="11">11:00 UTC</option><option value="14">14:00 UTC</option>
              <option value="17">17:00 UTC</option><option value="20">20:00 UTC</option>
            </select>
            <small>يتم إدخال التوقيت العالمي فقط (UTC+0)</small>
          </label>
        </section>
        <section class="panel">
          <h2>درجات حرارة التربة <small>(النطاق: -20.0 إلى +50.0 درجة مئوية)</small></h2>
          <div class="fields">
            <label class="field">درجة حرارة تربة على عمق 5سم (سْ)
              <input #t5 name="soilTemp5cm" type="text" placeholder="±dd.d أو #" maxlength="5" pattern="^[+-]?\\d{1,2}\\.\\d$|^#$" required (blur)="formatTemperature(t5)">
              <span class="signs"><button type="button" (click)="setSign(t5, '-')">سالب</button><button type="button" (click)="setSign(t5, '+')">موجب</button><button type="button" (click)="setMissing(t5)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 10سم (سْ)
              <input #t10 name="soilTemp10cm" type="text" placeholder="±dd.d أو #" maxlength="5" pattern="^[+-]?\\d{1,2}\\.\\d$|^#$" required (blur)="formatTemperature(t10)">
              <span class="signs"><button type="button" (click)="setSign(t10, '-')">سالب</button><button type="button" (click)="setSign(t10, '+')">موجب</button><button type="button" (click)="setMissing(t10)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 20سم (سْ)
              <input #t20 name="soilTemp20cm" type="text" placeholder="±dd.d أو #" maxlength="5" pattern="^[+-]?\\d{1,2}\\.\\d$|^#$" required (blur)="formatTemperature(t20)">
              <span class="signs"><button type="button" (click)="setSign(t20, '-')">سالب</button><button type="button" (click)="setSign(t20, '+')">موجب</button><button type="button" (click)="setMissing(t20)">#</button></span>
            </label>
            <label class="field">درجة حرارة تربة على عمق 50سم (سْ)
              <input #t50 name="soilTemp50cm" type="text" placeholder="±dd.d أو #" maxlength="5" pattern="^[+-]?\\d{1,2}\\.\\d$|^#$" required (blur)="formatTemperature(t50)">
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
    const value = field.value.replace(/^[+-]/, '');
    field.value = sign + value;
    field.setCustomValidity('');
  }

  setMissing(field: HTMLInputElement): void {
    field.value = '#';
    field.setCustomValidity('');
  }

  formatTemperature(field: HTMLInputElement): void {
    let value = field.value.trim();
    if (!value || value === '#') return;
    value = value.replace(/[^0-9.#+-]/g, '');
    let sign = '';
    if (value.startsWith('-') || value.startsWith('+')) {
      sign = value[0];
      value = value.substring(1);
    } else if (value.startsWith('#')) {
      field.value = '#';
      return;
    }
    value = value.replace(/[+#-]/g, '');
    if (!value) { field.value = sign; return; }
    if (!value.includes('.')) {
      const digits = value.replace(/[^0-9]/g, '');
      if (digits.length >= 2) value = digits.slice(0, -1) + '.' + digits.slice(-1);
      else if (digits.length === 1) value = '0.' + digits;
    } else {
      const parts = value.split('.');
      if (parts[1].length > 1) value = parts[0] + '.' + parts[1].charAt(0);
      else if (parts[1].length === 0) value += '0';
    }
    const parts = value.split('.');
    if (parts[0].length === 1) value = '0' + parts[0] + '.' + parts[1];
    else if (parts[0].length === 0) value = '00.' + parts[1];
    field.value = sign ? sign + value : '+' + value;
    field.setCustomValidity('');
  }

  countNotes(event: Event): void {
    this.notesCount = (event.target as HTMLTextAreaElement).value.length;
  }

  fillTestData(t5: HTMLInputElement, t10: HTMLInputElement, t20: HTMLInputElement, t50: HTMLInputElement, form: HTMLFormElement): void {
    t5.value = '+25.5';
    t10.value = '-5.3';
    t20.value = '#';
    t50.value = '+22.0';
    (form.elements.namedItem('utcTime') as HTMLSelectElement).value = '05';
    (form.elements.namedItem('observerNotes') as HTMLTextAreaElement).value = 'بيانات تجريبية للاختبار:\\n• قراءات 5سم و50سم طبيعية\\n• قراءات 10سم سالبة\\n• قراءات 20سم غير متوفرة (#)\\n• جميع القراءات ضمن النطاق المسموح\\n• تم إنشاؤها تلقائياً للنظام';
    (form.elements.namedItem('responsibilityConfirmed') as HTMLInputElement).checked = true;
    this.notesCount = (form.elements.namedItem('observerNotes') as HTMLTextAreaElement).value.length;
  }

  preview(event: Event, form: HTMLFormElement): void {
    event.preventDefault();
    const allowedHours = ['23', '02', '05', '08', '11', '14', '17', '20'];
    const utc = form.elements.namedItem('utcTime') as HTMLSelectElement;
    utc.setCustomValidity(allowedHours.includes(utc.value) ? '' : 'يجب اختيار ساعة UTC صحيحة');
    const temperatureFields = ['soilTemp5cm', 'soilTemp10cm', 'soilTemp20cm', 'soilTemp50cm'];
    for (const id of temperatureFields) {
      const field = form.elements.namedItem(id) as HTMLInputElement;
      const value = field.value.trim();
      const validFormat = value === '#' || /^[+-]?\\d{1,2}\\.\\d$/.test(value);
      const numeric = value === '#' ? 0 : Number(value);
      const validRange = value === '#' || (numeric >= -20 && numeric <= 50);
      field.setCustomValidity(validFormat && validRange ? '' : 'أدخل درجة بصيغة ±dd.d ضمن النطاق -20.0 إلى +50.0، أو #');
    }
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
