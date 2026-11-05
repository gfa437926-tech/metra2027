import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import {
  RegistrationStatusAccessError,
  RegistrationStatusService
} from '../../core/identity/registration-status.service';
import { RegistrationSubmissionStatus } from '../../core/identity/registration-status.models';

type PageState = 'idle' | 'loading' | 'loaded' | 'error';

@Component({
  standalone: true,
  imports: [CommonModule],
  template: `
    <main class="registration-page" dir="rtl">
      <header class="page-heading">
        <div>
          <p class="eyebrow">خدمات حساب المستخدم</p>
          <h1>متابعة طلب التسجيل</h1>
          <p>اعرف المرحلة الحالية لطلبك دون التواصل اليدوي مع إدارة المحطة.</p>
        </div>
        <span class="secure-label"><i class="fa-solid fa-shield-halved"></i> استعلام خاص بصاحب الطلب</span>
      </header>

      <section class="lookup-card">
        <label for="request-id">رقم طلب التسجيل</label>
        <div class="lookup-row">
          <input #requestIdInput id="request-id" type="text" inputmode="text"
            autocomplete="off" spellcheck="false" maxlength="36"
            placeholder="أدخل معرّف الطلب الذي استلمته عند التسجيل"
            (keyup.enter)="load(requestIdInput.value)" />
          <button type="button" (click)="load(requestIdInput.value)" [disabled]="state() === 'loading'">
            @if (state() === 'loading') { <i class="fa-solid fa-spinner spinning"></i> جارٍ الاستعلام }
            @else { <i class="fa-solid fa-magnifying-glass"></i> عرض الحالة }
          </button>
        </div>
        <p class="hint"><i class="fa-solid fa-lock"></i> يلزم تسجيل الدخول بنفس حساب التسجيل. لا يمكن عرض طلب مستخدم آخر حتى لو عُرف رقم طلبه.</p>
      </section>

      @if (state() === 'idle') {
        <section class="empty-state">
          <span class="empty-icon"><i class="fa-solid fa-clipboard-check"></i></span>
          <h2>تابع طلبك خطوة بخطوة</h2>
          <p>أدخل رقم الطلب لعرض ما إذا كان بانتظار رئيس المحطة أو إدارة النظام أو أصبح الحساب معتمداً.</p>
        </section>
      } @else if (state() === 'loading') {
        <section class="result-card" role="status">
          <i class="fa-solid fa-spinner spinning large-icon"></i>
          <h2>جارٍ التحقق من طلب التسجيل</h2>
          <p>يتم التحقق من الجلسة وقراءة حالة الطلب من الخادم.</p>
        </section>
      } @else if (state() === 'error') {
        <section class="result-card error-card" role="alert">
          <i class="fa-solid fa-circle-exclamation large-icon"></i>
          <h2>{{ errorTitle() }}</h2>
          <p>{{ errorMessage() }}</p>
        </section>
      } @else if (status(); as item) {
        <section class="result-card">
          <div class="result-heading">
            <div><p class="eyebrow">نتيجة الاستعلام</p><h2>{{ item.statusLabel }}</h2></div>
            <span class="status-pill" [class.complete]="item.status === 'active'"
              [class.rejected]="item.status === 'rejected'">{{ statusTag(item.status) }}</span>
          </div>

          <div class="timeline" [class.is-rejected]="item.status === 'rejected'">
            <div class="timeline-step" [class.done]="true">
              <span class="step-icon"><i class="fa-solid fa-file-circle-check"></i></span>
              <div><strong>تم إرسال الطلب</strong><small>{{ formatDate(item.submittedAtUtc) }}</small></div>
            </div>
            <div class="timeline-line" [class.done]="item.status !== 'pending_station_approval'"></div>
            <div class="timeline-step" [class.done]="item.status !== 'pending_station_approval'">
              <span class="step-icon"><i class="fa-solid fa-building-user"></i></span>
              <div><strong>مراجعة رئيس المحطة</strong><small>{{ stationStageText(item.status) }}</small></div>
            </div>
            <div class="timeline-line" [class.done]="item.status === 'active'"></div>
            <div class="timeline-step" [class.done]="item.status === 'active'">
              <span class="step-icon"><i class="fa-solid fa-user-shield"></i></span>
              <div><strong>اعتماد إدارة النظام</strong><small>{{ systemStageText(item.status) }}</small></div>
            </div>
          </div>

          @if (item.status === 'active') {
            <div class="outcome success"><i class="fa-solid fa-circle-check"></i><span>اكتملت الموافقة وأصبح حسابك معتمداً في النظام.</span></div>
          } @else if (item.status === 'rejected') {
            <div class="outcome rejected"><i class="fa-solid fa-circle-xmark"></i><span>تم رفض الطلب. راجع الجهة المختصة لمعرفة الإجراء التالي.</span></div>
          } @else {
            <div class="outcome pending"><i class="fa-solid fa-hourglass-half"></i><span>لم تنتهِ المراجعة بعد. يمكنك إعادة الاستعلام لاحقاً لمعرفة أي تحديث.</span></div>
          }
          <footer class="timestamps">
            <span>آخر تحديث: {{ formatDate(item.updatedAtUtc) }}</span>
            <span>رقم الطلب: {{ item.requestId }}</span>
          </footer>
        </section>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263747;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .registration-page{max-width:1050px;margin:0 auto}.page-heading{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:22px}.eyebrow{margin:0 0 6px;color:#2780b9;font-size:12px;font-weight:800}.page-heading h1{margin:0;font-size:clamp(24px,3vw,32px);font-weight:900}.page-heading p:not(.eyebrow){margin:7px 0 0;color:#71808b;font-size:13px}.secure-label{padding:9px 12px;background:#eaf5f0;color:#26764c;border-radius:9px;font-size:11px;font-weight:800;white-space:nowrap}.secure-label i{margin-left:5px}
    .lookup-card,.result-card,.empty-state{background:#fff;border:1px solid #e3eaf0;border-radius:14px;box-shadow:0 5px 18px #2233440a}.lookup-card{padding:20px;margin-bottom:18px}.lookup-card label{display:block;font-size:13px;font-weight:800;margin-bottom:9px}.lookup-row{display:flex;gap:10px}.lookup-row input{flex:1;min-width:0;border:1px solid #d8e1e8;border-radius:9px;padding:12px 14px;font:inherit;font-size:13px;outline:none}.lookup-row input:focus{border-color:#3186b4;box-shadow:0 0 0 3px #3186b41c}.lookup-row button{border:0;border-radius:9px;background:#247eaf;color:white;padding:0 18px;font:inherit;font-size:13px;font-weight:800;cursor:pointer;white-space:nowrap}.lookup-row button:disabled{opacity:.6;cursor:wait}.hint{margin:10px 0 0;color:#778792;font-size:11px;line-height:1.8}.hint i{color:#2883b3;margin-left:4px}
    .empty-state,.result-card{text-align:center;padding:34px 24px}.empty-icon{display:grid;place-items:center;width:58px;height:58px;margin:0 auto 12px;border-radius:16px;background:#eaf4fb;color:#2980b9;font-size:24px}.empty-state h2,.result-card h2{margin:5px 0 8px;font-size:18px;color:#34495e}.empty-state p,.result-card>p{margin:0;color:#778792;font-size:13px;line-height:1.9}.large-icon{font-size:32px;color:#3284ae}.result-card.error-card .large-icon{color:#c66b3d}.error-card p{max-width:600px;margin:0 auto}
    .result-heading{display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:right;margin-bottom:26px}.result-heading h2{margin:0;font-size:22px}.status-pill{padding:6px 11px;border-radius:22px;background:#fff2d9;color:#92621b;font-size:11px;font-weight:800;white-space:nowrap}.status-pill.complete{background:#e6f5eb;color:#237b49}.status-pill.rejected{background:#fdebea;color:#a33a35}
    .timeline{max-width:760px;margin:0 auto;display:grid;grid-template-columns:1fr 35px 1fr 35px 1fr;align-items:start;text-align:center}.timeline-step{display:grid;justify-items:center;gap:9px;color:#87949c}.step-icon{display:grid;place-items:center;width:44px;height:44px;border-radius:50%;background:#eef1f3;color:#88969f;font-size:17px}.timeline-step.done{color:#2b7650}.timeline-step.done .step-icon{background:#e4f4eb;color:#278451}.timeline-step strong{display:block;font-size:12px;color:#34495e}.timeline-step small{display:block;margin-top:4px;font-size:10px;color:#7a8992;line-height:1.6}.timeline-line{height:3px;background:#e4e9ed;margin-top:21px;border-radius:3px}.timeline-line.done{background:#53a879}
    .outcome{display:flex;align-items:center;justify-content:center;gap:9px;margin:25px auto 0;padding:13px 16px;border-radius:9px;max-width:680px;font-size:12px;font-weight:700}.outcome.pending{background:#fff6e6;color:#8c641f}.outcome.success{background:#e8f6ed;color:#257a4a}.outcome.rejected{background:#fff0ef;color:#a6423c}.timestamps{display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px;margin-top:20px;padding-top:15px;border-top:1px solid #edf1f4;color:#81909a;font-size:10px}
    .spinning{animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
    @media(max-width:650px){.page-heading{align-items:flex-start;flex-direction:column}.lookup-row{flex-direction:column}.lookup-row button{padding:12px}.result-heading{align-items:flex-start;flex-direction:column}.timeline{grid-template-columns:1fr;gap:8px;text-align:right}.timeline-step{grid-template-columns:44px 1fr;justify-items:start;align-items:center;text-align:right}.timeline-step small{margin-top:2px}.timeline-line{width:3px;height:18px;margin:-5px 20px}.timestamps{flex-direction:column}}
  `]
})
export class RegistrationStatusComponent {
  private readonly service = inject(RegistrationStatusService);
  readonly state = signal<PageState>('idle');
  readonly status = signal<RegistrationSubmissionStatus | null>(null);
  readonly errorTitle = signal('');
  readonly errorMessage = signal('');

