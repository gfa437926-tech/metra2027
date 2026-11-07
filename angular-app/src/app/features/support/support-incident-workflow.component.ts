import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { SupportIncidentApiService } from '../../core/api/support-incident-api.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page" dir="rtl">
      <header>
        <div>
          <span class="eyebrow">الصيانة والدعم</span>
          <h1>بلاغات الدعم</h1>
          <p>بلاغات تقنية المعلومات والاتصالات ضمن نطاق المحطة.</p>
        </div>
        <button type="button" (click)="load()" [disabled]="loading || !stationId">تحديث</button>
      </header>
      <section class="notice" *ngIf="!api.isConfigured">يلزم ضبط عنوان API وتسجيل الدخول.</section>
      <section class="notice" *ngIf="api.isConfigured && !stationId">افتح الشاشة مع <code>?stationId=UUID</code>.</section>
      <section class="notice error" *ngIf="error">{{ error }}</section>
      <section class="notice success" *ngIf="feedback">{{ feedback }}</section>

      <section class="card" *ngIf="stationId && api.isConfigured">
        <h2>بلاغ جديد</h2>
        <form (ngSubmit)="submit()" #f="ngForm">
          <label>النوع
            <select name="kind" [(ngModel)]="form.kind" required>
              <option value="InformationTechnology">تقنية معلومات</option>
              <option value="Telecommunications">اتصالات</option>
            </select>
          </label>
          <label>التصنيف <input name="category" [(ngModel)]="form.category" required minlength="2" maxlength="80" /></label>
          <label>العنوان <input name="title" [(ngModel)]="form.title" required minlength="5" maxlength="160" /></label>
          <label>الوصف <textarea name="desc" [(ngModel)]="form.description" required minlength="10" maxlength="5000" rows="4"></textarea></label>
          <label>الجهاز/الخدمة (اختياري) <input name="asset" [(ngModel)]="form.affectedAsset" maxlength="160" /></label>
          <label>الأولوية
            <select name="severity" [(ngModel)]="form.severity" required>
              <option>Low</option><option>Normal</option><option>High</option><option>Critical</option>
            </select>
          </label>
          <label class="check"><input type="checkbox" name="impact" [(ngModel)]="form.impactsOperations" /> يؤثر على سير العمل</label>
          <button type="submit" [disabled]="saving || f.invalid">{{ saving ? 'جارٍ الإرسال...' : 'إرسال إلى الخادم' }}</button>
        </form>
      </section>

      <section class="card">
        <h2>بلاغات المحطة</h2>
        <div *ngIf="loading">جارٍ التحميل...</div>
        <table *ngIf="!loading">
          <thead><tr><th>العنوان</th><th>النوع</th><th>الحالة</th><th>الأولوية</th></tr></thead>
          <tbody>
            <tr *ngFor="let row of rows">
              <td>{{ row['title'] }}</td>
              <td>{{ row['kind'] }}</td>
              <td>{{ row['status'] }}</td>
              <td>{{ row['severity'] }}</td>
            </tr>
            <tr *ngIf="rows.length === 0"><td colspan="4">لا توجد بلاغات.</td></tr>
          </tbody>
        </table>
      </section>
    </div>
  `,
  styles: [`
    .page{max-width:960px;margin:0 auto;padding:1rem}
    header{display:flex;justify-content:space-between;gap:1rem;margin-bottom:1rem}
    .card{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:1rem;margin-bottom:1rem}
    form{display:grid;gap:.75rem}
    label{display:grid;gap:.35rem;font-weight:600}
    input,select,textarea,button{font:inherit;padding:.5rem .65rem;border-radius:8px;border:1px solid #cbd5e1}
    button{background:#0f766e;color:#fff;border:none;cursor:pointer}
    button:disabled{opacity:.6}
    .check{display:flex;align-items:center;gap:.5rem;font-weight:500}
    .notice{padding:.75rem 1rem;border-radius:8px;background:#f8fafc;margin-bottom:.75rem}
    .notice.error{background:#fef2f2;color:#991b1b}
    .notice.success{background:#ecfdf5;color:#065f46}
    table{width:100%;border-collapse:collapse}
    th,td{border-bottom:1px solid #e2e8f0;padding:.5rem;text-align:right}
  `]
})
export class SupportIncidentWorkflowComponent implements OnInit {
  readonly api = inject(SupportIncidentApiService);
  private readonly route = inject(ActivatedRoute);
  stationId = '';
  rows: Record<string, unknown>[] = [];
  loading = false;
  saving = false;
  error = '';
  feedback = '';
  form = {
    kind: 'InformationTechnology',
    category: '',
    title: '',
    description: '',
    affectedAsset: '',
    severity: 'High',
    impactsOperations: false,
  };

  ngOnInit(): void {
    this.route.queryParamMap.subscribe((params) => {
      this.stationId = params.get('stationId')?.trim() ?? '';
      if (this.stationId && this.api.isConfigured) void this.load();
    });
  }

  async load(): Promise<void> {
    if (!this.stationId || !this.api.isConfigured || this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      this.rows = (await this.api.list(this.stationId, 100)) as Record<string, unknown>[];
    } catch (error: unknown) {
      this.error = this.errorMessage(error);
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  async submit(): Promise<void> {
    if (!this.stationId || this.saving) return;
    this.saving = true;
    this.error = '';
    this.feedback = '';
    try {
      await this.api.submit(this.stationId, {
        kind: this.form.kind,
        category: this.form.category.trim(),
        title: this.form.title.trim(),
        description: this.form.description.trim(),
        affectedAsset: this.form.affectedAsset.trim() || null,
        severity: this.form.severity,
        occurredAt: new Date().toISOString(),
        impactsOperations: this.form.impactsOperations,
      });
      this.feedback = 'تم إرسال بلاغ الدعم إلى الخادم.';
      this.form.category = '';
      this.form.title = '';
      this.form.description = '';
      this.form.affectedAsset = '';
      await this.load();
    } catch (error: unknown) {
      this.error = this.errorMessage(error);
    } finally {
      this.saving = false;
    }
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 401) return 'يلزم تسجيل الدخول.';
      if (error.status === 403) return 'ليست لديك صلاحية بلاغات هذه المحطة.';
      if (error.status === 400) return 'بيانات البلاغ غير صالحة.';
      if (error.status === 503) return 'خدمة الدعم غير متاحة (جداول القاعدة قد تكون غير مفعّلة).';
      return `رفض الخادم الطلب (HTTP ${error.status}).`;
    }
    return error instanceof Error ? error.message : 'حدث خطأ غير متوقع.';
  }
}
