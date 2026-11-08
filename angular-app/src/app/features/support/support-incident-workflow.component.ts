import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { StationContextService } from '../../core/station/station-context.service';
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
          <p>دورة الحادث: تقديم → مراجعة → إسناد → معالجة → إغلاق، مع عزل المحطة.</p>
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
        <h2>متابعة الحوادث</h2>
        <div *ngIf="loading">جارٍ التحميل...</div>
        <div class="item" *ngFor="let row of rows">
          <div class="head">
            <strong>{{ row['title'] }}</strong>
            <span class="badge">{{ row['status'] }}</span>
            <span class="badge muted">{{ row['severity'] }}</span>
          </div>
          <p>{{ row['description'] }}</p>
          <div class="actions">
            <button type="button" class="secondary" (click)="openDetail(row)" [disabled]="detailLoading">تفاصيل من الخادم</button>
            <button type="button" *ngFor="let action of nextActions(statusOf(row))"
              [disabled]="busyId === row['id']"
              (click)="transition(row, action.status)">{{ action.label }}</button>
          </div>
        </div>
        <p *ngIf="!loading && rows.length === 0">لا توجد بلاغات.</p>
      </section>

      <section class="card detail" *ngIf="detail">
        <div class="head">
          <h2>تفاصيل البلاغ</h2>
          <button type="button" class="secondary" (click)="closeDetail()">إغلاق</button>
        </div>
        <dl>
          <dt>المعرّف</dt><dd><code>{{ detail['id'] }}</code></dd>
          <dt>المحطة</dt><dd><code>{{ detail['station_id'] }}</code></dd>
          <dt>الحالة</dt><dd>{{ detail['status'] }}</dd>
          <dt>الأولوية</dt><dd>{{ detail['severity'] }}</dd>
          <dt>النوع</dt><dd>{{ detail['kind'] }}</dd>
          <dt>التصنيف</dt><dd>{{ detail['category'] }}</dd>
          <dt>العنوان</dt><dd>{{ detail['title'] }}</dd>
          <dt>الوصف</dt><dd>{{ detail['description'] }}</dd>
          <dt>الجهاز/الخدمة</dt><dd>{{ detail['affected_asset'] || '—' }}</dd>
          <dt>وقت الحدوث</dt><dd>{{ detail['occurred_at'] }}</dd>
        </dl>
      </section>

      <section class="return-dialog" *ngIf="pending" role="dialog">
        <div class="return-panel">
          <h2>{{ pending.label }}</h2>
          <label>ملاحظة
            <textarea [(ngModel)]="note" rows="3" maxlength="1000"></textarea>
          </label>
          <div class="return-actions">
            <button type="button" (click)="cancel()" [disabled]="!!busyId">إلغاء</button>
            <button type="button" (click)="confirm()" [disabled]="!!busyId">تأكيد</button>
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
    .item{border:1px solid #e2e8f0;border-radius:10px;padding:.85rem;margin-bottom:.75rem}
    .head{display:flex;gap:.4rem;flex-wrap:wrap;align-items:center}
    .badge{background:#ecfeff;color:#155e75;border-radius:999px;padding:.15rem .55rem;font-size:.85rem}
    .badge.muted{background:#f1f5f9;color:#475569}
    .actions{display:flex;flex-wrap:wrap;gap:.4rem;margin-top:.5rem}
    .actions button{background:#334155}
    button.secondary{background:#475569}
    .detail dl{display:grid;grid-template-columns:140px 1fr;gap:.35rem .75rem}
    .detail dt{color:#64748b}
    .detail dd{margin:0}
    .return-dialog{position:fixed;inset:0;background:rgba(15,23,42,.45);display:grid;place-items:center}
    .return-panel{background:#fff;border-radius:12px;padding:1rem;width:min(92vw,420px);display:grid;gap:.75rem}
    .return-actions{display:flex;gap:.5rem;justify-content:flex-end}
  `]
})
export class SupportIncidentWorkflowComponent implements OnInit {
  readonly api = inject(SupportIncidentApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);
  stationId = '';
  rows: Record<string, unknown>[] = [];
  detail: Record<string, unknown> | null = null;
  detailLoading = false;
  loading = false;
  saving = false;
  busyId: string | null = null;
  error = '';
  feedback = '';
  note = '';
  pending: { row: Record<string, unknown>; status: string; label: string } | null = null;
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
    this.stationId = this.stationContext.resolveStationId(this.route);
    this.route.queryParamMap.subscribe((params) => {
      const fromQuery = params.get('stationId')?.trim() ?? '';
      if (this.stationContext.isUuid(fromQuery)) {
        this.stationContext.remember(fromQuery);
        this.stationId = fromQuery;
      } else {
        this.stationId = this.stationContext.resolveStationId(this.route);
      }
      if (this.stationId && this.api.isConfigured) void this.load();
    });
  }

  statusOf(row: Record<string, unknown>): string {
    return String(row['status'] || '');
  }

  cancel(): void {
    if (this.busyId) return;
    this.pending = null;
    this.note = '';
  }

  nextActions(status: string): Array<{ status: string; label: string }> {
    switch (status) {
      case 'Submitted':
        return [{ status: 'UnderReview', label: 'بدء المراجعة' }, { status: 'Rejected', label: 'رفض' }];
      case 'UnderReview':
        return [{ status: 'Assigned', label: 'إسناد' }, { status: 'Rejected', label: 'رفض' }];
      case 'Assigned':
        return [{ status: 'InProgress', label: 'بدء المعالجة' }, { status: 'UnderReview', label: 'إعادة للمراجعة' }];
      case 'InProgress':
        return [
          { status: 'WaitingForInformation', label: 'بانتظار معلومات' },
          { status: 'Resolved', label: 'حل' },
          { status: 'Assigned', label: 'إعادة إسناد' },
        ];
      case 'WaitingForInformation':
        return [{ status: 'InProgress', label: 'استئناف' }, { status: 'Resolved', label: 'حل' }];
      case 'Resolved':
        return [{ status: 'Closed', label: 'إغلاق' }, { status: 'InProgress', label: 'إعادة فتح' }];
      default:
        return [];
    }
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


  closeDetail(): void {
    this.detail = null;
  }

  async openDetail(row: Record<string, unknown>): Promise<void> {
    if (!this.stationId || this.detailLoading) return;
    const id = String(row['id'] || '');
    if (!id) return;
    this.detailLoading = true;
    this.error = '';
    try {
      this.detail = (await this.api.getById(this.stationId, id)) as Record<string, unknown>;
      if (this.detail['station_id'] && String(this.detail['station_id']) !== this.stationId) {
        this.detail = null;
        this.error = 'رُفض عرض تفاصيل بلاغ لا ينتمي إلى محطتك.';
      }
    } catch (error: unknown) {
      this.detail = null;
      this.error = this.errorMessage(error);
    } finally {
      this.detailLoading = false;
    }
  }

  transition(row: Record<string, unknown>, status: string): void {
    const label = this.nextActions(String(row['status'] || '')).find((a) => a.status === status)?.label ?? status;
    this.pending = { row, status, label };
    this.note = '';
  }

  async confirm(): Promise<void> {
    if (!this.stationId || !this.pending || this.busyId) return;
    if ((this.pending.status === 'Rejected' || this.pending.status === 'Closed') && !this.note.trim()) {
      this.error = 'الملاحظة مطلوبة للإغلاق أو الرفض.';
      return;
    }
    const id = String(this.pending.row['id'] || '');
    this.busyId = id;
    this.error = '';
    try {
      await this.api.transition(this.stationId, id, this.pending.status, this.note.trim() || undefined);
      this.feedback = `تم تنفيذ الانتقال: ${this.pending.label}`;
      this.pending = null;
      this.note = '';
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
      if (error.status === 403) return 'ليست لديك صلاحية هذا الإجراء.';
      if (error.status === 400) return 'بيانات الطلب غير صالحة.';
      if (error.status === 409) return 'انتقال الحالة غير مسموح.';
      if (error.status === 503) return 'خدمة الدعم غير متاحة (جداول القاعدة قد تكون غير مفعّلة).';
      return `رفض الخادم الطلب (HTTP ${error.status}).`;
    }
    return error instanceof Error ? error.message : 'حدث خطأ غير متوقع.';
  }
}
