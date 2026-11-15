import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

type WorkspaceKey = 'climatol' | 'records' | 'comparison' | 'ai' | 'quality';
type WorkspaceTab = 'overview' | 'work' | 'review' | 'history';

@Component({
  selector: 'metra-scientific-workspaces',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header class="hero">
        <div>
          <p class="eyebrow">METRA 2027 · المختبر العلمي</p>
          <h1>{{ config().title }}</h1>
          <p class="subtitle">{{ config().description }}</p>
        </div>
        <div class="status"><span></span> واجهة جاهزة · الخدمة الخلفية غير موصولة</div>
      </header>

      <nav class="workspace-nav" aria-label="مساحات العمل العلمية">
        <a routerLink="/scientific/climatol" [class.active]="key() === 'climatol'">التجانس المناخي</a>
        <a routerLink="/scientific/records" [class.active]="key() === 'records'">أرشيف السجلات</a>
        <a routerLink="/scientific/comparison" [class.active]="key() === 'comparison'">مقارنة المصادر</a>
        <a routerLink="/scientific/quality" [class.active]="key() === 'quality'">ضبط الجودة</a>
        <a routerLink="/scientific/ai" [class.active]="key() === 'ai'">مختبر الذكاء الاصطناعي</a>
      </nav>

      <div class="notice" role="status">
        <strong>وضع آمن للعرض والتصميم</strong>
        <span>لا يتم إنشاء نتائج علمية أو قراءات تجريبية. رفع الملفات، تشغيل OCR/CLIMATOL، التدريب والاعتماد تتطلب خدمات الخادم والصلاحيات التي لم تُربط بعد.</span>
      </div>

      <div class="tabs" role="tablist" aria-label="أقسام مساحة العمل">
        <button *ngFor="let tab of tabs" [class.selected]="activeTab() === tab.id" (click)="activeTab.set(tab.id)" role="tab" [attr.aria-selected]="activeTab() === tab.id">{{ tab.label }}</button>
      </div>

      <ng-container [ngSwitch]="activeTab()">
        <section *ngSwitchCase="'overview'" class="content">
          <div class="metrics">
            <article class="metric"><span>المهام النشطة</span><b>—</b><small>بانتظار اتصال API</small></article>
            <article class="metric"><span>العناصر قيد المراجعة</span><b>—</b><small>لا توجد بيانات محمّلة</small></article>
            <article class="metric"><span>العناصر المعتمدة</span><b>—</b><small>لا توجد بيانات محمّلة</small></article>
            <article class="metric"><span>حالة الخدمة</span><b class="muted">غير متصل</b><small>لا توجد نتائج وهمية</small></article>
          </div>
          <div class="section-head"><div><h2>{{ config().overviewTitle }}</h2><p>مسارات العمل المتاحة ضمن هذه الوحدة</p></div></div>
          <div class="cards">
            <article class="card" *ngFor="let item of config().workflows">
              <div class="card-icon">{{ item.icon }}</div><h3>{{ item.title }}</h3><p>{{ item.description }}</p>
              <span class="chip">{{ item.status }}</span>
            </article>
          </div>
        </section>

        <section *ngSwitchCase="'work'" class="content">
          <div class="section-head"><div><h2>{{ config().workTitle }}</h2><p>نموذج إعداد العملية — لن يبدأ التنفيذ قبل تفعيل الخدمة والتحقق من الصلاحيات.</p></div></div>
          <div class="form-grid">
            <label>المحطة / مجموعة المحطات<input type="text" placeholder="اختر المحطة بعد تحميل دليل المحطات" disabled></label>
            <label>العنصر المناخي / نوع السجل<select disabled><option>يتم تحميل الخيارات من الخادم</option></select></label>
            <label>من تاريخ<input type="date" disabled></label>
            <label>إلى تاريخ<input type="date" disabled></label>
            <label class="wide">ملاحظات العملية<textarea rows="3" placeholder="تظهر هنا ملاحظات الإعداد..." disabled></textarea></label>
          </div>
          <div class="actions"><button disabled>تشغيل العملية — الخدمة غير مفعّلة</button><span>لن يتم إرسال أي طلب أو تعديل بيانات من هذه الواجهة حالياً.</span></div>
        </section>

        <section *ngSwitchCase="'review'" class="content">
          <div class="section-head"><div><h2>مراجعة واعتماد النتائج</h2><p>سجل المراجعة البشرية، أسباب القرار، والفروقات قبل وبعد المعالجة.</p></div></div>
          <div class="empty"><div>⌕</div><h3>لا توجد عناصر مراجعة محمّلة</h3><p>تظهر طلبات المراجعة هنا بعد ربط واجهة API وتطبيق صلاحيات المحطة والدور.</p></div>
        </section>

        <section *ngSwitchCase="'history'" class="content">
          <div class="section-head"><div><h2>سجل العمليات والإصدارات</h2><p>تتبع غير قابل للمحو لكل عملية وملف ومستخدم وإصدار نموذج.</p></div></div>
          <div class="empty"><div>◷</div><h3>السجل بانتظار ربط خدمة التدقيق</h3><p>سيتم عرض معرف العملية وبصمة الملفات والمنفذ والتوقيت والقرار عند توفر الخدمة.</p></div>
        </section>
      </ng-container>
      <footer>الملاحظات الخام محفوظة دون تعديل · المخرجات العلمية مشتقة وتحتاج اعتماداً بشرياً</footer>
    </section>
  `,
  styles: [`
    :host{display:block;color:#173247}.page{max-width:1440px;margin:0 auto;padding:30px clamp(16px,3vw,42px) 48px;font-family:Tahoma,Arial,sans-serif}
    .hero{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;flex-wrap:wrap;padding:10px 0 24px}.eyebrow{color:#168b91;font-size:12px;font-weight:800;letter-spacing:.4px;margin:0 0 9px}.hero h1{font-size:clamp(24px,3vw,34px);margin:0;color:#142f45}.subtitle{color:#687d8d;margin:10px 0 0;max-width:760px;line-height:1.8}
    .status{background:#eef6f7;color:#315e68;border:1px solid #d4e8e9;border-radius:999px;padding:9px 14px;font-size:12px;display:flex;align-items:center;gap:8px}.status span{width:8px;height:8px;border-radius:50%;background:#c18a39}
    .workspace-nav{display:flex;gap:8px;overflow:auto;padding:8px 0 16px;border-bottom:1px solid #e5edf1}.workspace-nav a{white-space:nowrap;text-decoration:none;padding:11px 15px;border-radius:10px;color:#597181;font-size:13px;font-weight:700}.workspace-nav a.active{background:#153b53;color:white}
    .notice{display:flex;gap:12px;align-items:flex-start;background:#fff8e9;border:1px solid #f1dfb7;border-radius:12px;padding:14px 16px;margin:20px 0;color:#725526;font-size:12px;line-height:1.8}.notice strong{white-space:nowrap}
    .tabs{display:flex;gap:6px;margin:18px 0}.tabs button{border:1px solid #dce6eb;background:white;color:#526c7c;border-radius:8px;padding:10px 16px;cursor:pointer}.tabs button.selected{background:#e7f2f3;color:#146e76;border-color:#b9dcdd;font-weight:800}
    .content{padding:8px 0}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}.metric,.card{background:white;border:1px solid #e3ebef;border-radius:14px;padding:18px;box-shadow:0 5px 20px rgba(22,55,75,.035)}.metric span,.metric small{display:block;color:#738796;font-size:12px}.metric b{display:block;font-size:27px;margin:12px 0;color:#183b51}.metric b.muted{font-size:17px;color:#a16d25}.metric small{font-size:11px}
    .section-head{display:flex;justify-content:space-between;align-items:center;margin:24px 0 14px}.section-head h2{font-size:19px;margin:0;color:#18384d}.section-head p{font-size:12px;color:#7a8d99;margin:7px 0 0}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.card-icon{width:40px;height:40px;border-radius:11px;background:#edf5f6;display:grid;place-items:center;font-size:19px}.card h3{font-size:15px;margin:14px 0 8px}.card p{font-size:12px;color:#708492;line-height:1.8;min-height:44px}.chip{display:inline-block;background:#f2f5f7;border-radius:20px;padding:5px 9px;color:#667d8a;font-size:10px}
    .form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;background:white;border:1px solid #e3ebef;border-radius:14px;padding:20px}.form-grid label{display:flex;flex-direction:column;gap:8px;color:#496273;font-size:12px}.form-grid .wide{grid-column:1/-1}.form-grid input,.form-grid select,.form-grid textarea{border:1px solid #dfe8ed;border-radius:8px;padding:11px;background:#f6f8f9;color:#8a9aa4}.actions{display:flex;align-items:center;gap:14px;margin-top:16px;flex-wrap:wrap}.actions button{border:0;background:#9aaab3;color:white;border-radius:8px;padding:11px 16px}.actions span{font-size:11px;color:#82939e}
    .empty{text-align:center;background:white;border:1px dashed #d7e2e8;border-radius:14px;padding:48px 18px;color:#718592}.empty div{font-size:30px;color:#91a7b4}.empty h3{font-size:16px;color:#35556a}.empty p{font-size:12px}.page footer{border-top:1px solid #e6edf1;margin-top:30px;padding-top:16px;color:#81929d;font-size:11px}
    @media(max-width:900px){.metrics{grid-template-columns:repeat(2,minmax(0,1fr))}.cards{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.metrics,.cards,.form-grid{grid-template-columns:1fr}.form-grid .wide{grid-column:auto}.notice{flex-direction:column}.hero{padding-top:0}}
  `]
})
export class ScientificWorkspacesComponent {
  private readonly route = inject(ActivatedRoute);
  readonly key = signal<WorkspaceKey>((this.route.snapshot.data['workspace'] ?? 'quality') as WorkspaceKey);
  readonly activeTab = signal<WorkspaceTab>('overview');
  readonly tabs = [
    { id: 'overview' as const, label: 'نظرة عامة' },
    { id: 'work' as const, label: 'إعداد عملية' },
    { id: 'review' as const, label: 'المراجعة والاعتماد' },
    { id: 'history' as const, label: 'السجل والإصدارات' }
  ];
  private readonly configs: Record<WorkspaceKey, any> = {
    climatol: { title: 'التجانس المناخي و CLIMATOL', description: 'إدارة السلاسل المناخية، كشف الانقطاعات، اختيار المحطات المرجعية، تشغيل التجانس ومراجعة السلاسل المصححة.', overviewTitle: 'دورة عمل التجانس المناخي', workTitle: 'إعداد مهمة تجانس جديدة', workflows: [
      { icon: '⌁', title: 'تهيئة السلاسل', description: 'اختيار المتغير والفترة الزمنية وفحص الاستمرارية والقيم المفقودة.', status: 'يتطلب ربط البيانات' },
      { icon: '⌖', title: 'كشف نقاط الانقطاع', description: 'تشخيص الانقطاعات والقيم الشاذة ومراجعة الأدلة المناخية.', status: 'يتطلب محرك التحليل' },
      { icon: '⇄', title: 'المحطات المرجعية', description: 'اختيار المحطات المقارنة وقياس الارتباط والتجانس المكاني.', status: 'يتطلب دليل المحطات' },
      { icon: '◉', title: 'تشغيل CLIMATOL', description: 'إرسال مهمة معزولة وحفظ المخرجات كملفات مشتقة منفصلة.', status: 'محرك R غير موصول' },
      { icon: '✓', title: 'اعتماد السلاسل', description: 'مراجعة التعديلات وتوثيق سبب قبول أو رفض كل تغيير.', status: 'يتطلب صلاحية اعتماد' },
      { icon: '▤', title: 'المناخ والمؤشرات', description: 'المجاميع الشهرية والموسمية والسنوية والاتجاهات والمؤشرات.', status: 'يتطلب خدمة مناخية' }
    ] },
    records: { title: 'أرشيف السجلات الورقية والميكانيكية', description: 'حفظ صور السجلات الأصلية وربطها بالمحطة والتاريخ والعنصر والجهاز مع سجل مصدر وبصمة رقمية.', overviewTitle: 'مصادر السجلات', workTitle: 'إضافة سجل مصور', workflows: [
      { icon: '▤', title: 'السجلات الورقية', description: 'صور دفاتر الرصد والنماذج الورقية مع بيانات المصدر والصفحة.', status: 'رفع الملفات غير موصول' },
      { icon: '⌁', title: 'Thermograph', description: 'أرشفة مخططات درجة الحرارة الميكانيكية.', status: 'بانتظار الربط' },
      { icon: '⌁', title: 'Hygrograph', description: 'أرشفة مخططات الرطوبة وتوثيق الجهاز والفترة.', status: 'بانتظار الربط' },
      { icon: '⌁', title: 'Barograph', description: 'أرشفة مخططات الضغط الجوي.', status: 'بانتظار الربط' },
      { icon: '⌁', title: 'Pluviograph', description: 'أرشفة مخططات الهطول ومقاطع التسجيل.', status: 'بانتظار الربط' },
      { icon: '▣', title: 'سلامة الملفات', description: 'حفظ checksum والنسخة الأصلية وسجل من رفع الملف.', status: 'يتطلب خدمة التخزين' }
    ] },
    comparison: { title: 'مقارنة مصادر الرصد الثلاثية', description: 'عرض متزامن للسجل الورقي والمسجل الميكانيكي والرصد الإلكتروني مع الفروقات والحدود المقبولة والمراجعة البشرية.', overviewTitle: 'مصادر المقارنة والتحقق', workTitle: 'إعداد مقارنة جديدة', workflows: [
      { icon: '▤', title: 'المصدر الورقي', description: 'القيمة المكتوبة يدوياً والوقت والصفحة وموضع القراءة.', status: 'مصدر غير موصول' },
      { icon: '⌁', title: 'المسجل الميكانيكي', description: 'القيمة المستخرجة من منحنى الجهاز مع إحداثيات الصورة.', status: 'استخراج غير موصول' },
      { icon: '◉', title: 'الرصد الإلكتروني', description: 'القيمة المعتمدة من سجل الرصد الرقمي للفترة نفسها.', status: 'مصدر غير موصول' },
      { icon: '⇄', title: 'حساب الفروقات', description: 'الفروق المطلقة والنسبية والتسامحات وعدم اليقين.', status: 'يتطلب محرك مقارنة' },
      { icon: '▧', title: 'تراكب الصور', description: 'عرض صورة الأصل والمنحنى ونقاط القراءة بجانب القيم.', status: 'عارض غير موصول' },
      { icon: '✓', title: 'قرار المراجع', description: 'قبول أو رفض أو طلب إعادة قراءة مع سبب موثق.', status: 'يتطلب خدمة اعتماد' }
    ] },
    ai: { title: 'مختبر الذكاء الاصطناعي', description: 'إدارة مجموعات البيانات والوسم والتقسيم والتدريب والتقييم وسجل إصدارات النماذج والنشر المنضبط.', overviewTitle: 'خط إنتاج النماذج', workTitle: 'إعداد تجربة تدريب', workflows: [
      { icon: '▦', title: 'مجموعات البيانات', description: 'إصدارات datasets ومصادرها وحقوق استخدامها وبصماتها.', status: 'يتطلب مستودع بيانات' },
      { icon: '✎', title: 'الوسم والتصحيح', description: 'تصحيح OCR وتحديد منحنيات وأزمنة القراءات يدوياً.', status: 'أداة الوسم غير موصولة' },
      { icon: '⇥', title: 'تقسيم البيانات', description: 'تقسيم train/validation/test مع منع تسرب المحطة والزمن.', status: 'يتطلب pipeline' },
      { icon: '⚙', title: 'التدريب والتقييم', description: 'تتبع التجارب ومقاييس الدقة والاستدعاء والخطأ وعدم اليقين.', status: 'لا يوجد تدريب مفعّل' },
      { icon: '◈', title: 'سجل النماذج', description: 'نسخ النماذج وبصماتها وبيانات التدريب وتقارير التقييم.', status: 'السجل غير موصول' },
      { icon: '✓', title: 'اعتماد ونشر', description: 'موافقة بشرية ونشر تدريجي ومراقبة الانحراف وإعادة التدريب.', status: 'النشر غير مفعّل' }
    ] },
    quality: { title: 'مركز تدقيق جودة البيانات والصور', description: 'مراجعة القيم المستخرجة، رصد التناقضات، تتبع التصحيحات وحماية البيانات الخام.', overviewTitle: 'مسارات ضبط الجودة', workTitle: 'إعداد فحص جودة', workflows: [
      { icon: '⌕', title: 'استخراج OCR', description: 'قراءة الأرقام والتواريخ من الصور مع مواضع القراءة ودرجة الثقة.', status: 'OCR غير موصول' },
      { icon: '⌁', title: 'رقمنة المنحنيات', description: 'استخراج نقاط السلاسل من مخططات الأجهزة الميكانيكية.', status: 'Digitizer غير موصول' },
      { icon: '⚑', title: 'كشف الشذوذ', description: 'قواعد تحقق فيزيائية وزمنية ومقارنة مصادر مستقلة.', status: 'محرك الجودة غير موصول' },
      { icon: '⇄', title: 'تسوية الاختلافات', description: 'تجميع الفروقات وتعيينها لمراجع مختص.', status: 'قائمة المراجعة غير موصولة' },
      { icon: '◷', title: 'تاريخ التعديلات', description: 'حفظ القيمة الأصلية والمصححة والسبب والمنفذ والتوقيت.', status: 'سجل التدقيق غير موصول' },
      { icon: '▣', title: 'التقارير', description: 'تقارير اكتمال البيانات وجودة الاستخراج ونتائج المراجعة.', status: 'التقارير غير موصولة' }
    ] }
  };
  readonly config = computed(() => this.configs[this.key()]);
}
