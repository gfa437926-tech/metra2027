import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';

type AftnView = 'inbox' | 'outbox' | 'compose' | 'channel';

@Component({
  standalone: true,
  selector: 'metra-aftn-console',
  imports: [CommonModule, FormsModule],
  template: `
    <main class="workspace" dir="rtl">
      <header><div><span class="eyebrow">METRA 2027 · الاتصالات الجوية</span><h1>وحدة AFTN</h1>
        <p>إدارة رسائل الاتصالات الجوية ضمن مركز مخوّل مع تتبع التسليم وسجل تدقيق مركزي.</p></div>
        <span class="state">القناة غير متصلة</span>
      </header>
      <div class="warning">لا توجد قناة AFTN خادمية أو API للرسائل في النسخة الحالية. لا يتم استقبال أو إرسال أي حركة من المتصفح.</div>
      <nav class="tabs">
        <button type="button" [class.active]="view==='inbox'" (click)="view='inbox'">الوارد</button>
        <button type="button" [class.active]="view==='outbox'" (click)="view='outbox'">الصادر</button>
        <button type="button" [class.active]="view==='compose'" (click)="view='compose'">إنشاء رسالة</button>
        <button type="button" [class.active]="view==='channel'" (click)="view='channel'">القناة والتدقيق</button>
      </nav>
      @if (view === 'inbox') {
        <section class="panel"><h2>صندوق الوارد</h2><div class="empty"><strong>لا توجد رسائل واردة</strong><p>ستظهر الرسائل بعد التحقق من هوية المركز وصلاحية الاستقبال.</p></div>
          <div class="filters"><span>فترة الاستلام UTC</span><span>رمز المرسل</span><span>الأولوية</span><span>حالة المعالجة</span></div></section>
      } @else if (view === 'outbox') {
        <section class="panel"><h2>صندوق الصادر</h2><div class="empty"><strong>لا توجد رسائل صادرة</strong><p>ستظهر حالة الرسائل وإيصالات التسليم بعد ربط بوابة الإرسال.</p></div>
          <div class="filters"><span>فترة الإنشاء UTC</span><span>جهة الاستقبال</span><span>الأولوية</span><span>حالة التسليم</span></div></section>
      } @else if (view === 'compose') {
        <section class="panel">
          <h2>إنشاء رسالة — معاينة محلية فقط</h2>
          <div class="fields">
            <label>جهة الإرسال / Originator<input [(ngModel)]="origin" name="origin"></label>
            <label>جهة أو جهات الاستقبال<input [(ngModel)]="addressees" name="addressees"></label>
            <label>الأولوية<select [(ngModel)]="priority" name="priority"><option value="SS">SS — أعلى</option><option value="DD">DD — عاجل</option><option value="FF">FF — عادي</option></select></label>
            <label>الموضوع (اختياري)<input [(ngModel)]="subject" name="subject"></label>
          </div>
          <label>نص الرسالة<textarea [(ngModel)]="body" name="body" rows="8" maxlength="10000"></textarea></label>
          <p class="validation" *ngIf="validation">{{ validation }}</p>
          <button type="button" class="secondary" (click)="preview()">معاينة محلية</button>
          <div class="preview" *ngIf="previewText"><h3>معاينة — غير مرسلة</h3><pre>{{ previewText }}</pre></div>
          <button type="button" disabled>إرسال الرسالة — بانتظار القناة الخادمية المعتمدة</button>
          <small>لا يتم فحص القالب أو الترميز وفق معيار الرسائل قبل اعتماد القواعد الرسمية.</small>
        </section>
      } @else {
        <section class="panel"><h2>متطلبات تشغيل القناة</h2>
          <article><strong>قناة خادمية آمنة</strong><p>استقبال وإرسال مع مراقبة الاتصال وإعادة المحاولة.</p></article>
          <article><strong>قوالب معتمدة</strong><p>تعريف صيغ الرسائل والحقول والأولويات وقواعد التحقق.</p></article>
          <article><strong>عزل المركز والمحطة</strong><p>التحقق من نطاق المستخدم قبل قراءة الرسائل أو إنشاء الإرسال.</p></article>
          <article><strong>سجل تدقيق غير قابل للتلاعب</strong><p>تسجيل المنفذ والتوقيت UTC والرسالة وحالة التسليم والسبب.</p></article>
          <article><strong>مراقبة التسليم</strong><p>معرف الرسالة وإقرار الاستلام وحالات الفشل والتكرار.</p></article>
        </section>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.workspace{max-width:1200px;margin:auto;padding:12px}header{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:25px;margin:7px 0}h2{font-size:18px;margin:0 0 12px}.state{height:max-content;background:#fff4df;color:#8c5b12;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700}.warning{background:#fff7e8;border:1px solid #f0dfb9;border-right:4px solid #d49a37;padding:13px;border-radius:9px;margin:14px 0;line-height:1.7}.tabs{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px}.tabs button{border:1px solid #dce5eb;background:#fff;border-radius:8px;padding:9px 13px;color:#506675;cursor:pointer}.tabs button.active{background:#287caf;color:#fff}.panel{background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:18px;display:grid;gap:13px}.empty{border:1px dashed #cddae2;border-radius:10px;background:#f7fafc;padding:24px;text-align:center}.empty p{color:#75848e;margin-top:6px}.filters{display:flex;gap:8px;flex-wrap:wrap}.filters span{background:#f1f5f8;border-radius:7px;padding:8px;font-size:12px;color:#627581}.fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}label{display:grid;gap:7px;font-size:12px;font-weight:700;color:#5e707c}input,select,textarea{width:100%;box-sizing:border-box;border:1px solid #d8e2e8;border-radius:8px;padding:10px;font:inherit}.panel>button{border:0;border-radius:8px;padding:11px;background:#287caf;color:#fff;font:inherit;font-weight:700}.panel>button:disabled{opacity:.55}.secondary{background:#edf5fa!important;color:#287caf!important}.preview{background:#f7fafc;border:1px solid #dce5eb;border-radius:8px;padding:12px}.preview pre{white-space:pre-wrap;direction:ltr;text-align:left;font:12px/1.7 monospace}.validation{color:#9a5b12;font-size:12px}article{padding:12px;border:1px solid #e5edf1;border-radius:9px}article p{color:#70808b;margin:5px 0 0}small{color:#7e8d96}@media(max-width:700px){.fields{grid-template-columns:1fr}}
  `]
})
export class AftnConsoleComponent {
  view: AftnView = 'inbox';
  origin = '';
  addressees = '';
  subject = '';
  body = '';
  priority = 'FF';
  validation = '';
  previewText = '';

  preview(): void {
    const missing: string[] = [];
    if (!this.origin.trim()) missing.push('جهة الإرسال');
    if (!this.addressees.trim()) missing.push('جهة الاستقبال');
    if (!this.body.trim()) missing.push('نص الرسالة');
    if (missing.length) {
      this.validation = `الحقول الناقصة: ${missing.join('، ')}`;
      this.previewText = '';
      return;
    }
    this.validation = 'اكتملت الحقول الأساسية للمعاينة المحلية فقط. لم يتم التحقق من معيار AFTN أو إرسال الرسالة.';
    this.previewText = `المرسل: ${this.origin.trim()}\nالمستقبل: ${this.addressees.trim()}\nالأولوية: ${this.priority}\nالموضوع: ${this.subject.trim()}\n\n${this.body.trim()}`;
  }
}
