import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';
import {
  RegistrationStatus,
  RegistrationSubmissionApiService,
  RequestableRole
} from '../../core/api/registration-submission-api.service';
import { SupabaseAuthService } from '../../core/supabase/supabase-auth.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="registration-page" dir="rtl">
      <section class="registration-card">
        <header>
          <span class="eyebrow">METRA 2027 · الهوية المؤسسية</span>
          <h1>إنشاء الحساب وطلب الانضمام</h1>
          <p>إنشاء حساب الهوية لا يفعّل صلاحيات METRA. يبدأ التفعيل بعد مراجعة المحطة والاعتماد النظامي المنفصل.</p>
        </header>

        @if (!auth.isConfigured || !api.isConfigured) {
          <div class="notice warning">خدمة التسجيل غير مهيأة في بيئة العرض. يلزم ضبط Supabase العام وعنوان API قبل إنشاء الحساب أو إرسال الطلب.</div>
        } @else if (mode === 'account') {
          <form (ngSubmit)="createAccount()">
            <h2>الخطوة الأولى: حساب الدخول</h2>
            <label>البريد الإلكتروني
              <input type="email" name="email" [(ngModel)]="email" autocomplete="email" required maxlength="254">
            </label>
            <label>كلمة المرور
              <input type="password" name="password" [(ngModel)]="password" autocomplete="new-password" required minlength="8" maxlength="128">
            </label>
            @if (needsEmailConfirmation) {
              <div class="notice warning">تم إنشاء حساب الهوية. أكّد بريدك الإلكتروني ثم سجّل الدخول، وبعدها افتح هذه الصفحة لإكمال بيانات طلب الانضمام.</div>
            }
            @if (error) { <div class="notice error" role="alert">{{ error }}</div> }
            <button class="primary" type="submit" [disabled]="busy || !email.trim() || password.length < 8">
              {{ busy ? 'جارٍ إنشاء الحساب…' : 'إنشاء حساب الدخول' }}
            </button>
            <p class="helper">لديك حساب بالفعل؟ <a routerLink="/login">تسجيل الدخول</a></p>
          </form>
        } @else if (loading) {
          <div class="loading">جارٍ تحميل بيانات التسجيل وحالة الحساب…</div>
        } @else if (status?.account_state) {
          <section class="status-panel">
            <span class="status-label">حالة حساب METRA</span>
            <h2>{{ statusLabel(status.account_state) }}</h2>
            <p>{{ statusDescription(status) }}</p>
            @if (status.submitted_at) { <small>تاريخ تقديم الطلب: {{ formatDate(status.submitted_at) }}</small> }
            @if (status.review_note || status.state_reason) {
              <div class="review-note"><strong>ملاحظة المراجعة</strong><p>{{ status.review_note || status.state_reason }}</p></div>
            }
            @if (status.request_id) { <small>رقم الطلب: {{ status.request_id }}</small> }
            <a routerLink="/">العودة إلى لوحة النظام</a>
          </section>
        } @else {
          <form (ngSubmit)="submitRegistration()">
            <h2>الخطوة الثانية: بيانات طلب الانضمام</h2>
            <div class="fields">
              <label>الاسم الأول<input name="firstName" [(ngModel)]="firstName" required maxlength="120"></label>
              <label>اسم الأب<input name="fatherName" [(ngModel)]="fatherName" required maxlength="120"></label>
              <label>اسم العائلة<input name="lastName" [(ngModel)]="lastName" required maxlength="120"></label>
              <label>رقم الهاتف (اختياري)<input name="phone" [(ngModel)]="phone" type="tel" maxlength="40" dir="ltr"></label>
              <label>المحطة المطلوبة
                <select name="stationId" [(ngModel)]="stationId" required>
                  <option value="">اختر محطة فعّالة ومعتمدة</option>
                  @for (station of stations; track station.id) {
                    <option [value]="station.id">{{ station.name_ar }} — {{ station.local_station_code || station.id }}</option>
                  }
                </select>
              </label>
              <label>الدور المطلوب
                <select name="roleCode" [(ngModel)]="roleCode" required>
                  <option value="">اختر الدور المتاح للطلب</option>
                  @for (role of roles; track role.role_code) {
                    <option [value]="role.role_code">{{ role.name_ar }} ({{ role.role_code }})</option>
                  }
                </select>
              </label>
            </div>
            @if (stations.length === 0) {
              <div class="notice warning">لا توجد محطات معتمدة وفعّالة متاحة للطلب حالياً.</div>
            }
            @if (roles.length === 0) {
              <div class="notice warning">لا توجد أدوار قابلة للطلب حالياً. لا يمكن طلب الأدوار الإدارية من هذه الشاشة.</div>
            }
            <label class="terms">
              <input type="checkbox" name="termsAccepted" [(ngModel)]="termsAccepted">
              <span>أقر بصحة البيانات وأوافق على شروط استخدام METRA وإجراءات التحقق والاعتماد المؤسسي (الإصدار {{ termsVersion }}).</span>
            </label>
            @if (error) { <div class="notice error" role="alert">{{ error }}</div> }
            @if (notice) { <div class="notice success" role="status">{{ notice }}</div> }
            <button class="primary" type="submit" [disabled]="busy || !canSubmit">
              {{ busy ? 'جارٍ إرسال الطلب…' : 'إرسال طلب الانضمام' }}
            </button>
            <p class="helper">يظل الحساب غير مفعل تشغيلياً حتى إتمام مرحلتي الاعتماد. لن تُمنح صلاحية مدير النظام من هذا المسار.</p>
          </form>
        }
      </section>
    </main>
  `,
  styles: [`
    :host{display:block;color:#294253;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .registration-page{max-width:900px;margin:20px auto}.registration-card{background:#fff;border:1px solid #e4ebef;border-radius:16px;padding:clamp(18px,4vw,32px);box-shadow:0 8px 30px #1d35460b}
    header{margin-bottom:22px}.eyebrow{font-size:12px;font-weight:800;color:#287caf}h1{font-size:25px;margin:8px 0}header p{font-size:13px;color:#7c8992;line-height:1.9;margin:0}
    form{display:grid;gap:15px}h2{font-size:18px;margin:0 0 3px}label{display:grid;gap:7px;font-size:12px;font-weight:700;color:#5e707c}input,select{box-sizing:border-box;width:100%;font:inherit;padding:11px;border:1px solid #d8e2e8;border-radius:8px;background:#fff;color:#294253}input:focus,select:focus{outline:2px solid #b9d9eb;border-color:#438bb3}
    .fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.terms{display:flex;align-items:flex-start;gap:10px;padding:13px;background:#f7fafc;border-radius:9px;line-height:1.8}.terms input{width:18px;height:18px;flex:0 0 auto;margin-top:2px}.primary{border:0;border-radius:9px;padding:13px;background:#287caf;color:#fff;font:inherit;font-weight:800;cursor:pointer}.primary:disabled{opacity:.5;cursor:not-allowed}
    .notice{padding:12px 14px;border-radius:9px;font-size:12px;line-height:1.8}.warning{background:#fff8e9;color:#795a20}.error{background:#fff0ef;color:#a33d35}.success{background:#eaf7ef;color:#247247}.helper{font-size:11px;color:#83919a;line-height:1.8;margin:0}.helper a,.status-panel a{color:#287caf;font-weight:800;text-decoration:none}.loading{padding:30px;text-align:center;color:#7b8992}.status-panel{border:1px solid #e2ebef;border-radius:12px;background:#f9fbfc;padding:20px}.status-label{font-size:11px;color:#748692}.status-panel h2{font-size:22px;margin:8px 0;color:#2e627e}.status-panel p{font-size:13px;line-height:1.9;color:#5e707c}.status-panel small{display:block;font-size:10px;color:#87939b;margin-top:8px}.review-note{padding:12px;background:#fff;border-radius:8px;margin:12px 0}.review-note strong{font-size:11px}.review-note p{margin:5px 0 0}
    @media(max-width:620px){.fields{grid-template-columns:1fr}.registration-page{margin:0}.registration-card{border-radius:12px}}
  `]
})
export class RegistrationComponent implements OnInit {
  readonly auth = inject(SupabaseAuthService);
  readonly api = inject(RegistrationSubmissionApiService);
  private readonly stationsApi = inject(ObservationApiService);

  readonly termsVersion = 'metra-terms-2026-11';
  mode: 'account' | 'profile' = 'account';
  email = '';
  password = '';
  firstName = '';
  fatherName = '';
  lastName = '';
  phone = '';
  stationId = '';
  roleCode = '';
  termsAccepted = false;
  stations: StationDirectoryItem[] = [];
  roles: RequestableRole[] = [];
  status: RegistrationStatus | null = null;
  loading = false;
  busy = false;
  needsEmailConfirmation = false;
  error = '';
  notice = '';

  get canSubmit(): boolean {
    return Boolean(
      this.firstName.trim() && this.fatherName.trim() && this.lastName.trim() &&
      this.stationId && this.roleCode && this.termsAccepted &&
      this.stations.some(s => s.id === this.stationId && s.approval_status === 'approved' &&
        s.operational_status === 'active' && !s.is_demo) &&
      this.roles.some(r => r.role_code === this.roleCode)
    );
  }

  async ngOnInit(): Promise<void> {
    if (!this.api.isConfigured) return;
    try {
      const token = await this.auth.getAccessToken();
      if (token) {
        this.mode = 'profile';
        await this.loadProfile();
      }
    } catch {
      this.mode = 'account';
    }
  }

  async createAccount(): Promise<void> {
    if (this.busy || !this.email.trim() || this.password.length < 8) return;
    this.busy = true;
    this.error = '';
    this.needsEmailConfirmation = false;
    try {
      const hasSession = await this.auth.signUpWithPassword(this.email.trim(), this.password);
      if (!hasSession) {
        this.needsEmailConfirmation = true;
        return;
      }
      this.mode = 'profile';
      await this.loadProfile();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.busy = false;
    }
  }

  async loadProfile(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const [stations, roles, status] = await Promise.all([
        this.stationsApi.getAllStations(),
        this.api.getRequestableRoles(),
        this.api.getMyStatus()
      ]);
      this.stations = stations.filter(station =>
        station.approval_status === 'approved' &&
        station.operational_status === 'active' &&
        !station.is_demo
      );
      this.roles = roles;
      this.status = status;
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.loading = false;
    }
  }

  async submitRegistration(): Promise<void> {
    if (this.busy || !this.canSubmit) return;
    this.busy = true;
    this.error = '';
    this.notice = '';
    try {
      await this.api.submit({
        firstName: this.firstName.trim(),
        fatherName: this.fatherName.trim(),
        lastName: this.lastName.trim(),
        phone: this.phone.trim() || null,
        roleCode: this.roleCode,
        stationId: this.stationId,
        termsVersion: this.termsVersion,
        idempotencyKey: crypto.randomUUID()
      });
      this.notice = 'تم استلام طلب الانضمام. سيظل الحساب قيد المراجعة حتى اكتمال مرحلتي الاعتماد.';
      this.status = await this.api.getMyStatus();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.busy = false;
    }
  }

  statusLabel(state: string): string {
    const labels: Record<string, string> = {
      pending_station_approval: 'بانتظار اعتماد رئيس المحطة',
      pending_system_approval: 'بانتظار الاعتماد النظامي النهائي',
      active: 'الحساب معتمد وفعال',
      rejected: 'تم رفض طلب التسجيل',
      suspended: 'الحساب موقوف',
      disabled: 'الحساب معطل'
    };
    return labels[state] ?? state;
  }

  statusDescription(status: RegistrationStatus): string {
    if (status.account_state === 'pending_station_approval') return 'تم استلام الطلب وهو بانتظار مراجعة المحطة. لا توجد صلاحيات تشغيلية مفعلة حتى الآن.';
    if (status.account_state === 'pending_system_approval') return 'اجتاز الطلب مراجعة المحطة وينتظر اعتماداً نظامياً من مراجع مختلف.';
    if (status.account_state === 'active') return 'اكتملت الموافقات وأنشئ التكليف المطلوب. ستظل كل العمليات خاضعة لنطاق الصلاحيات الممنوحة.';
    if (status.account_state === 'rejected') return 'لا يمكن إعادة تقديم طلب جديد من الحساب نفسه تلقائياً. راجع ملاحظة الرفض والجهة المختصة.';
    return 'حالة الحساب تحتاج إلى مراجعة الجهة المختصة.';
  }

  formatDate(value: string): string {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'غير متاح' : new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 400) return 'البيانات أو الدور أو المحطة المختارة غير صالحة أو غير متاحة.';
      if (error.status === 401) return 'يلزم تسجيل الدخول والتحقق من البريد الإلكتروني أولاً.';
      if (error.status === 409) return 'يوجد طلب سابق أو أن الحساب مرتبط مسبقاً. راجع حالة الحساب بدلاً من إنشاء طلب مكرر.';
      if (error.status === 503) return 'خدمة التسجيل غير متاحة حالياً. لم يتم تأكيد حفظ الطلب.';
    }
    return error instanceof Error ? error.message : 'تعذر إكمال التسجيل.';
  }
}
