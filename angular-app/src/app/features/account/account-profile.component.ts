import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { RegistrationSubmissionApiService, RegistrationStatus } from '../../core/api/registration-submission-api.service';
import { SupabaseAuthService } from '../../core/supabase/supabase-auth.service';

@Component({
  standalone: true,
  selector: 'metra-account-profile',
  imports: [CommonModule, RouterLink],
  template: `
    <main class="profile" dir="rtl">
      <header><span class="eyebrow">الهوية المؤسسية</span><h1>الملف الشخصي وحالة الحساب</h1>
        <p>يعرض هذا الملف البيانات التي يعيدها الخادم فقط؛ لا يستنتج أدواراً أو محطات أو صلاحيات.</p></header>
      @if (loading) { <div class="state">جارٍ تحميل حالة الحساب…</div> }
      @else if (error) { <div class="notice error" role="alert">{{ error }} <button type="button" (click)="load()">إعادة المحاولة</button></div> }
      @else if (status) {
        <section class="card">
          <div class="identity"><span class="avatar">م</span><div><strong>{{ email || 'مستخدم METRA' }}</strong><small>مصدر الهوية: Supabase Auth</small></div></div>
          <div class="status"><small>حالة الحساب</small><strong>{{ stateLabel(status.account_state) }}</strong><span>{{ status.state_reason || 'لا توجد ملاحظة حالة من الخادم.' }}</span></div>
          <h2>طلب الانضمام</h2>
          <dl><dt>حالة الطلب</dt><dd>{{ status.request_status || 'لا يوجد طلب' }}</dd>
            <dt>رقم الطلب</dt><dd>{{ status.request_id || '—' }}</dd>
            <dt>تاريخ التقديم</dt><dd>{{ status.submitted_at ? formatDate(status.submitted_at) : '—' }}</dd></dl>
          @if (status.review_note) { <div class="review"><strong>ملاحظة المراجعة</strong><p>{{ status.review_note }}</p></div> }
          <div class="notice warning">لا يعيد API الحالي قائمة المحطات المسندة أو العضويات الفعالة أو الصلاحيات الفعلية؛ لذلك لا يتم عرضها أو استنتاجها هنا.</div>
          <div class="links"><a routerLink="/register">حالة طلب الانضمام</a><a routerLink="/forgot-password">تغيير كلمة المرور</a><a routerLink="/">العودة للرئيسية</a></div>
        </section>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.profile{max-width:850px;margin:18px auto;padding:12px}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:25px;margin:7px 0}header p{color:#75848e;line-height:1.8}.card{background:#fff;border:1px solid #e4ebef;border-radius:14px;padding:22px;box-shadow:0 5px 18px #2233440b}.identity{display:flex;gap:12px;align-items:center;padding-bottom:18px;border-bottom:1px solid #edf1f4}.identity div{display:grid;gap:4px}.identity small{color:#83919a}.avatar{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;background:#eaf4fa;color:#287caf;font-size:22px;font-weight:800}.status{display:grid;gap:5px;padding:16px;background:#f5f9fb;border-radius:10px;margin:16px 0}.status small{color:#7c8b95}.status strong{font-size:20px;color:#286f91}.status span{font-size:12px;color:#70808b}h2{font-size:17px}dl{display:grid;grid-template-columns:170px 1fr;gap:9px;font-size:13px}dt{color:#71818c}dd{margin:0;font-weight:700;overflow-wrap:anywhere}.review{background:#f7fafc;padding:12px;border-radius:8px}.review p{margin:5px 0 0;line-height:1.7}.notice{padding:12px;border-radius:8px;font-size:12px;line-height:1.7;margin-top:14px}.warning{background:#fff7e8;color:#805e21}.error{background:#fff0ef;color:#a43d36}.state{padding:25px;text-align:center}.links{display:flex;gap:12px;flex-wrap:wrap;margin-top:16px}.links a{color:#287caf;text-decoration:none;font-weight:700;font-size:12px}button{border:0;border-radius:7px;padding:7px 12px;background:#287caf;color:#fff;font:inherit}
  `]
})
export class AccountProfileComponent implements OnInit {
  private readonly api = inject(RegistrationSubmissionApiService);
  private readonly auth = inject(SupabaseAuthService);
  status: RegistrationStatus | null = null;
  email: string | null = null;
  loading = false;
  error = '';

  ngOnInit(): void { void this.load(); }

  async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      [this.email, this.status] = await Promise.all([this.auth.getCurrentUserEmail(), this.api.getMyStatus()]);
    } catch {
      this.error = 'تعذر تحميل حالة الحساب من الخادم. لا يمكن استنتاج صلاحياتك من بيانات محلية.';
    } finally { this.loading = false; }
  }

  stateLabel(state: string | null): string {
    switch (state) {
      case 'active': return 'نشط';
      case 'pending': return 'بانتظار الاعتماد';
      case 'suspended': return 'موقوف';
      case 'disabled': return 'معطل';
      case 'rejected': return 'مرفوض';
      default: return 'غير معروف';
    }
  }

  formatDate(value: string): string {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? 'غير متاح' : `${parsed.toISOString()} UTC`;
  }
}
