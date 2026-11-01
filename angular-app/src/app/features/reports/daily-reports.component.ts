import { Component } from '@angular/core';

@Component({
  standalone: true,
  selector: 'metra-daily-reports',
  template: `
    <div class="page">
      <header class="page-head"><div class="head-icon"><i class="fa-regular fa-calendar-days"></i></div><div><h1>النشرات اليومية</h1><p>تسجيل ملخص الحالة الجوية وعناصر الرصد اليومية</p></div></header>
      <form (submit)="submit($event)">
        <section class="panel"><h2><i class="fa-solid fa-calendar-check"></i> معلومات النشرة</h2><div class="grid">
          <label>تاريخ الرصد<input type="date" name="date" required [value]="today"></label>
          <label>نوع التقرير<select name="reportType" required><option value="24h">ملخص 24 ساعة</option><option value="06utc">رصد الساعة 06 UTC</option><option value="18utc">رصد الساعة 18 UTC</option></select></label>
          <label>المحطة<input name="station" required placeholder="اسم أو رمز المحطة"></label>
          <label>اسم الراصد<input name="observer" required placeholder="اسم الراصد"></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-temperature-half"></i> درجات الحرارة والهطول</h2><div class="grid">
          <label>درجة الحرارة الصغرى (°م)<input type="number" step="0.1" name="minTemp" required></label>
          <label>درجة الحرارة العظمى (°م)<input type="number" step="0.1" name="maxTemp" required></label>
          <label>كمية الأمطار (ملم)<input type="number" min="0" step="0.1" name="precipitation" required></label>
          <label>سماكة الثلوج (سم)<input type="number" min="0" step="1" name="snowThickness"></label>
          <label>التبخر (ملم)<input type="number" min="0" step="0.1" name="evaporation"></label>
          <label>مدة السطوع الشمسي (ساعة)<input type="number" min="0" max="24" step="0.1" name="sunshineDuration"></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-gauge-high"></i> الرطوبة والرياح</h2><div class="grid">
          <label>أعلى رطوبة نسبية (%)<input type="number" min="0" max="100" name="maxHumidity"></label>
          <label>وقت أعلى رطوبة<input type="time" name="maxHumidityTime"></label>
          <label>أدنى رطوبة نسبية (%)<input type="number" min="0" max="100" name="minHumidity"></label>
          <label>وقت أدنى رطوبة<input type="time" name="minHumidityTime"></label>
          <label>أقصى سرعة هبات الرياح (عقدة)<input type="number" min="0" step="0.1" name="maxGustSpeed"></label>
          <label>اتجاه الهبات (درجة)<input type="number" min="0" max="360" name="maxGustDirection"></label>
          <label>وقت الهبات القصوى<input type="time" name="maxGustTime"></label>
          <label>نسبة السطوع الشمسي (%)<input type="number" min="0" max="100" name="sunshinePercentage"></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-cloud-bolt"></i> الظواهر الجوية خلال اليوم</h2><div class="phenomena">
          @for (item of phenomena; track item) {<label><input type="checkbox" [value]="item" name="phenomena">{{ item }}</label>}
        </div><label class="notes-label">ملاحظات الراصد<textarea name="notes" rows="4" placeholder="تفاصيل إضافية عن الظواهر والحالة الجوية..."></textarea></label></section>
        <div class="agreement"><label><input type="checkbox" required> أقر بصحة البيانات المدخلة ومطابقتها لسجل الرصد.</label></div>
        <div class="actions"><button class="primary" type="submit"><i class="fa-solid fa-clipboard-check"></i> مراجعة التقرير اليومي</button><button class="secondary" type="reset">مسح الحقول</button></div>
      </form>
      @if (message) {<div class="notice" role="status"><i class="fa-solid fa-circle-info"></i>{{ message }}</div>}
      <p class="footnote">المراجعة حالياً محلية فقط؛ لا يتم حفظ التقرير أو إرساله قبل ربط واجهة API والمصادقة.</p>
    </div>`,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}.page-head{display:flex;align-items:center;gap:18px;background:linear-gradient(135deg,#3498db,#2471a3);color:#fff;padding:24px 28px;border-radius:16px;margin-bottom:22px;box-shadow:0 8px 24px #3498db30}.head-icon{width:62px;height:62px;border-radius:15px;background:#ffffff25;display:grid;place-items:center;font-size:30px}.page-head h1{margin:0 0 5px;font-size:27px}.page-head p{margin:0;opacity:.9}.panel{background:#fff;border:1px solid #e5eaee;border-radius:14px;padding:22px;margin-bottom:18px;box-shadow:0 5px 18px #2638490a}.panel h2{font-size:18px;margin:0 0 20px;padding-bottom:12px;border-bottom:2px solid #edf1f4;color:#34495e}.panel h2 i{color:#3498db;margin-left:9px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.grid label,.notes-label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.grid input,.grid select,.notes-label textarea{width:100%;box-sizing:border-box;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;background:#fbfcfd;color:#2c3e50;font:inherit;font-weight:400}.phenomena{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-bottom:20px}.phenomena label{display:flex;align-items:center;gap:8px;background:#f7f9fb;padding:11px;border-radius:8px;font-size:13px}.notes-label textarea{margin-top:7px}.agreement{background:#f4f8fb;padding:14px 16px;border-radius:9px;margin:15px 0;font-size:13px}.actions{display:flex;gap:10px}.actions button{border:0;border-radius:9px;padding:12px 22px;font:inherit;font-weight:700;cursor:pointer}.primary{background:#2980b9;color:#fff}.secondary{background:#ecf0f1;color:#34495e}.notice{margin-top:16px;padding:14px;background:#eaf4fb;border-right:4px solid #3498db;border-radius:8px}.footnote{font-size:12px;color:#8a969e;margin-top:18px}@media(max-width:900px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.phenomena{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid,.phenomena{grid-template-columns:1fr}.page-head{padding:18px}.page-head h1{font-size:22px}.head-icon{width:50px;height:50px}.panel{padding:16px}.actions{flex-direction:column}}`
  ]
})
export class DailyReportsComponent {
  readonly today = new Date().toISOString().slice(0,10);
  readonly phenomena = ['عواصف رعدية','برد','ثلوج','أمطار','صقيع','ضباب','شابورة','عواصف ترابية أو رملية','غبار متصاعد','سديم','رياح عاصفة'];
  message = '';
  submit(event: Event): void {
    event.preventDefault();
    const form = event.target as HTMLFormElement;
    if (!form.reportValidity()) return;
    const min = Number(new FormData(form).get('minTemp'));
    const max = Number(new FormData(form).get('maxTemp'));
    if (min > max) { this.message = 'تنبيه: درجة الحرارة الصغرى أكبر من العظمى؛ يرجى مراجعة القيم.'; return; }
    this.message = 'تم التحقق من الحقول محلياً. بعد ربط API سيُحفظ التقرير ويُرسل لمسار التدقيق.';
  }
}