  async load(requestId: string): Promise<void> {
    this.status.set(null);
    this.errorTitle.set('');
    this.errorMessage.set('');
    if (!requestId.trim()) {
      this.showError('رقم الطلب مطلوب', 'أدخل معرّف طلب التسجيل أولاً.');
      return;
    }

    this.state.set('loading');
    try {
      this.status.set(await this.service.getOwnStatus(requestId.trim()));
      this.state.set('loaded');
    } catch (error: unknown) {
      const accessError = error instanceof RegistrationStatusAccessError ? error.code : 'unavailable';
      const messages: Record<string, [string, string]> = {
        supabase_not_configured: ['إعدادات تسجيل الدخول غير مكتملة', 'لم يتم ضبط عنوان مشروع Supabase والمفتاح العام. لم يتم إرسال أي طلب إلى الخادم.'],
        not_signed_in: ['يلزم تسجيل الدخول', 'سجّل الدخول بنفس الحساب الذي أرسل طلب التسجيل ثم أعد المحاولة.'],
        not_found: ['لم يتم العثور على الطلب', 'تحقق من رقم الطلب. قد لا يكون الطلب تابعاً للحساب المسجل حالياً.'],
        forbidden: ['الوصول غير مسموح', 'لا تسمح صلاحيات الجلسة الحالية بقراءة هذا الطلب.'],
        unavailable: ['تعذر الاتصال بالخدمة', 'تعذر التحقق من حالة الطلب حالياً. أعد المحاولة لاحقاً.']
      };
      const [title, message] = messages[accessError] ?? messages['unavailable'];
      this.showError(title, message);
    }
  }

  statusTag(status: RegistrationSubmissionStatus['status']): string {
    return status === 'active' ? 'معتمد' :
      status === 'rejected' ? 'مرفوض' :
      status === 'pending_system_approval' ? 'المرحلة الثانية' : 'المرحلة الأولى';
  }

  stationStageText(status: RegistrationSubmissionStatus['status']): string {
    if (status === 'pending_station_approval') return 'بانتظار قرار رئيس المحطة';
    return status === 'rejected' ? 'توقف الطلب بعد قرار الرفض' : 'اكتملت مراجعة المحطة';
  }

  systemStageText(status: RegistrationSubmissionStatus['status']): string {
    if (status === 'pending_station_approval') return 'تبدأ بعد موافقة المحطة';
    if (status === 'pending_system_approval') return 'بانتظار القرار النهائي';
    if (status === 'active') return 'تم الاعتماد النهائي';
    return 'لم يكتمل الاعتماد النهائي';
  }

  formatDate(value: string): string {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'غير متاح' :
      new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }

  private showError(title: string, message: string): void {
    this.errorTitle.set(title);
    this.errorMessage.set(message);
    this.state.set('error');
  }
}
