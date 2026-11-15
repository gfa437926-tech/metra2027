import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

type WorkspaceKey = 'climatol' | 'records' | 'comparison' | 'ai' | 'quality';
type Panel = 'overview' | 'setup' | 'review' | 'reports';

interface WorkItem { title: string; description: string; status: string; }
interface WorkspaceConfig {
  title: string; subtitle: string; purpose: string;
  workflows: WorkItem[]; setupTitle: string; setupFields: string[];
  reviewTitle: string; reviewSteps: string[]; reports: string[];
}
@Component({
  selector: 'metra-scientific-detail',
  standalone: true,
  imports: [CommonModule, RouterLink],
  template: `
    <main class="shell" dir="rtl">
      <header class="hero">
        <div><span class="eyebrow">METRA 2027 · بيئة العمل العلمية</span><h1>{{ config().title }}</h1><p>{{ config().subtitle }}</p></div>
        <span class="service-state"><i></i> الواجهة متاحة · تكامل الخدمات قيد التنفيذ</span>
      </header>
      <nav class="module-nav" aria-label="الوحدات العلمية">
        <a routerLink="/scientific/climatol" [class.active]="key()==='climatol'">CLIMATOL</a>
        <a routerLink="/scientific/records" [class.active]="key()==='records'">أرشيف السجلات</a>
        <a routerLink="/scientific/comparison" [class.active]="key()==='comparison'">مقارنة المصادر</a>
        <a routerLink="/scientific/quality" [class.active]="key()==='quality'">ضبط الجودة</a>
        <a routerLink="/scientific/ai" [class.active]="key()==='ai'">مختبر AI</a>
      </nav>
      <section class="safety"><b>حدود التشغيل الحالية</b><span>هذه واجهة إدارة ومراجعة. لا يتم رفع ملفات أو تشغيل OCR أو CLIMATOL أو تدريب نموذج أو اعتماد نتيجة قبل توصيل الخدمة الخلفية والتحقق من الصلاحيات. لا تُستبدل البيانات الخام بالمخرجات المشتقة.</span></section>
      <nav class="tabs" aria-label="أقسام الوحدة">
        <button [class.chosen]="panel()==='overview'" (click)="panel.set('overview')">نظرة عامة</button>
        <button [class.chosen]="panel()==='setup'" (click)="panel.set('setup')">إعداد العمل</button>
        <button [class.chosen]="panel()==='review'" (click)="panel.set('review')">المراجعة والاعتماد</button>
        <button [class.chosen]="panel()==='reports'" (click)="panel.set('reports')">النتائج والتقارير</button>
      </nav>
      @if (panel()==='overview') {
        <section class="metrics">
          <article><small>المهام النشطة</small><strong>—</strong><span>بانتظار API</span></article>
          <article><small>قيد المراجعة</small><strong>—</strong><span>لا توجد بيانات محمّلة</span></article>
          <article><small>المعتمد</small><strong>—</strong><span>لا توجد بيانات محمّلة</span></article>
          <article><small>حالة المعالجة</small><strong class="pending">غير متصل</strong><span>لا توجد نتائج تجريبية</span></article>
        </section>
        <section class="section-title"><div><h2>{{ config().purpose }}</h2><p>مسارات العمل والأدوات التابعة لهذه الوحدة</p></div></section>
        <section class="cards">
          @for (item of config().workflows; track item.title) {
            <article class="work-card"><div class="glyph">◇</div><h3>{{ item.title }}</h3><p>{{ item.description }}</p><span class="tag">{{ item.status }}</span></article>
          }
        </section>
      }
      @if (panel()==='setup') {
        <section class="panel">
          <div class="section-title"><div><h2>{{ config().setupTitle }}</h2><p>يمكن إعداد مسودة محلية لاستكمالها بعد ربط الخدمة؛ لا يتم إرسالها أو حفظها على الخادم.</p></div></div>
          <div class="form-grid">
            @for (field of config().setupFields; track field; let i = $index) {
              <label>{{ field }}
                @if (i===0) { <select><option>اختر من دليل البيانات عند الاتصال</option><option disabled>لا توجد بيانات محملة</option></select> }
                @else if (i===1) { <select><option>اختر النوع أو المتغير</option><option disabled>تُحمّل الخيارات من API</option></select> }
                @else if (field.toLowerCase().includes('تاريخ') || field.toLowerCase().includes('من ') || field.toLowerCase().includes('إلى ')) { <input type="date" /> }
                @else { <input type="text" [placeholder]="'أدخل ' + field" /> }
              </label>
            }
            <label class="wide">ملاحظات وسياق العمل<textarea rows="3" placeholder="اكتب الملاحظات والمنهجية أو سبب الفحص"></textarea></label>
          </div>
          <div class="actions"><button (click)="prepareDraft()">تجهيز مسودة محلية</button><span>{{ draftMessage() || 'لا يتم الحفظ أو التشغيل قبل تفعيل API.' }}</span></div>
        </section>
      }
      @if (panel()==='review') {
        <section class="panel">
          <div class="section-title"><div><h2>{{ config().reviewTitle }}</h2><p>قائمة المراجعة تعرض لاحقاً العناصر الحقيقية من الخدمة مع المصدر والإصدار والأثر.</p></div></div>
          <div class="review-grid">
            @for (step of config().reviewSteps; track step; let i=$index) {
              <article><b>{{ i+1 }}</b><div><h3>{{ step }}</h3><p>بانتظار بيانات موثقة وخدمة مراجعة</p></div><span>غير محمّل</span></article>
            }
          </div>
          <div class="empty"><strong>لا توجد عناصر مراجعة محمّلة</strong><p>ستظهر هنا القرارات وأسباب القبول أو الرفض وهوية المراجع والتوقيت وبصمة المصدر.</p></div>
        </section>
      }
      @if (panel()==='reports') {
        <section class="panel">
          <div class="section-title"><div><h2>النتائج والتقارير</h2><p>مساحات عرض جاهزة لنتائج موثقة؛ لا تُعرض مؤشرات مصطنعة.</p></div></div>
          <div class="cards">
            @for (report of config().reports; track report) {
              <article class="work-card"><div class="glyph">▤</div><h3>{{ report }}</h3><p>يُنشأ التقرير من بيانات الخدمة المعتمدة مع مرجع المصدر وإصدار المعالجة.</p><span class="tag">بانتظار الربط</span></article>
            }
          </div>
        </section>
      }
      <footer>METRA 2027 · حفظ المصدر الأصلي · تتبع الإصدارات · اعتماد بشري للمخرجات العلمية</footer>
    </main>
  `,
  styles: [`
    :host{display:block;color:#18364a}.shell{max-width:1500px;margin:auto;padding:26px clamp(14px,3vw,40px) 42px;font-family:Tahoma,Arial,sans-serif}
    .hero{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;flex-wrap:wrap;padding:8px 0 22px}.eyebrow{font-size:11px;color:#13838a;font-weight:800}.hero h1{font-size:clamp(24px,3vw,35px);margin:10px 0;color:#12334a}.hero p{margin:0;color:#6d8290;line-height:1.8;max-width:780px;font-size:13px}
    .service-state{white-space:nowrap;background:#fff5e4;color:#886322;border:1px solid #f0dfbd;border-radius:30px;padding:9px 13px;font-size:11px}.service-state i{display:inline-block;width:7px;height:7px;border-radius:50%;background:#c08a34;margin-left:6px}
    .module-nav,.tabs{display:flex;gap:7px;overflow:auto;padding:8px 0 13px}.module-nav{border-bottom:1px solid #e2ebef}.module-nav a{white-space:nowrap;text-decoration:none;color:#607987;padding:10px 13px;border-radius:9px;font-size:12px;font-weight:700}.module-nav a.active{background:#173f56;color:white}
    .safety{display:flex;gap:12px;align-items:flex-start;background:#fff8e9;border:1px solid #f0dfba;border-radius:12px;padding:13px 15px;margin:17px 0;color:#705627;font-size:11px;line-height:1.9}.safety b{white-space:nowrap}
    .tabs{margin:8px 0 16px}.tabs button{border:1px solid #dce7ec;background:white;color:#567181;border-radius:9px;padding:10px 15px;font:inherit;font-size:12px;cursor:pointer;white-space:nowrap}.tabs button.chosen{background:#e8f3f3;color:#146e75;border-color:#b9d9da;font-weight:800}
    .metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}.metrics article,.work-card,.panel{background:white;border:1px solid #e3ebef;border-radius:14px;padding:17px;box-shadow:0 5px 20px #18364a08}.metrics small,.metrics span{display:block;color:#758a97;font-size:11px}.metrics strong{display:block;font-size:26px;margin:11px 0;color:#173d54}.metrics strong.pending{font-size:15px;color:#a1712d}
    .section-title{display:flex;justify-content:space-between;align-items:center;margin:23px 0 13px}.section-title h2{font-size:18px;margin:0}.section-title p{font-size:11px;color:#7b8e99;margin:6px 0 0}.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.work-card h3{font-size:14px;margin:12px 0 7px}.work-card p{font-size:11px;color:#718592;line-height:1.8;min-height:38px}.glyph{width:36px;height:36px;border-radius:10px;background:#edf5f6;color:#247e83;display:grid;place-items:center;font-size:20px}.tag{display:inline-block;background:#f1f5f6;color:#657c89;padding:5px 9px;border-radius:20px;font-size:10px}
    .panel{padding:18px}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.form-grid label{display:flex;flex-direction:column;gap:7px;font-size:11px;color:#506c7c}.form-grid input,.form-grid select,.form-grid textarea{width:100%;box-sizing:border-box;border:1px solid #dce6eb;background:#fbfcfd;border-radius:8px;padding:11px;color:#365367;font:inherit}.form-grid .wide{grid-column:1/-1}.actions{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-top:15px}.actions button{border:0;background:#17465d;color:white;border-radius:8px;padding:11px 17px;font:inherit;font-size:12px;cursor:pointer}.actions span{font-size:11px;color:#778b97}
    .review-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.review-grid article{display:flex;align-items:center;gap:12px;border:1px solid #e4ecef;border-radius:11px;padding:13px}.review-grid article>b{background:#edf4f5;color:#23787e;border-radius:9px;padding:8px 11px}.review-grid h3{font-size:12px;margin:0 0 5px}.review-grid p{font-size:10px;color:#82939d;margin:0}.review-grid article>span{margin-right:auto;color:#a0793c;font-size:10px;white-space:nowrap}.empty{text-align:center;background:#f8fafb;border:1px dashed #d6e2e8;border-radius:11px;padding:25px;margin-top:14px}.empty p{font-size:11px;color:#7b8e99;margin-bottom:0}.shell footer{border-top:1px solid #e4ecef;margin-top:28px;padding-top:14px;color:#84949e;font-size:10px}
    @media(max-width:850px){.metrics{grid-template-columns:repeat(2,minmax(0,1fr))}.cards{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:580px){.metrics,.cards,.form-grid,.review-grid{grid-template-columns:1fr}.form-grid .wide{grid-column:auto}.safety{flex-direction:column}.service-state{white-space:normal}}
  `]
})
export class ScientificWorkspaceDetailComponent {
  private readonly route = inject(ActivatedRoute);
  readonly key = signal<WorkspaceKey>((this.route.snapshot.data['workspace'] ?? 'quality') as WorkspaceKey);
  readonly panel = signal<Panel>('overview');
  readonly draftMessage = signal('');
  readonly config = computed(() => this.configs[this.key()]);
  prepareDraft(): void {
    this.draftMessage.set('تم تجهيز المسودة في الواجهة الحالية فقط؛ لم تُرسل إلى الخادم ولم تُحفظ.');
  }
  private readonly configs: Record<WorkspaceKey, WorkspaceConfig> = {
    climatol: {
      title:'التجانس المناخي وCLIMATOL', subtitle:'إدارة السلاسل الزمنية، فحص الجودة، كشف الانقطاعات، اختيار المحطات المرجعية ومراجعة السلاسل المصححة.',
      purpose:'مسارات التجانس والتحليل المناخي', setupTitle:'إعداد مهمة تجانس مناخي',
      setupFields:['المحطة أو مجموعة المحطات','العنصر المناخي','من تاريخ','إلى تاريخ','طريقة المقارنة المرجعية'],
      workflows:[
        {title:'استكشاف السلاسل الزمنية',description:'عرض السلسلة الخام والفجوات والقيم المفقودة والتغطية الزمنية.',status:'يتطلب مستودع البيانات'},
        {title:'كشف نقاط الانقطاع',description:'تحليل التغيرات المرشحة وربطها بالأدلة الوصفية للمحطة.',status:'يتطلب محرك CLIMATOL'},
        {title:'المحطات المرجعية',description:'تحديد المحطات المرجعية وفحص الارتباط والتجانس المكاني.',status:'يتطلب دليل المحطات'},
        {title:'تشغيل التجانس',description:'إدارة مهمة معزولة وحفظ المخرجات المشتقة دون تغيير الخام.',status:'محرك R غير موصول'},
        {title:'السلاسل المصححة',description:'مقارنة قبل وبعد التجانس وإدارة الإصدارات وسبب كل تعديل.',status:'يتطلب خدمة النتائج'},
        {title:'المعدلات والمؤشرات',description:'المعدلات الشهرية والفصلية والسنوية والاتجاهات والمؤشرات المناخية.',status:'يتطلب خدمة المناخ'}
      ],
      reviewTitle:'مراجعة نتائج التجانس',reviewSteps:['فحص اكتمال السلسلة ومصدرها','مراجعة نقاط الانقطاع المقترحة','التحقق من المحطات المرجعية','مقارنة السلسلة الخام والمصححة','اعتماد الإصدار أو إرجاعه للتعديل'],
      reports:['تقرير جودة السلاسل الزمنية','تقرير نقاط الانقطاع','تقرير مقارنة المحطات المرجعية','تقرير السلاسل قبل وبعد التجانس','المعدلات الشهرية والفصلية والسنوية','مؤشرات الاتجاه والتغير المناخي']
    },
    records:{
      title:'أرشيف السجلات الورقية والميكانيكية',subtitle:'إدارة دورة حياة صور دفاتر الرصد ومخططات أجهزة التسجيل مع حفظ المصدر الأصلي وبصمة الملفات.',
      purpose:'أرشيف مصادر القياس',setupTitle:'تعريف سجل مصور جديد',setupFields:['المحطة','نوع السجل أو الجهاز','العنصر المناخي','تاريخ بداية التسجيل','تاريخ نهاية التسجيل','رقم الصفحة أو معرف الجهاز'],
      workflows:[
        {title:'دفاتر السجلات الورقية',description:'أرشفة صفحات الرصد اليدوي وربطها بالمحطة والتاريخ والراصد.',status:'خدمة التخزين مطلوبة'},
        {title:'Thermograph',description:'أرشفة مخططات درجة الحرارة ومعايرة التدريج الزمني والحراري.',status:'خدمة التخزين مطلوبة'},
        {title:'Hygrograph',description:'أرشفة مخططات الرطوبة وتوثيق الجهاز والفترة.',status:'خدمة التخزين مطلوبة'},
        {title:'Barograph',description:'أرشفة مخططات الضغط مع بيانات المعايرة.',status:'خدمة التخزين مطلوبة'},
        {title:'Pluviograph',description:'أرشفة مخططات الهطول وفترات التسجيل.',status:'خدمة التخزين مطلوبة'},
        {title:'بصمة وسلامة الملف',description:'الاحتفاظ بالنسخة الأصلية وSHA-256 وسجل الرفع والإصدارات.',status:'يتطلب تخزيناً آمناً'}
      ],
      reviewTitle:'مراجعة ملفات الأرشيف',reviewSteps:['التحقق من بيانات تعريف الملف','فحص جودة الصورة واتجاهها','التحقق من بصمة الملف الأصلي','ربط السجل بالمحطة والفترة والجهاز','تسجيل قرار قبول الملف أو رفضه'],
      reports:['فهرس السجلات حسب المحطة','تغطية الأرشيف حسب السنوات','السجلات الناقصة أو منخفضة الجودة','سجل الملفات والإصدارات']
    },
    comparison:{
      title:'مقارنة مصادر الرصد الثلاثية',subtitle:'مقارنة متزامنة بين السجل الورقي والمسجل الميكانيكي والرصد الإلكتروني وتوثيق الاختلافات والقرارات.',
      purpose:'مصادر المقارنة والتحقق',setupTitle:'إعداد مقارنة مصادر جديدة',setupFields:['المحطة','العنصر المناخي','تاريخ ووقت البداية','تاريخ ووقت النهاية','حدود التسامح المعتمدة'],
      workflows:[
        {title:'السجل الورقي',description:'القيمة اليدوية وصورة الصفحة وموضع القراءة وهوية المراجع.',status:'مصدر البيانات غير موصول'},
        {title:'المسجل الميكانيكي',description:'القيمة المستخرجة من المنحنى وإحداثيات النقطة ومعايرة المحاور.',status:'رقمنة المنحنيات غير موصولة'},
        {title:'الرصد الإلكتروني',description:'القيمة الرقمية المعتمدة والطابع الزمني ومصدر القياس.',status:'مصدر البيانات غير موصول'},
        {title:'محاذاة الوقت',description:'مطابقة التوقيت والمنطقة الزمنية ودقة التسجيل بين المصادر.',status:'يتطلب محرك المطابقة'},
        {title:'تحليل الفروقات',description:'الفروق المطلقة والنسبية وعدم اليقين وحدود القبول.',status:'يتطلب محرك المقارنة'},
        {title:'قرار المراجع',description:'قبول أو رفض أو طلب إعادة القراءة مع سبب موثق.',status:'يتطلب خدمة الاعتماد'}
      ],
      reviewTitle:'مراجعة حالات الاختلاف',reviewSteps:['التحقق من تطابق المحطة والعنصر','مطابقة الطوابع الزمنية','مراجعة صورة الورق وموضع القراءة','مراجعة المنحنى ومعايرة المحاور','تفسير الفروقات وتوثيق القرار'],
      reports:['تقرير التطابق بين المصادر','تقرير الفروقات حسب العنصر','تقرير الحالات خارج حدود التسامح','سجل قرارات المراجعة']
    },
    quality:{
      title:'مركز تدقيق الصور وجودة البيانات',subtitle:'إدارة فحوص OCR ورقمنة المنحنيات والقواعد الفيزيائية والزمنية ومراجعة التصحيحات.',
      purpose:'مسارات ضبط الجودة',setupTitle:'إعداد مهمة تدقيق جودة',setupFields:['المحطة أو مجموعة المحطات','نوع الفحص','من تاريخ','إلى تاريخ','مستوى الشدة أو حدود الفحص'],
      workflows:[
        {title:'استخراج OCR',description:'قراءة الأرقام والتواريخ مع مواضع النص ودرجة الثقة.',status:'OCR غير موصول'},
        {title:'رقمنة المنحنيات',description:'استخراج نقاط الرسم من مخططات الأجهزة الميكانيكية.',status:'Digitizer غير موصول'},
        {title:'القواعد الفيزيائية',description:'فحص الحدود والوحدات والعلاقات الفيزيائية بين العناصر.',status:'محرك الجودة غير موصول'},
        {title:'الفحوص الزمنية',description:'كشف التكرار والفجوات والقفزات واختلال التوقيت.',status:'محرك الجودة غير موصول'},
        {title:'مراجعة الاختلافات',description:'تجميع الحالات وتوزيعها على المراجعين وتسجيل القرار.',status:'قائمة المراجعة غير موصولة'},
        {title:'سجل التصحيحات',description:'حفظ القيمة الخام والمصححة والسبب والمستخدم والتوقيت.',status:'سجل التدقيق غير موصول'}
      ],
      reviewTitle:'قائمة حالات الجودة',reviewSteps:['مراجعة مصدر الصورة أو الرصد','التحقق من قاعدة الفحص المنطبقة','مراجعة القيمة الأصلية دون تعديل','توثيق القيمة المقترحة وسببها','اعتماد التصحيح أو رفضه'],
      reports:['تقرير اكتمال البيانات','تقرير أخطاء التحقق الفيزيائي','تقرير جودة OCR والرقمنة','تقرير الفجوات والقيم الشاذة','سجل التصحيحات والاعتمادات']
    },
    ai:{
      title:'مختبر الذكاء الاصطناعي',subtitle:'إدارة البيانات الموسومة وتقسيمها والتجارب والتقييم وسجل النماذج والاعتماد والنشر والمراقبة.',
      purpose:'خط إنتاج نماذج الذكاء الاصطناعي',setupTitle:'إعداد تجربة تعلم آلي',setupFields:['مجموعة البيانات وإصدارها','نوع النموذج أو المهمة','بداية نطاق البيانات','نهاية نطاق البيانات','سياسة تقسيم المحطات والزمن'],
      workflows:[
        {title:'مستودع مجموعات البيانات',description:'إصدارات البيانات والمصادر وحقوق الاستخدام وبصمات الملفات.',status:'مستودع البيانات مطلوب'},
        {title:'تعليم الصور والقراءات',description:'وسم الأرقام والمنحنيات وتصحيح النصوص المستخرجة.',status:'أداة الوسم غير موصولة'},
        {title:'تقسيم البيانات',description:'Train/Validation/Test مع منع تسرب المحطة والفترة الزمنية.',status:'Pipeline غير موصول'},
        {title:'تجارب التدريب',description:'إدارة الإعدادات والموارد ومقاييس الخطأ وعدم اليقين.',status:'التدريب غير مفعّل'},
        {title:'سجل النماذج',description:'حفظ نسخ النماذج وبصماتها وتقارير تقييمها ومصدر بياناتها.',status:'Model Registry غير موصول'},
        {title:'الاعتماد والنشر',description:'بوابة موافقة بشرية ونشر تدريجي ومراقبة الانحراف وإعادة التدريب.',status:'النشر غير مفعّل'}
      ],
      reviewTitle:'بوابة اعتماد النموذج',reviewSteps:['مراجعة مصدر البيانات وحقوق استخدامها','التحقق من عدم تسرب المحطات والفترات','مراجعة مقاييس الاختبار المستقل','اختبار التعميم على محطات غير مرئية','اعتماد الإصدار أو رفضه قبل النشر'],
      reports:['تقرير جودة مجموعة البيانات','تقرير الوسم ومراجعة العينات','تقرير تقسيم Train/Validation/Test','مقارنة التجارب ومقاييس الأداء','بطاقة النموذج وإصداراته','تقرير الانحراف وإعادة التدريب']
    }
  };
}
