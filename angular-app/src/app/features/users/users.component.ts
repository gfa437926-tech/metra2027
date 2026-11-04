import { Component } from '@angular/core';
import { RegistrationReviewComponent } from './registration-review.component';

interface RoleDefinition {
  code: string;
  name: string;
  english: string;
  scope: string;
  requestable: boolean;
}

@Component({
  standalone: true,
  imports: [RegistrationReviewComponent],
  template: `
    <main class="page" dir="rtl">
      <header>
        <span class="eyebrow">إدارة الهوية والصلاحيات</span>
        <h1>المستخدمون والأدوار</h1>
        <p>مرجع الأدوار المعتمدة في METRA 2027 وحدود طلبها ومنحها.</p>
      </header>

      <metra-registration-review></metra-registration-review>

      <section class="notice" role="note">
        <strong>حالة الوحدة: مرجع الأدوار فقط</strong>
        <p>هذه الشاشة تعرض تعريفات الأدوار ولا تنشئ حسابات أو تكليفات أو تمنح صلاحيات. إدارة المستخدمين الفعلية تتطلب ربط واجهات إدارية موثقة بالخادم وسياسات قاعدة البيانات وسجل التدقيق.</p>
      </section>

      <section class="summary" aria-label="ملخص الأدوار">
        <article><span>إجمالي الأدوار</span><strong>{{ roles.length }}</strong></article>
        <article><span>قابلة لطلب المستخدم</span><strong>{{ requestableCount }}</strong></article>
        <article><span>تتطلب منحاً إدارياً</span><strong>{{ roles.length - requestableCount }}</strong></article>
      </section>

      <section class="panel">
        <div class="panel-heading">
          <div><h2>دليل الأدوار</h2><p>الأدوار المرتبة وفق دليل التهيئة الأساسي.</p></div>
          <span class="count">{{ roles.length }} أدوار</span>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>الدور</th><th>رمز الدور</th><th>نطاق المسؤولية</th><th>آلية الإسناد</th></tr></thead>
            <tbody>
              @for (role of roles; track role.code) {
                <tr>
                  <td><strong>{{ role.name }}</strong><small>{{ role.english }}</small></td>
                  <td><code>{{ role.code }}</code></td>
                  <td>{{ role.scope }}</td>
                  <td><span class="tag" [class.self]="role.requestable">{{ role.requestable ? 'طلب ذاتي فقط' : 'منح إداري معتمد' }}</span></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </section>
      <p class="footnote">تنبيه أمني: إظهار الدور في الواجهة لا يمنح أي صلاحية. التحقق النهائي يجب أن يتم في API وقاعدة البيانات لكل مستخدم ومحطة وطلب.</p>
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .page{max-width:1450px;margin:auto}header{margin-bottom:20px}.eyebrow{color:#287caf;font-size:13px;font-weight:800}h1{font-size:clamp(24px,3vw,32px);margin:8px 0;font-weight:800}h2{font-size:19px;margin:0 0 5px}p{margin:0;color:#778691;font-size:13px;line-height:1.8}
    .notice{background:#fff8e9;border:1px solid #f0dfb9;border-right:4px solid #d69b35;border-radius:10px;padding:15px 17px;margin-bottom:16px}.notice strong{display:block;color:#76551d;margin-bottom:5px}.notice p{color:#765f36}
    .summary{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:13px;margin-bottom:18px}.summary article,.panel{background:#fff;border-radius:12px;padding:18px;box-shadow:0 5px 18px #2233440c}.summary article{display:grid;gap:8px;border-bottom:3px solid #3498db}.summary span{font-size:12px;color:#71808b}.summary strong{font-size:25px;color:#203e53}
    .panel{padding:22px}.panel-heading{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:16px}.count{background:#edf5fa;color:#2876a8;padding:6px 11px;border-radius:20px;font-size:12px;font-weight:700}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;min-width:720px}th{text-align:right;background:#f5f7f9;color:#697781;font-size:12px;padding:13px 11px}td{padding:14px 11px;border-bottom:1px solid #edf0f2;font-size:12px;vertical-align:top;line-height:1.8}tbody tr:hover{background:#f8fbfd}td small{display:block;color:#87939b;direction:ltr;text-align:right;font-size:11px}code{background:#f1f4f6;padding:4px 7px;border-radius:5px;direction:ltr;display:inline-block}.tag{display:inline-block;background:#fff0e8;color:#9a5527;padding:5px 9px;border-radius:20px;font-size:11px;font-weight:700;white-space:nowrap}.tag.self{background:#e8f5ed;color:#247447}.footnote{margin-top:14px;font-size:11px;color:#85919a}
    @media(max-width:700px){.summary{grid-template-columns:1fr}.panel{padding:14px}.panel-heading{align-items:flex-start;flex-direction:column}}
  `]
})
export class UsersComponent {
  readonly roles: RoleDefinition[] = [
    { code: 'observer', name: 'راصد جوي', english: 'Weather Observer', scope: 'إدخال الرصد والنشرات ضمن المحطة المسندة إليه.', requestable: true },
    { code: 'station_head', name: 'رئيس محطة', english: 'Station Manager', scope: 'إدارة شؤون المحطة والراصدين ومراجعة النشرات ضمن نطاقها.', requestable: false },
    { code: 'station_auditor', name: 'مدقق محطة', english: 'Station Auditor', scope: 'مراجعة جودة واكتمال نشرات المحطة ضمن نطاق التدقيق.', requestable: false },
    { code: 'chief_auditor', name: 'المدقق الرئيسي العام', english: 'Chief Auditor', scope: 'التدقيق النهائي العام وفق مسار الاعتماد المؤسسي.', requestable: false },
    { code: 'network_director', name: 'رئيس دائرة الشبكات', english: 'Network Director', scope: 'الإشراف على شبكة المحطات وبياناتها وتكليفاتها.', requestable: false },
    { code: 'statistics_director', name: 'رئيس دائرة الإحصاء', english: 'Statistics Director', scope: 'الإشراف على الإحصاء المناخي والتحليلات والتقارير.', requestable: false },
    { code: 'aftn_operator', name: 'مسؤول دائرة AFTN', english: 'AFTN Operations Officer', scope: 'إدارة رسائل AFTN والترميز والإرسال وسجل التسليم.', requestable: false },
    { code: 'system_admin', name: 'مدير النظام', english: 'System Administrator', scope: 'إدارة الإعدادات التقنية والحسابات والصلاحيات بضوابط التدقيق.', requestable: false }
  ];

  get requestableCount(): number {
    return this.roles.filter(role => role.requestable).length;
  }
}
