import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { SupabaseAuthService } from '../../core/supabase/supabase-auth.service';

@Component({
  standalone: true,
  selector: 'metra-forgot-password',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="page" dir="rtl"><section class="card">
      <span class="eyebrow">أمن الحساب</span><h1>استعادة كلمة المرور</h1>
      <p>أدخل البريد الإلكتروني المرتبط بحسابك. ستظهر رسالة عامة لا تكشف ما إذا كان الحساب موجوداً.</p>
      @if (!sent) {
        <form (ngSubmit)="submit()">
          <label>البريد الإلكتروني<input type="email" name="email" [(ngModel)]="email" required maxlength="254" autocomplete="email"></label>
          @if (error) { <div class="error" role="alert">{{ error }}</div> }
          <button type="submit" [disabled]="busy || !email.trim()">{{ busy ? 'جارٍ الإرسال…' : 'إرسال رابط الاستعادة' }}</button>
        </form>
      } @else {
        <div class="success" role="status">إذا كان البريد مرتبطاً بحساب، فستصلك رسالة تحتوي رابط الاستعادة. تحقق من صندوق الوارد والبريد غير المرغوب فيه.</div>
      }
      <a routerLink="/login">العودة إلى تسجيل الدخول</a>
    </section></main>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#263b4b}.page{min-height:60vh;display:grid;place-items:center}.card{width:min(100%,440px);background:#fff;border:1px solid #e4ebef;border-radius:14px;padding:26px;box-shadow:0 7px 24px #2233440b}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:23px;margin:8px 0}p{font-size:13px;color:#71808b;line-height:1.8}form{display:grid;gap:14px;margin:18px 0}label{display:grid;gap:7px;font-size:12px;font-weight:700}input{padding:11px;border:1px solid #d8e2e8;border-radius:8px;font:inherit;direction:ltr;text-align:left}button{border:0;border-radius:8px;padding:12px;background:#287caf;color:white;font:inherit;font-weight:700}button:disabled{opacity:.5}.error{color:#a33d35;font-size:12px}.success{background:#eaf7ef;color:#247247;border-radius:9px;padding:14px;font-size:13px;line-height:1.8;margin:18px 0}a{color:#287caf;text-decoration:none;font-size:12px;font-weight:700}
  `]
})
export class ForgotPasswordComponent {
  private readonly auth = inject(SupabaseAuthService);
  email = '';
  busy = false;
  sent = false;
  error = '';

  async submit(): Promise<void> {
    if (this.busy || !this.email.trim()) return;
    this.busy = true;
    this.error = '';
    try {
      const redirectTo = new URL('/auth/reset-password', window.location.origin).toString();
      await this.auth.sendPasswordRecovery(this.email.trim(), redirectTo);
      this.sent = true;
    } catch {
      this.error = 'تعذر إرسال طلب الاستعادة حالياً. تحقق من الاتصال ثم أعد المحاولة.';
    } finally { this.busy = false; }
  }
}
