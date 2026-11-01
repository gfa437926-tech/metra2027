import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
 standalone:true, imports:[CommonModule],
 template:`
 <div class="page" dir="rtl">
  <header><div class="icon"><i class="fa-solid fa-calendar-week"></i></div><div><h1>التقارير الشهرية</h1><p>استعراض النشرات المناخية حسب المحطة والسنة والشهر واليوم</p></div><span class="mode">معاينة</span></header>
  <div class="notice"><i class="fa-solid fa-circle-info"></i><span>مصدر البيانات غير مربوط حالياً. لن تُعرض أرقام أو سجلات افتراضية على أنها بيانات رصد حقيقية.</span></div>
  <section class="panel"><h2><i class="fa-solid fa-filter"></i> معايير البحث والتصنيف</h2>
   <div class="filters">
    <label>المحطة<select (change)="station=$any($event.target).value"><option value="">جميع المحطات</option>@for(s of stations;track s){<option [value]="s">{{s}}</option>}</select></label>
    <label>السنة<select (change)="year=$any($event.target).value"><option value="">جميع السنوات</option>@for(y of years;track y){<option [value]="y">{{y}}</option>}</select></label>
    <label>الشهر<select (change)="month=$any($event.target).value"><option value="">جميع الأشهر</option>@for(m of months;track m.v){<option [value]="m.v">{{m.n}}</option>}</select></label>
    <label>اليوم<input type="date" [value]="date" (change)="date=$any($event.target).value"></label>
   </div>
   <div class="actions"><button class="primary" (click)="search()"><i class="fa-solid fa-magnifying-glass"></i> تطبيق الفلاتر</button><button class="secondary" (click)="reset()">إعادة تعيين</button></div>
  </section>
  <section class="stats">
   <article><i class="fa-solid fa-location-dot"></i><span>المحطات المحددة</span><strong>—</strong></article>
   <article><i class="fa-solid fa-file-lines"></i><span>عدد النشرات</span><strong>—</strong></article>
   <article><i class="fa-regular fa-clock"></i><span>الأوقات القياسية</span><strong>00 · 06 · 12 · 18 UTC</strong></article>
   <article><i class="fa-solid fa-database"></i><span>حالة مصدر البيانات</span><strong class="pending">غير مربوط</strong></article>
  </section>
  <section class="panel results"><div class="results-head"><h2><i class="fa-solid fa-table"></i> سجل النشرات المناخية</h2><span>{{periodLabel}}</span></div>
   <div class="table-wrap"><table><thead><tr><th>المحطة</th><th>التاريخ</th><th>00 UTC</th><th>06 UTC</th><th>12 UTC</th><th>18 UTC</th><th>الإجمالي</th></tr></thead><tbody><tr><td colspan="7" class="empty"><i class="fa-regular fa-folder-open"></i><strong>{{message}}</strong><small>ستظهر سجلات المحطات هنا بعد توصيل واجهة القراءة المعتمدة.</small></td></tr></tbody></table></div>
  </section>
  <section class="panel"><h2><i class="fa-solid fa-chart-column"></i> مؤشرات الملخص الشهري</h2><div class="metrics">@for(m of metrics;track m){<div><span>{{m}}</span><b>—</b></div>}</div><p class="footnote">تعتمد المؤشرات على سجلات النشرات المعتمدة فقط بعد تحديد قواعد التجميع ووحدات القياس.</p></section>
 </div>`,
 styles:[`
 :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}header{display:flex;align-items:center;gap:16px;padding:23px 26px;background:linear-gradient(135deg,#16a085,#117864);color:#fff;border-radius:14px;margin-bottom:17px}.icon{width:56px;height:56px;display:grid;place-items:center;background:#ffffff25;border-radius:13px;font-size:26px}h1{font-size:25px;margin:0 0 5px}header p{margin:0;opacity:.9;font-size:13px}.mode{margin-right:auto;background:#fff3cd;color:#856404;padding:7px 12px;border-radius:7px;font-size:12px;font-weight:700}.notice{display:flex;gap:10px;align-items:center;padding:12px 15px;margin-bottom:17px;border-radius:8px;background:#eaf4fb;color:#245575;font-size:13px}.panel{background:#fff;border:1px solid #e5eaee;border-radius:12px;padding:21px;margin-bottom:17px}.panel h2{font-size:17px;margin:0 0 17px}.panel h2 i{color:#168b76;margin-left:8px}.filters{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:13px}.filters label{display:grid;gap:7px;font-size:13px;font-weight:700}.filters input,.filters select{min-width:0;width:100%;box-sizing:border-box;padding:11px;border:1px solid #d9e1e7;border-radius:8px;font:inherit;background:#fbfcfd}.actions{display:flex;gap:9px;margin-top:17px}.actions button{border:0;border-radius:8px;padding:11px 18px;font:inherit;font-weight:700;cursor:pointer}.primary{background:#168b76;color:#fff}.secondary{background:#edf1f3;color:#34495e}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:17px}.stats article{display:grid;grid-template-columns:30px 1fr;gap:4px 8px;align-items:center;background:#fff;border:1px solid #e5eaee;border-radius:10px;padding:14px}.stats i{grid-row:span 2;color:#168b76;font-size:19px}.stats span{font-size:11px;color:#82909a}.stats strong{font-size:13px}.pending{color:#b7791f}.results-head{display:flex;align-items:center;justify-content:space-between;gap:10px}.results-head span{font-size:12px;color:#82909a}.table-wrap{overflow:auto}table{width:100%;min-width:780px;border-collapse:collapse}th{background:#2c3e50;color:#fff;padding:13px;font-size:12px}td{text-align:center;padding:24px;border-bottom:1px solid #edf0f2}.empty i,.empty strong,.empty small{display:block;margin:6px auto}.empty i{font-size:28px;color:#aab5bd}.empty strong{color:#65737d;font-size:13px}.empty small{font-size:11px;color:#96a1a9}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.metrics div{display:flex;justify-content:space-between;gap:8px;padding:13px;background:#f3f8f7;border-radius:8px;font-size:12px}.metrics b{color:#168b76;font-size:16px}.footnote{font-size:11px;color:#8a969e;margin:15px 0 0}@media(max-width:850px){.filters,.stats{grid-template-columns:repeat(2,1fr)}.metrics{grid-template-columns:repeat(2,1fr)}}@media(max-width:550px){header{padding:17px;flex-wrap:wrap}h1{font-size:21px}.filters,.stats,.metrics{grid-template-columns:1fr}.panel{padding:15px}.actions{flex-direction:column}}
 `]
})
export class MonthlyReportsComponent {
 station='';year='';month='';date='';message='اختر معايير البحث ثم اضغط تطبيق الفلاتر.';periodLabel='لم يتم تنفيذ البحث';
 readonly stations:string[]=[];
 readonly years=Array.from({length:25},(_,i)=>String(new Date().getFullYear()-i));
 readonly months=[{v:'01',n:'يناير'},{v:'02',n:'فبراير'},{v:'03',n:'مارس'},{v:'04',n:'أبريل'},{v:'05',n:'مايو'},{v:'06',n:'يونيو'},{v:'07',n:'يوليو'},{v:'08',n:'أغسطس'},{v:'09',n:'سبتمبر'},{v:'10',n:'أكتوبر'},{v:'11',n:'نوفمبر'},{v:'12',n:'ديسمبر'}];
 readonly metrics=['متوسط الحرارة','أعلى حرارة','أدنى حرارة','مجموع الأمطار','معدل الرطوبة','متوسط سرعة الرياح','عدد أيام المطر','عدد أيام الصقيع'];
 search(){this.periodLabel=[this.station||'جميع المحطات',this.date||[this.month,this.year].filter(Boolean).join('/')||'جميع الفترات'].join(' · ');this.message='لا توجد نتائج قابلة للعرض: لم يتم توصيل مصدر البيانات بعد.';}
 reset(){this.station='';this.year='';this.month='';this.date='';this.periodLabel='لم يتم تنفيذ البحث';this.message='اختر معايير البحث ثم اضغط تطبيق الفلاتر.';}
}