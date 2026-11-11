import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';

type AiView = 'home' | 'analysis' | 'anomalies' | 'reports' | 'governance';

@Component({
  standalone: true,
  selector: 'metra-ai-workspace',
  imports: [CommonModule, FormsModule],
  template: `
    <main class="workspace" dir="rtl">
      <header class="head">
        <div><span class="eyebrow">METRA 2027 · التحليل الذكي</span><h1>مساحة الذكاء الاصطناعي</h1>
          <p>تحليل مساعد للبيانات الجوية مع توثيق المصدر والفترة وإصدار النموذج وعدم اليقين.</p></div>
        <span class="state">واجهة جاهزة · التنفيذ محجوب</span>
      </header>
      <div class="warning" role="status">لا يوجد AI Gateway مربوط حالياً. لن تُعرض نتائج مصطنعة ولن تُرسل بيانات إلى مزود خارجي من المتصفح.</div>
      <nav class="tabs" aria-label="أقسام الذكاء الاصطناعي">
        <button type="button" [class.active]="view==='home'" (click)="view='home'">الرئيسية</button>
        <button type="button" [class.active]="view==='analysis'" (click)="view='analysis'">التحليل</button>
        <button type="button" [class.active]="view==='anomalies'" (click)="view='anomalies'">الشذوذ</button>
        <button type="button" [class.active]="view==='reports'" (click)="view='reports'">التقارير</button>
        <button type="button" [class.active]="view==='governance'" (click)="view='governance'">الحوكمة</button>
      </nav>

      @if (view === 'home') {
        <section class="grid">
          <article><h2>تحليل السلاسل الزمنية</h2><p>فحص الاتجاهات والفجوات والتغيرات ضمن المحطات المصرح بها.</p></article>
          <article><h2>تفسير قواعد الجودة</h2><p>تفسير سبب إطلاق قاعدة فيزيائية أو رياضية مع إصدار القاعدة.</p></article>
          <article><h2>اكتشاف الشذوذ</h2><p>اقتراح حالات للمراجعة البشرية دون تعديل السجلات الأصلية.</p></article>
          <article><h2>تلخيص النشرات</h2><p>تلخيص موثق للمصدر والفترة مع فصل الرصد عن الاستنتاج.</p></article>
        </section>
      } @else if (view === 'analysis') {
        <section class="panel">
          <h2>إعداد طلب التحليل</h2>
          <div class="fields">
            <label>نوع المهمة<select [(ngModel)]="task" name="task">
              <option value="explain">تفسير حالة جوية</option><option value="trend">تحليل اتجاه زمني</option>
              <option value="quality">تفسير جودة البيانات</option><option value="summary">تلخيص نشرة</option><option value="compare">مقارنة محطات</option>
            </select></label>
            <label>نطاق البيانات<select [(ngModel)]="source" name="source">
              <option value="authorized">المحطات المصرح بها فقط</option><option value="observations">رصدات محددة</option><option value="bulletins">نشرات معتمدة</option>
            </select></label>
            <label>الفترة الزمنية<select [(ngModel)]="period" name="period">
              <option value="24h">آخر 24 ساعة</option><option value="7d">آخر 7 أيام</option><option value="30d">آخر 30 يوماً</option>
            </select></label>
          </div>
          <label>سؤال المختص<textarea [(ngModel)]="prompt" name="prompt" rows="5" maxlength="4000" placeholder="اكتب السؤال أو تعليمات التحليل دون بيانات شخصية أو أسرار تشغيلية."></textarea></label>
          <button type="button" disabled>تنفيذ التحليل — بانتظار AI Gateway</button>
          <small>الإعدادات محلية في الصفحة فقط؛ لم يتم إرسال السؤال أو قراءة بيانات.</small>
        </section>
      } @else if (view === 'anomalies') {
        <section class="panel"><h2>مركز الحالات الشاذة</h2><div class="empty"><strong>لا توجد نتائج متاحة</strong><p>يظهر هذا القسم بعد ربط محرك التحليل الخادمي. لا توجد قياسات شاذة تجريبية.</p></div>
          <ul><li>فحص الحدود والعلاقات الفيزيائية.</li><li>مقارنة زمنية بخط أساس معتمد.</li><li>مقارنة مكانية تراعي الارتفاع والإحداثيات وجودة القياس.</li></ul>
        </section>
      } @else if (view === 'reports') {
        <section class="panel"><h2>تقارير التحليل</h2><div class="empty"><strong>لا توجد تقارير مولدة</strong><p>تتطلب التقارير API يسجل المصدر والفترة وبصمة البيانات وإصدار النموذج.</p></div></section>
      } @else {
        <section class="panel"><h2>حوكمة الذكاء الاصطناعي</h2>
          <ul><li>جميع الطلبات تمر عبر ASP.NET Core مع صلاحيات المحطة.</li><li>تسجيل هوية المنفذ والمصدر والفترة والنموذج.</li><li>لا اعتماد تلقائي ولا تعديل للرصدات الأصلية.</li><li>تقييم الإصدارات وإمكانية التراجع ومراجعة بشرية.</li><li>عدم وضع مفاتيح مزودي النماذج في Angular.</li></ul>
        </section>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.workspace{max-width:1200px;margin:0 auto;padding:12px}
    .head{display:flex;justify-content:space-between;gap:16px;align-items:flex-start;flex-wrap:wrap}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:26px;margin:7px 0}h2{font-size:18px;margin:0 0 12px}p{color:#6e7e88;line-height:1.8;margin:0}.state{background:#edf5fa;color:#287caf;border-radius:8px;padding:9px 12px;font-size:12px;font-weight:700}
    .warning{background:#fff7e8;border:1px solid #f0dfb9;border-right:4px solid #d49a37;border-radius:9px;padding:14px;margin:16px 0;line-height:1.7}
    .tabs{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:14px}.tabs button{border:1px solid #dce5eb;border-radius:8px;background:#fff;padding:9px 14px;color:#506675;cursor:pointer}.tabs button.active{background:#287caf;color:#fff;border-color:#287caf}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px}.grid article,.panel{background:#fff;border:1px solid #e4ebef;border-radius:12px;padding:18px;box-shadow:0 4px 15px #21374708}.grid h2{font-size:16px}
    .panel{display:grid;gap:14px}.fields{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}label{display:grid;gap:7px;font-size:12px;font-weight:700;color:#5e707c}input,select,textarea{width:100%;box-sizing:border-box;border:1px solid #d8e2e8;border-radius:8px;padding:10px;font:inherit;background:#fff}button:disabled{opacity:.55;cursor:not-allowed}.panel>button{border:0;border-radius:8px;padding:11px;background:#287caf;color:#fff;font:inherit;font-weight:700}.panel small{color:#82909a}.empty{background:#f7fafc;border:1px dashed #cddae2;border-radius:10px;padding:24px;text-align:center}.empty p{margin-top:6px}li{line-height:2;color:#506675}
    @media(max-width:720px){.fields{grid-template-columns:1fr}}
  `]
})
export class AiWorkspaceComponent {
  view: AiView = 'home';
  task = 'explain';
  source = 'authorized';
  period = '24h';
  prompt = '';
}
