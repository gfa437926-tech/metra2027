import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

interface ClimateDraft { id:string; hour:string; date:string; status:'draft'|'submitted'; values:Record<string,string>; }

@Component({
 standalone:true,selector:'metra-climate-reports',imports:[CommonModule],
 template:`
 <div class="page" dir="rtl">
  <header class="hero"><div class="hero-icon"><i class="fa-solid fa-wind"></i></div><div><h1>النشرات الساعية المناخية</h1><p>إدخال البيانات المناخية الساعية وتتبع التغيرات · التوقيت العالمي UTC</p></div><span class="preview">وضع المعاينة</span></header>
  <div class="notice"><i class="fa-solid fa-circle-info"></i><div><strong>نموذج تجريبي مستقل عن قاعدة البيانات.</strong><span>المسودات وحالات الإرسال مؤقتة داخل الصفحة ولا تمثل حفظاً أو اعتماداً فعلياً.</span></div></div>
  <section class="panel identity"><h2><i class="fa-solid fa-user-tie"></i> التعريف بالمحطة والراصد</h2><div class="grid three"><label>المحطة<input name="station" [(value)]="station" placeholder="رمز أو اسم المحطة"></label><label>اسم الراصد<input name="observer" [(value)]="observer" placeholder="اسم الراصد"></label><label>تاريخ الرصد<input type="date" [value]="date" (change)="date=$any($event.target).value"></label></div></section>
  <form #climateForm (submit)="submit($event,climateForm)">
   <section class="panel"><h2><i class="fa-solid fa-clock"></i> المعلومات الأساسية</h2><div class="grid two"><label>التوقيت العالمي المكافئ (UTC)<select name="utcTime" required><option value="">اختر الساعة</option>@for(h of hours;track h){<option [value]="h">{{h}}:00 UTC</option>}</select></label><div class="info">يُستخدم التوقيت العالمي UTC حصراً في تسجيل النشرة. اختر موعد الرصد المحدد في تعليمات المحطة.</div></div></section>
   <section class="panel"><h2><i class="fa-solid fa-temperature-half"></i> درجات الحرارة</h2><div class="grid two">
    <label>درجة الحرارة الجافة (سْ)<input name="dryTemp" required maxlength="5" placeholder="25.5 أو -5.3 أو #" (blur)="formatDecimal($event)"><small>من -20 إلى 60 · صيغة dd.d أو #</small></label>
    <label>درجة الحرارة الرطبة (سْ)<input name="wetTemp" required maxlength="5" placeholder="20.3 أو # " (blur)="formatDecimal($event)"><small>من -20 إلى 60 · صيغة dd.d أو #</small></label>
   </div><p class="relation" *ngIf="relationMessage">{{relationMessage}}</p></section>
   <section class="panel"><h2><i class="fa-solid fa-calculator"></i> الحقول المحسوبة</h2><div class="grid three">
    <label>الرطوبة النسبية المحسوبة (%)<input name="relativeHumidity" required maxlength="3" placeholder="075 أو #" (blur)="formatInteger($event,3)"><small>001–100 أو #</small></label>
    <label>ضغط بخار الماء (ميلبار)<input name="vaporPressure" required maxlength="5" placeholder="18.5 أو #" (blur)="formatDecimal($event)"><small>من -50 إلى 50 · dd.d أو #</small></label>
    <label>درجة الندى (سْ)<input name="dewPoint" required maxlength="5" placeholder="18.2 أو #" (blur)="formatDecimal($event)"><small>dd.d أو #</small></label>
   </div></section>
   <section class="panel"><h2><i class="fa-solid fa-wind"></i> الرياح</h2><div class="grid four">
    <label>اتجاه الرياح السطحية (درجة)<input name="windDirection" required maxlength="2" placeholder="15 أو #" (blur)="formatInteger($event,2)"><small>00–36 أو #</small></label>
    <label>سرعة الرياح السطحية (م/ثا)<input name="windSpeed" required maxlength="2" placeholder="12 أو #" (blur)="formatInteger($event,2)"><small>00–99 أو #</small></label>
    <label>اتجاه المتوسط الساعي للرياح (درجة)<input name="avgWindDirection" required maxlength="2" placeholder="16 أو #" (blur)="formatInteger($event,2)"><small>00–36 أو #</small></label>
    <label>سرعة المتوسط الساعي للرياح (م/ثا)<input name="avgWindSpeed" required maxlength="2" placeholder="10 أو #" (blur)="formatInteger($event,2)"><small>00–99 أو #</small></label>
   </div></section>
   <section class="panel"><h2><i class="fa-solid fa-cloud"></i> التغطية الكلية للسحب</h2><div class="grid two"><label>كمية التغطية الكلية للسحب الكلي<input name="totalCloudCover" required maxlength="1" placeholder="3 أو #" (blur)="formatInteger($event,1)"><small>0–9 أو #</small></label></div></section>
   <section class="panel"><h2><i class="fa-regular fa-note-sticky"></i> ملاحظات الراصد</h2><textarea name="observerNotes" rows="3" placeholder="أي ملاحظات إضافية حول الظروف الجوية..."></textarea><label class="agreement"><input type="checkbox" name="responsibilityAgreement" required> أقر بصحة البيانات المدخلة ومطابقتها لسجل الرصد.</label></section>
   <div class="actions"><button class="primary" type="submit"><i class="fa-solid fa-check-double"></i> التحقق وإنشاء مسودة</button><button class="secondary" type="reset" (click)="clearMessages()">مسح الحقول</button></div>
  </form>
  <section class="feedback error" *ngIf="issues.length"><strong><i class="fa-solid fa-triangle-exclamation"></i> أخطاء التحقق</strong><ul><li *ngFor="let issue of issues">{{issue}}</li></ul></section>
  <section class="feedback success" *ngIf="message" role="status">{{message}}</section>
  <section class="panel drafts" *ngIf="drafts.length"><h2><i class="fa-solid fa-inbox"></i> سجل المسودات التجريبية</h2>@for(d of drafts;track d.id){<article><div><strong>{{d.id}}</strong><p>{{d.date}} · {{d.hour}} UTC · {{station||'محطة غير محددة'}}</p></div><span [class.sent]="d.status==='submitted'">{{d.status==='draft'?'مسودة':'بانتظار المراجعة'}}</span><button *ngIf="d.status==='draft'" (click)="send(d)" type="button">إرسال للمراجعة</button></article>}</section>
  <p class="footnote">حقول الإدخال مطابقة للمعرفات الظاهرة في النموذج الأصلي h_climate_send.html. لا يشمل هذا النموذج حالياً جميع عناصر ترميز النشرة أو إحصائيات المحطة، ويجب استكمال مطابقتها قبل اعتماده تشغيلياً.</p>
 </div>`,
 styles:[`
 :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}.hero{display:flex;align-items:center;gap:16px;padding:23px 26px;background:linear-gradient(135deg,#16a085,#117864);color:#fff;border-radius:14px;margin-bottom:17px}.hero-icon{width:58px;height:58px;border-radius:14px;background:#ffffff25;display:grid;place-items:center;font-size:27px}.hero h1{font-size:25px;margin:0 0 5px}.hero p{margin:0;font-size:13px;opacity:.9}.preview{margin-right:auto;background:#fff3cd;color:#856404;padding:7px 12px;border-radius:7px;font-size:12px;font-weight:700;white-space:nowrap}.notice{display:flex;gap:12px;align-items:center;background:#eaf4fb;color:#245575;padding:13px 16px;border-right:4px solid #3498db;border-radius:8px;margin-bottom:17px}.notice div{display:grid;gap:4px}.notice span{font-size:12px}.panel{background:#fff;border:1px solid #e5eaee;border-radius:12px;padding:21px;margin-bottom:17px;box-shadow:0 5px 18px #2638490a}.panel h2{font-size:17px;margin:0 0 17px;padding-bottom:11px;border-bottom:2px solid #edf1f4}.panel h2 i{color:#16a085;margin-left:8px}.grid{display:grid;gap:14px}.grid.two{grid-template-columns:repeat(2,minmax(0,1fr))}.grid.three{grid-template-columns:repeat(3,minmax(0,1fr))}.grid.four{grid-template-columns:repeat(4,minmax(0,1fr))}.grid label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.grid input,.grid select,textarea{box-sizing:border-box;width:100%;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;background:#fbfcfd;font:inherit;color:#2c3e50;outline:none}.grid input:focus,.grid select:focus,textarea:focus{border-color:#16a085;box-shadow:0 0 0 3px #16a08520}.grid small{font-size:10px;color:#84919a;font-weight:400}.info{background:#eaf4fb;border-radius:8px;padding:13px;color:#245575;font-size:12px;align-self:end}.relation{color:#b7791f;font-size:12px;margin:12px 0 0}.agreement{display:flex;gap:9px;align-items:center;margin-top:15px;background:#f4f8fb;padding:12px;border-radius:8px;font-size:12px}.actions{display:flex;gap:10px;margin-bottom:16px}.actions button,.drafts article button{border:0;border-radius:8px;padding:12px 19px;font:inherit;font-weight:700;cursor:pointer}.primary,.drafts article button{background:#168b76;color:#fff}.secondary{background:#edf1f3;color:#34495e}.feedback{padding:14px 17px;border-radius:9px;margin:14px 0;font-size:13px}.feedback ul{margin:8px 0 0;padding-right:22px}.error{background:#fff0ef;border-right:4px solid #dc3545;color:#9d2929}.success{background:#eaf7ef;border-right:4px solid #27ae60;color:#218348}.drafts article{display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #edf0f2}.drafts article div{flex:1}.drafts article p{font-size:11px;color:#82909a;margin:4px 0 0}.drafts article span{font-size:11px;background:#edf0f2;padding:6px 10px;border-radius:20px}.drafts article span.sent{background:#fff3cd;color:#946200}.drafts article button{padding:8px 12px;font-size:11px}.footnote{font-size:11px;color:#8a969e;margin-top:17px}@media(max-width:900px){.grid.four{grid-template-columns:repeat(2,minmax(0,1fr))}.grid.three{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.hero{padding:17px;flex-wrap:wrap}.hero h1{font-size:21px}.grid.two,.grid.three,.grid.four{grid-template-columns:1fr}.panel{padding:15px}.actions{flex-direction:column}.drafts article{align-items:flex-start;flex-wrap:wrap}}
 `]
})
export class ClimateReportsComponent {
 station='';observer='';date=new Date().toISOString().slice(0,10);
 readonly hours=['00','01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23'];
 issues:string[]=[];message='';drafts:ClimateDraft[]=[];private sequence=1;
 relationMessage='';
 formatDecimal(event:FocusEvent):void{const f=event.target as HTMLInputElement;let v=f.value.trim();if(!v||v==='#')return;const negative=v.startsWith('-');v=v.replace(/[^0-9.]/g,'');const p=v.split('.');const whole=(p[0]||'0').slice(0,2);const fraction=(p[1]||'0').slice(0,1);f.value=(negative?'-':'')+whole+'.'+fraction;}
 formatInteger(event:FocusEvent,width:number):void{const f=event.target as HTMLInputElement;let v=f.value.trim();if(!v||v==='#')return;f.value=v.replace(/\D/g,'').slice(0,width).padStart(width,'0');}
 clearMessages():void{this.issues=[];this.message='';this.relationMessage='';}
 submit(event:Event,form:HTMLFormElement):void{
  event.preventDefault();this.clearMessages();if(!form.reportValidity())return;
  const fd=new FormData(form);const values:Record<string,string>={};fd.forEach((v,k)=>{if(typeof v==='string')values[k]=v.trim();});
  const temp=['dryTemp','wetTemp','vaporPressure','dewPoint'];
  for(const k of temp){const v=values[k]??'';const label=this.label(k);if(v==='#')continue;if(!/^-?\d{1,2}\.\d$/.test(v)){this.issues.push(label+': التنسيق المطلوب ±dd.d أو #.');continue;}const n=Number(v);const min=k==='vaporPressure'?-50:-20;const max=k==='vaporPressure'?50:60;if(n<min||n>max)this.issues.push(label+': القيمة خارج المجال '+min+' إلى '+max+'.');}
  const rules:[string,RegExp,number,number,string][]=[['relativeHumidity',/^\d{3}$/,1,100,'الرطوبة النسبية'],['windDirection',/^\d{2}$/,0,36,'اتجاه الرياح'],['avgWindDirection',/^\d{2}$/,0,36,'اتجاه المتوسط الساعي للرياح (درجة)'],['windSpeed',/^\d{2}$/,0,99,'سرعة الرياح'],['avgWindSpeed',/^\d{2}$/,0,99,'سرعة المتوسط الساعي للرياح (م/ثا)'],['totalCloudCover',/^\d$/,0,9,'التغطية الكلية للسحب']];
  for(const [k,pattern,min,max,label] of rules){const v=values[k]??'';if(v==='#')continue;const n=Number(v);if(!pattern.test(v)||n<min||n>max)this.issues.push(label+': قيمة غير صحيحة، أو # عند عدم توفرها.');}
  const dry=values['dryTemp'],wet=values['wetTemp'];if(dry&&wet&&dry!=='#'&&wet!=='#'&&Number(dry)<Number(wet)){this.relationMessage='درجة الحرارة الجافة يجب أن تكون مساوية أو أكبر من درجة الحرارة الرطبة';this.issues.push(this.relationMessage);}
  if(this.issues.length)return;
  const id='C-'+String(this.sequence++).padStart(4,'0');this.drafts.unshift({id,hour:values['utcTime'],date:this.date,status:'draft',values});this.message='اجتازت النشرة التحقق الأولي وأُنشئت مسودة مؤقتة في الذاكرة.';form.reset();
 }
 send(d:ClimateDraft):void{d.status='submitted';this.message='تم تغيير حالة '+d.id+' في المعاينة فقط.';}
 private label(k:string):string{return ({dryTemp:'الحرارة الجافة',wetTemp:'الحرارة الرطبة',vaporPressure:'ضغط بخار الماء',dewPoint:'درجة الندى'} as Record<string,string>)[k]??k;}
}