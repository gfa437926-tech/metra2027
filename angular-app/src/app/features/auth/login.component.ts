import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { SupabaseAuthService } from '../../core/supabase/supabase-auth.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="login" dir="rtl">
      <section class="panel">
        <div class="mark"><i class="fa-solid fa-cloud-sun"></i></div>
        <h1>تسجيل الدخول إلى METRA 2027</h1>
        <p>استخدم حسابك المعتمد للوصول إلى وظائف النظام وفق صلاحياتك.</p>
        <form (ngSubmit)="submit()">
          <label>البريد الإلكتروني<input type="email" name="email" [(ngModel)]="email" autocomplete="username" required></label>
          <label>كلمة المرور<input type="password" name="password" [(ngModel)]="password" autocomplete="current-password" required></label>
          <p class="error" *ngIf="error" role="alert">{{ error }}</p>
          <button type="submit" [disabled]="busy || !auth.isConfigured">{{ busy ? 'جارٍ التحقق...' : 'تسجيل الدخول' }}</button>
          <p class="hint">ليس لديك حساب؟ <a routerLink="/register" [queryParams]="{returnUrl: '/register'}">إنشاء حساب وطلب الانضمام</a></p>
        </form>
        <p class="hint" *ngIf="!auth.isConfigured">إعدادات Supabase العامة غير مهيأة في بيئة النشر.</p>
      </section>
    </main>
  `,
  styles: [`
    :host{display:block;min-height:65vh}.login{min-height:65vh;display:grid;place-items:center}.panel{width:min(100%,440px);background:#fff;border-radius:15px;padding:30px;box-shadow:0 8px 28px #22334412}.mark{width:58px;height:58px;border-radius:50%;display:grid;place-items:center;margin:0 auto 14px;background:#eaf4fb;color:#2980b9;font-size:27px}h1{text-align:center;font-size:22px;margin:0 0 8px}p{text-align:center;color:#71808b;font-size:13px;line-height:1.8;margin:0 0 20px}form{display:grid;gap:15px}label{display:grid;gap:7px;font-size:13px;font-weight:700}input{font:inherit;border:1px solid #d8e0e6;border-radius:8px;padding:11px;direction:ltr;text-align:left}button{border:0;border-radius:8px;background:#287caf;color:white;padding:12px;font:inherit;font-weight:700;cursor:pointer}button:disabled{opacity:.5;cursor:not-allowed}.error{color:#b33b35;margin:0}.hint{margin:14px 0 0;color:#a05b13}
  `]
})
export class LoginComponent {
  readonly auth = inject(SupabaseAuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  email = '';
  password = '';
  busy = false;
  error = '';

  async submit(): Promise<void> {
    if (this.busy || !this.email.trim() || !this.password) return;
    this.busy = true;
    this.error = '';
    try {
      await this.auth.signInWithPassword(this.email.trim(), this.password);
      const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl') || '/';
      await this.router.navigateByUrl(returnUrl.startsWith('/') && !returnUrl.startsWith('//') ? returnUrl : '/');
    } catch (error: unknown) {
      this.error = error instanceof Error ? error.message : 'تعذر تسجيل الدخول.';
    } finally {
      this.busy = false;
    }
  }
}
