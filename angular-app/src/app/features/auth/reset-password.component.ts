import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { SupabaseAuthService } from '../../core/supabase/supabase-auth.service';

@Component({
  standalone: true,
  selector: 'metra-reset-password',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <main class="page" dir="rtl"><section class="card">
      <span class="eyebrow">أمن الحساب</span><h1>تعيين كلمة مرور جديدة</h1>
      @if (checking) { <p>جارٍ التحقق من رابط الاستعادة…</p> }
      @else if (!validSession) {
        <div class="error" role="alert">رابط الاستعادة غير صالح أو انتهت صلاحيته. اطلب رابطاً جديداً.</div>
        <a routerLink="/forgot-password">طلب رابط استعادة جديد</a>
      } @else if (updated) {
        <div class="success" role="status">تم تحديث كلمة المرور. يمكنك تسجيل الدخول الآن.</div>
        <a routerLink="/login">الانتقال إلى تسجيل الدخول</a>
      } @else {
        <form (ngSubmit)="submit()">
          <label>كلمة المرور الجديدة<input type="password" name="password" [(ngModel)]="password" minlength="8" maxlength="128" required autocomplete="new-password"></label>
          <label>تأكيد كلمة المرور<input type="password" name="confirmation" [(ngModel)]="confirmation" minlength="8" maxlength="128" required autocomplete="new-password"></label>
          @if (error) { <div class="error" role="alert">{{ error }}</div> }
          <button type="submit" [disabled]="busy || password.length < 8 || password !== confirmation">{{ busy ? 'جارٍ التحديث…' : 'تحديث كلمة المرور' }}</button>
        </form>
      }
    </section></main>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#263b4b}.page{min-height:60vh;display:grid;place-items:center}.card{width:min(100%,440px);background:#fff;border:1px solid #e4ebef;border-radius:14px;padding:26px;box-shadow:0 7px 24px #2233440b}.eyebrow{font-size:12px;color:#287caf;font-weight:800}h1{font-size:23px;margin:8px 0}form{display:grid;gap:14px;margin:18px 0}label{display:grid;gap:7px;font-size:12px;font-weight:700}input{padding:11px;border:1px solid #d8e2e8;border-radius:8px;font:inherit;direction:ltr;text-align:left}button{border:0;border-radius:8px;padding:12px;background:#287caf;color:white;font:inherit;font-weight:700}button:disabled{opacity:.5}.error{background:#fff0ef;color:#a33d35;border-radius:8px;padding:12px;font-size:12px}.success{background:#eaf7ef;color:#247247;border-radius:9px;padding:14px;font-size:13px;line-height:1.8;margin:18px 0}a{color:#287caf;text-decoration:none;font-size:12px;font-weight:700}
  `]
})
export class ResetPasswordComponent implements OnInit {
  private readonly auth = inject(SupabaseAuthService);
  private readonly router = inject(Router);
  checking = true;
  validSession = false;
  busy = false;
  updated = false;
  error = '';
  password = '';
  confirmation = '';

  async ngOnInit(): Promise<void> {
    try { this.validSession = Boolean(await this.auth.getAccessToken()); }
    catch { this.validSession = false; }
    finally { this.checking = false; }
  }

  async submit(): Promise<void> {
    if (this.busy || this.password.length < 8 || this.password !== this.confirmation) return;
    this.busy = true;
    this.error = '';
    try {
      await this.auth.updatePassword(this.password);
      this.updated = true;
      this.password = '';
      this.confirmation = '';
      await this.auth.signOut();
    } catch (error: unknown) {
      this.error = error instanceof Error ? error.message : 'تعذر تحديث كلمة المرور.';
    } finally { this.busy = false; }
  }
}
