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
          <p>دورة البلاغ: تقديم → مراجعة → إسناد → تنفيذ → حل → إغلاق، مع عزل المحطة.</p>
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
        <h2>متابعة بلاغات المحطة</h2>
        <div *ngIf="loading">جارٍ التحميل...</div>
        <div class="fault" *ngFor="let row of rows">
          <div class="fault-head">
            <strong>{{ row.equipment_name }}</strong>
            <span class="badge">{{ row.status }}</span>
            <span class="badge muted">{{ row.severity }}</span>
            <span class="badge muted" *ngIf="row.progress_percent != null">{{ row.progress_percent }}%</span>
          </div>
          <p>{{ row.description }}</p>
          <p class="meta">{{ row.equipment_category }} — {{ row.occurred_at | date:'medium' }}</p>
          <div class="actions" *ngIf="nextActions(row.status).length">
            <button
              type="button"
              *ngFor="let action of nextActions(row.status)"
              [disabled]="busyId === row.id"
              (click)="transition(row, action.status)">
              {{ action.label }}
            </button>
          </div>
        </div>
        <p *ngIf="!loading && rows.length === 0">لا توجد بلاغات.</p>
      </section>

      <section class="card" *ngIf="detail">
        <div class="fault-head">
          <strong>تفاصيل العطل من الخادم</strong>
          <button type="button" (click)="closeDetail()">إغلاق</button>
        </div>
        <p>{{ detail.equipment_category }} / {{ detail.equipment_name }} — {{ detail.status }}</p>
        <p>{{ detail.description }}</p>
        <p>المحطة: <code>{{ detail.station_id }}</code> — التقدم: {{ detail.progress_percent }}%</p>
      </section>

      <section class="return-dialog" *ngIf="pendingTransition" role="dialog">
        <div class="return-panel">
          <h2>{{ pendingTransition.label }}</h2>
          <p *ngIf="pendingTransition.requiresNote">ملاحظة مطلوبة للإغلاق أو الرفض.</p>
          <label *ngIf="pendingTransition.requiresNote || pendingTransition.allowsNote">
            الملاحظة
            <textarea [(ngModel)]="transitionNote" rows="3" maxlength="1000"></textarea>
          </label>
          <label *ngIf="pendingTransition.requiresProgress">
            نسبة الإنجاز
            <input type="number" min="0" max="100" [(ngModel)]="transitionProgress" />
          </label>
          <div class="return-actions">
            <button type="button" (click)="cancelTransition()" [disabled]="!!busyId">إلغاء</button>
            <button type="button" (click)="confirmTransition()" [disabled]="!!busyId">تأكيد</button>
          </div>
        </div>
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
    .fault{border:1px solid #e2e8f0;border-radius:10px;padding:.85rem;margin-bottom:.75rem}
    .fault-head{display:flex;flex-wrap:wrap;gap:.4rem;align-items:center;margin-bottom:.35rem}
    .badge{background:#ecfeff;color:#155e75;border-radius:999px;padding:.15rem .55rem;font-size:.85rem}
    .badge.muted{background:#f1f5f9;color:#475569}
    .meta{color:#64748b;font-size:.9rem}
    .actions{display:flex;flex-wrap:wrap;gap:.4rem;margin-top:.5rem}
    .actions button{background:#334155}
    .return-dialog{position:fixed;inset:0;background:rgba(15,23,42,.45);display:grid;place-items:center;z-index:20}
    .return-panel{background:#fff;border-radius:12px;padding:1rem;width:min(92vw,420px);display:grid;gap:.75rem}
    .return-actions{display:flex;gap:.5rem;justify-content:flex-end}
  `]
})
export class EquipmentFaultWorkflowComponent implements OnInit {
  readonly api = inject(EquipmentFaultApiService);
  private readonly route = inject(ActivatedRoute);

  stationId = '';
  rows: EquipmentFaultItem[] = [];
  detail: EquipmentFaultItem | null = null;
  detailLoading = false;
  loading = false;
  saving = false;
  busyId: string | null = null;
  error = '';
  feedback = '';
  transitionNote = '';
  transitionProgress = 100;
  pendingTransition: {
    row: EquipmentFaultItem;
    status: string;
    label: string;
    requiresNote: boolean;
    allowsNote: boolean;
    requiresProgress: boolean;
  } | null = null;

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

  nextActions(status: string): Array<{ status: string; label: string }> {
    switch (status) {
      case 'Submitted':
        return [
          { status: 'UnderReview', label: 'بدء المراجعة' },
          { status: 'Rejected', label: 'رفض' },
        ];
      case 'UnderReview':
        return [
          { status: 'Assigned', label: 'إسناد' },
          { status: 'Rejected', label: 'رفض' },
        ];
      case 'Assigned':
        return [
          { status: 'InProgress', label: 'بدء الإصلاح' },
          { status: 'UnderReview', label: 'إعادة للمراجعة' },
        ];
      case 'InProgress':
        return [
          { status: 'Resolved', label: 'تسجيل الحل' },
          { status: 'Assigned', label: 'إعادة الإسناد' },
        ];
      case 'Resolved':
        return [
          { status: 'Closed', label: 'إغلاق' },
          { status: 'InProgress', label: 'إعادة للتنفيذ' },
        ];
      default:
        return [];
    }
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

  closeDetail(): void {
    this.detail = null;
  }

  async openDetail(row: EquipmentFaultItem): Promise<void> {
    if (!this.stationId || this.detailLoading) return;
    this.detailLoading = true;
    this.error = '';
    try {
      this.detail = await this.api.getById(this.stationId, row.id);
      if (this.detail.station_id && this.detail.station_id !== this.stationId) {
        this.detail = null;
        this.error = 'رُفض عرض عطل لا ينتمي إلى محطتك.';
      }
    } catch (error: unknown) {
      this.detail = null;
      this.error = this.errorMessage(error);
    } finally {
      this.detailLoading = false;
    }
  }

  transition(row: EquipmentFaultItem, status: string): void {
    const label = this.nextActions(row.status).find((a) => a.status === status)?.label ?? status;
    this.pendingTransition = {
      row,
      status,
      label,
      requiresNote: status === 'Rejected' || status === 'Closed',
      allowsNote: true,
      requiresProgress: status === 'Resolved' || status === 'InProgress',
    };
    this.transitionNote = '';
    this.transitionProgress = status === 'Resolved' ? 100 : (row.progress_percent ?? 0);
  }

  cancelTransition(): void {
    if (this.busyId) return;
    this.pendingTransition = null;
    this.transitionNote = '';
  }

  async confirmTransition(): Promise<void> {
    if (!this.stationId || !this.pendingTransition || this.busyId) return;
    const pending = this.pendingTransition;
    if (pending.requiresNote && !this.transitionNote.trim()) {
      this.error = 'الملاحظة مطلوبة لهذا الانتقال.';
      return;
    }
    if (pending.requiresProgress && (this.transitionProgress < 0 || this.transitionProgress > 100)) {
      this.error = 'نسبة الإنجاز يجب أن تكون بين 0 و100.';
      return;
    }
    if (pending.status === 'Resolved' && this.transitionProgress !== 100) {
      this.error = 'لا يمكن تسجيل الحل قبل اكتمال الإنجاز 100٪.';
      return;
    }

    this.busyId = pending.row.id;
    this.error = '';
    this.feedback = '';
    try {
      await this.api.transition(
        this.stationId,
        pending.row.id,
        pending.status,
        this.transitionNote.trim() || undefined,
        pending.requiresProgress ? this.transitionProgress : undefined
      );
      this.feedback = `تم تنفيذ الانتقال: ${pending.label}`;
      this.pendingTransition = null;
      this.transitionNote = '';
      await this.load();
    } catch (error: unknown) {
      this.error = this.errorMessage(error);
    } finally {
      this.busyId = null;
    }
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 401) return 'يلزم تسجيل الدخول.';
      if (error.status === 403) return 'ليست لديك صلاحية هذا الإجراء على المحطة.';
      if (error.status === 400) return 'بيانات الطلب غير صالحة.';
      if (error.status === 409) return 'انتقال الحالة غير مسموح وفق دورة حياة البلاغ.';
      if (error.status === 503) return 'خدمة الأعطال غير متاحة (جداول القاعدة قد تكون غير مفعّلة).';
      return `رفض الخادم الطلب (HTTP ${error.status}).`;
    }
    return error instanceof Error ? error.message : 'حدث خطأ غير متوقع.';
  }
}
