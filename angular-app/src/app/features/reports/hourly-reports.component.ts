import { Component } from '@angular/core';

@Component({
  standalone: true,
  selector: 'metra-hourly-reports',
  template: `
    <div class="page">
      <header class="page-head"><div class="head-icon"><i class="fa-regular fa-clock"></i></div><div><h1>النشرات الساعية</h1><p>إدخال ومراجعة عناصر الرصد الجوي الساعي</p></div></header>
      <section class="stats"><article><i class="fa-solid fa-calendar-day"></i><span>تاريخ الرصد</span><strong>{{ today }}</strong></article><article><i class="fa-regular fa-clock"></i><span>التوقيت المحلي</span><strong>{{ now }}</strong></article><article><i class="fa-solid fa-location-dot"></i><span>المحطة</span><strong>المحطة المحددة للمستخدم</strong></article></section>
      <form (submit)="submit($event)">
        <section class="panel"><h2><i class="fa-solid fa-circle-info"></i> المعلومات الأساسية</h2><div class="grid">
          <label>تاريخ الرصد<input type="date" name="date" required [value]="today"></label>
          <label>ساعة الرصد (UTC)<select name="utcTime" required><option value="">اختر الساعة</option>@for (h of hours; track h) {<option [value]="h">{{ h }}:00</option>}</select></label>
          <label>رقم المحطة<input name="station" placeholder="رمز المحطة" required></label>
          <label>اسم الراصد<input name="observer" placeholder="اسم الراصد" required></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-temperature-half"></i> الحرارة والضغط والرطوبة</h2><div class="grid">
          <label>درجة الحرارة الجافة (°م)<input name="dryTemp" type="number" step="0.1" placeholder="مثال: 24.5" required></label>
          <label>درجة الحرارة المبللة (°م)<input name="wetTemp" type="number" step="0.1"></label>
          <label>الضغط الجوي للمحطة (hPa)<input name="stationPressure" type="number" step="0.1"></label>
          <label>ضغط سطح البحر (hPa)<input name="seaLevelPressure" type="number" step="0.1"></label>
          <label>الرطوبة النسبية (%)<input name="relativeHumidity" type="number" min="0" max="100" required></label>
          <label>درجة الندى (°م)<input name="dewPoint" type="number" step="0.1"></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-wind"></i> الرياح والرؤية والطقس</h2><div class="grid">
          <label>اتجاه الرياح (درجة)<input name="windDirection" type="number" min="0" max="360"></label>
          <label>سرعة الرياح (عقدة)<input name="windSpeed" type="number" min="0" step="0.1"></label>
          <label>سرعة الهبات (عقدة)<input name="gustSpeed" type="number" min="0" step="0.1"></label>
          <label>مدى الرؤية (كم)<input name="visibility" type="number" min="0" step="0.1"></label>
          <label>الطقس الحالي<input name="currentWeather" placeholder="رمز أو وصف الظاهرة"></label>
          <label>الطقس السابق<input name="pastWeather" placeholder="رمز أو وصف الظاهرة"></label>
          <label>كمية الهطول (ملم)<input name="precipitation" type="number" min="0" step="0.1"></label>
          <label>الغطاء السحابي (أثمان)<select name="cloudCover"><option value="">اختر</option>@for (n of cloudValues; track n) {<option [value]="n">{{ n }}</option>}</select></label>
        </div></section>
        <section class="panel"><h2><i class="fa-solid fa-cloud"></i> تفاصيل السحب والملاحظات</h2><div class="grid">
          <label>نوع السحب<input name="cloudType" placeholder="CL / CM / CH أو الوصف"></label>
          <label>ارتفاع قاعدة السحب (متر)<input name="cloudHeight" type="number" min="0"></label>
          <label class="wide">ملاحظات الراصد<textarea name="notes" rows="3" placeholder="ملاحظات إضافية عن حالة الطقس..."></textarea></label>
        </div></section>
        <div class="agreement"><label class="check"><input type="checkbox" required> أقر بصحة البيانات المدخلة ومطابقتها لسجل الرصد.</label></div>
        <div class="actions"><button class="primary" type="submit"><i class="fa-solid fa-clipboard-check"></i> مراجعة النشرة</button><button class="secondary" type="reset">مسح الحقول</button></div>
      </form>
      @if (message) {<div class="notice" role="status"><i class="fa-solid fa-circle-info"></i>{{ message }}</div>}
      <p class="footnote">هذه واجهة إدخال ومراجعة أولية. لا يتم حفظ البيانات أو إرسالها إلى قاعدة البيانات حتى تفعيل واجهة API والمصادقة.</p>
    </div>`,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}.page-head{display:flex;align-items:center;gap:18px;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;padding:24px 28px;border-radius:16px;margin-bottom:22px;box-shadow:0 8px 24px #667eea30}.head-icon{width:62px;height:62px;border-radius:15px;background:#ffffff25;display:grid;place-items:center;font-size:30px}.page-head h1{margin:0 0 5px;font-size:27px}.page-head p{margin:0;opacity:.9}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:22px}.stats article{background:#fff;border:1px solid #e8edf1;border-radius:12px;padding:15px 18px;display:grid;grid-template-columns:32px 1fr;align-items:center;gap:3px 10px}.stats i{grid-row:span 2;color:#3498db;font-size:20px}.stats span{font-size:12px;color:#82909a}.stats strong{font-size:14px}.panel{background:#fff;border:1px solid #e5eaee;border-radius:14px;padding:22px;margin-bottom:18px;box-shadow:0 5px 18px #2638490a}.panel h2{font-size:18px;margin:0 0 20px;padding-bottom:12px;border-bottom:2px solid #edf1f4;color:#34495e}.panel h2 i{color:#3498db;margin-left:9px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.grid label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.grid input,.grid select,.grid textarea{width:100%;box-sizing:border-box;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;background:#fbfcfd;color:#2c3e50;font:inherit;font-weight:400;outline:none}.grid input:focus,.grid select:focus,.grid textarea:focus{border-color:#3498db;box-shadow:0 0 0 3px #3498db20}.wide{grid-column:1/-1}.agreement{background:#f4f8fb;padding:14px 16px;border-radius:9px;margin:15px 0}.check{display:flex;align-items:center;gap:9px;font-size:13px}.actions{display:flex;gap:10px}.actions button{border:0;border-radius:9px;padding:12px 22px;font:inherit;font-weight:700;cursor:pointer}.primary{background:#2980b9;color:#fff}.secondary{background:#ecf0f1;color:#34495e}.notice{margin-top:16px;padding:14px;background:#eaf4fb;border-right:4px solid #3498db;border-radius:8px}.footnote{font-size:12px;color:#8a969e;margin-top:18px}.footnote:before{content:'ⓘ';margin-left:6px}@media(max-width:850px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.stats{grid-template-columns:1fr}.grid{grid-template-columns:1fr}.page-head{padding:18px}.page-head h1{font-size:22px}.head-icon{width:50px;height:50px}.panel{padding:16px}.wide{grid-column:auto}.actions{flex-direction:column}}`
  ]
})
export class HourlyReportsComponent {
  readonly today = new Date().toISOString().slice(0,10);
  readonly now = new Intl.DateTimeFormat('ar', {hour:'2-digit',minute:'2-digit'}).format(new Date());
  readonly hours = Array.from({length:24},(_,i)=>String(i).padStart(2,'0'));
  readonly cloudValues = ['0','1','2','3','4','5','6','7','8','/'];
  message = '';
  submit(event: Event): void {
    event.preventDefault();
    const form = event.target as HTMLFormElement;
    if (!form.reportValidity()) return;
    this.message = 'تم التحقق من الحقول محلياً. الخطوة التالية بعد ربط API هي حفظ النشرة وإرسالها لمسار التدقيق.';
  }
}
