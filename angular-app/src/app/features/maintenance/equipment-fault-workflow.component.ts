import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import {
  EquipmentFaultApiService,
  EquipmentFaultItem,
} from '../../core/api/equipment-fault-api.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page" dir="rtl">
      <header>
        <div>
          <span class="eyebrow">الصيانة والدعم</span>
          <h1>أعطال المعدات</h1>
          <p>إرسال بلاغات أعطال المعدات إلى الخادم ضمن نطاق المحطة وصلاحيات المستخدم.</p>
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
          <label>التصنيف
            <select name="category" [(ngModel)]="form.equipmentCategory" required>
              <option>أجهزة الرصد</option>
              <option>أجهزة الاتصالات</option>
              <option>أجهزة القياس</option>
              <option>أخرى</option>
            </select>
          </label>
          <label>اسم المعدة
            <input name="name" [(ngModel)]="form.equipmentName" required minlength="2" maxlength="120" />
          </label>
          <label>الوصف
            <textarea name="desc" [(ngModel)]="form.description" required minlength="10" maxlength="5000" rows="4"></textarea>
          </label>
          <label>الشدة
            <select name="severity" [(ngModel)]="form.severity" required>
              <option>Low</option><option>Medium</option><option>High</option><option>Critical</option>
            </select>
          </label>
          <label class="check">
            <input type="checkbox" name="blocking" [(ngModel)]="form.isOperationallyBlocking" />
            يعطل التشغيل التشغيلي
          </label>
          <button type="submit" [disabled]="saving || f.invalid">{{ saving ? 'جارٍ الإرسال...' : 'إرسال إلى الخادم' }}</button>
        </form>
      </section>

      <section class="card">
        <h2>بلاغات المحطة</h2>
        <div *ngIf="loading">جارٍ التحميل...</div>
        <table *ngIf="!loading">
          <thead>
            <tr><th>المعدة</th><th>الشدة</th><th>الحالة</th><th>الوصف</th></tr>
          </thead>
          <tbody>
            <tr *ngFor="let row of rows">
              <td>{{ row.equipment_name }}</td>
              <td>{{ row.severity }}</td>
              <td>{{ row.status }}</td>
              <td>{{ row.description }}</td>
            </tr>
            <tr *ngIf="rows.length === 0"><td colspan="4">لا توجد بلاغات.</td></tr>
          </tbody>
        </table>
      </section>
    </div>
  `,
  styles: [`
    .page{max-width:960px;margin:0 auto;padding:1rem}
    header{display:flex;justify-content:space-between;gap:1rem;align-items:flex-start;margin-bottom:1rem}
    .card{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:1rem;margin-bottom:1rem}
    form{display:grid;gap:.75rem}
    label{display:grid;gap:.35rem;font-weight:600}
    input,select,textarea,button{font:inherit;padding:.5rem .65rem;border-radius:8px;border:1px solid #cbd5e1}
    button{background:#0f766e;color:#fff;border:none;cursor:pointer}
    button:disabled{opacity:.6;cursor:not-allowed}
    .check{display:flex;align-items:center;gap:.5rem;font-weight:500}
    .notice{padding:.75rem 1rem;border-radius:8px;background:#f8fafc;margin-bottom:.75rem}
    .notice.error{background:#fef2f2;color:#991b1b}
    .notice.success{background:#ecfdf5;color:#065f46}
    table{width:100%;border-collapse:collapse}
    th,td{border-bottom:1px solid #e2e8f0;padding:.5rem;text-align:right;vertical-align:top}
  `]
})
export class EquipmentFaultWorkflowComponent implements OnInit {
  readonly api = inject(EquipmentFaultApiService);
  private readonly route = inject(ActivatedRoute);

  stationId = '';
  rows: EquipmentFaultItem[] = [];
  loading = false;
  saving = false;
  error = '';
  feedback = '';
  form = {
    equipmentCategory: 'أجهزة الرصد',
    equipmentName: '',
    description: '',
    severity: 'High',
    isOperationallyBlocking: false,
  };

  ngOnInit(): void {
    this.route.queryParamMap.subscribe((params) => {
      this.stationId = params.get('stationId')?.trim() ?? '';
      this.error = '';
      if (this.stationId && this.api.isConfigured) void this.load();
    });
  }

  async load(): Promise<void> {
    if (!this.stationId || !this.api.isConfigured || this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      this.rows = await this.api.list(this.stationId, 100);
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
        equipmentCategory: this.form.equipmentCategory,
        equipmentName: this.form.equipmentName.trim(),
        description: this.form.description.trim(),
        severity: this.form.severity,
        occurredAt: new Date().toISOString(),
        isOperationallyBlocking: this.form.isOperationallyBlocking,
      });
      this.feedback = 'تم إرسال بلاغ العطل إلى الخادم.';
      this.form.equipmentName = '';
      this.form.description = '';
      this.form.isOperationallyBlocking = false;
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
      if (error.status === 403) return 'ليست لديك صلاحية أعطال هذه المحطة.';
      if (error.status === 400) return 'بيانات البلاغ غير صالحة.';
      if (error.status === 503) return 'خدمة الأعطال غير متاحة (قد تكون جداول القاعدة غير مفعّلة).';
      return `رفض الخادم الطلب (HTTP ${error.status}).`;
    }
    return error instanceof Error ? error.message : 'حدث خطأ غير متوقع.';
  }
}
