import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { StationContextService } from '../../core/station/station-context.service';
import { StationPickerComponent } from '../../core/station/station-picker.component';
import { ObservationApiService, ObservationQueueItem } from '../../core/api/observation-api.service';
import { EditableObservationField, buildEditableFields, fieldsToPayload, validateEditableFields } from './observation-field-labels';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule, StationPickerComponent],
  template: `
    <div class="page" dir="rtl">
      <header>
        <div>
          <span class="eyebrow"><i class="fa-solid fa-list-check"></i> إدارة ومتابعة السجلات</span>
          <h1>مراجعة النشرات الجوية</h1>
          <p>قائمة النشرات المرسلة فعلياً إلى قاعدة البيانات للمراجعة على مستوى المحطة.</p>
        </div>
        <button type="button" class="refresh" (click)="load()" [disabled]="loading || !stationId">
          <i class="fa-solid fa-rotate" [class.spin]="loading"></i> تحديث القائمة
        </button>
      </header>

      <metra-station-picker [stationId]="stationId" (stationIdChange)="onStationPicked($event)"></metra-station-picker>

      <section class="notice" *ngIf="!api.isConfigured">
        <i class="fa-solid fa-triangle-exclamation"></i>
        <div><strong>إعداد الاتصال غير مكتمل</strong><p>اضبط apiBaseUrl وsupabaseUrl وsupabaseAnonKey في إعدادات التشغيل، ثم سجّل دخول المستخدم.</p></div>
      </section>
      <section class="notice" *ngIf="api.isConfigured && !stationId">
        <i class="fa-solid fa-location-dot"></i>
        <div><strong>يلزم تحديد المحطة</strong><p>افتح شاشة المراجعة مع معرّف المحطة: <code>?stationId=UUID</code>. لا يتم افتراض محطة أو اختيارها تلقائياً.</p></div>
      </section>
      <section class="notice error" *ngIf="error" role="alert">
        <i class="fa-solid fa-circle-exclamation"></i><div><strong>تعذر تحميل قائمة المراجعة</strong><p>{{ error }}</p></div>
      </section>
      <section class="notice success" *ngIf="feedback" role="status">
        <i class="fa-solid fa-circle-check"></i><div><strong>{{ feedback }}</strong></div>
      </section>

      <section class="stats">
        <article><span>النشرات المعروضة</span><strong>{{ rows.length }}</strong></article>
        <article><span>بانتظار القرار</span><strong>{{ rows.length }}</strong></article>
        <article><span>مصدر البيانات</span><strong class="source">الخادم</strong></article>
      </section>

      <div class="tabs">
        <button type="button" [class.active]="activeTab==='review'" (click)="activeTab='review'; load()">طابور المراجعة</button>
        <button type="button" [class.active]="activeTab==='returned'" (click)="activeTab='returned'; loadReturned()">مُرجَعة لإعادة التقديم</button>
      </div>

      <section class="card" *ngIf="activeTab==='review'">
        <div class="card-heading"><div><h2>قائمة النشرات المرسلة</h2><p>تظهر هنا السجلات ذات الحالة submitted فقط وفق صلاحيات المحطة.</p></div>
          <span class="count">{{ rows.length }} سجل</span>
        </div>
        <div class="loading" *ngIf="loading"><i class="fa-solid fa-spinner spin"></i> جارٍ تحميل البيانات من الخادم...</div>
        <div class="table-wrap" *ngIf="!loading">
          <table>
            <thead><tr><th>معرّف النشرة</th><th>نوع النشرة</th><th>وقت الرصد</th><th>وقت الإرسال</th><th>معرّف الراصد</th><th>الحالة</th><th>الإجراء</th></tr></thead>
            <tbody>
              <tr *ngFor="let row of rows">
                <td data-label="معرّف النشرة"><code>{{ row.id }}</code></td>
                <td data-label="نوع النشرة">{{ typeLabel(row.observation_type) }}</td>
                <td data-label="وقت الرصد">{{ dateLabel(row.observed_at) }}</td>
                <td data-label="وقت الإرسال">{{ dateLabel(row.submitted_at) }}</td>
                <td data-label="معرّف الراصد"><code>{{ row.created_by }}</code></td>
                <td data-label="الحالة"><span class="status">بانتظار المراجعة</span></td>
                <td class="actions" data-label="الإجراء">
                  <button type="button" class="approve" (click)="decide(row, 'approve')" [disabled]="busyId !== null">اعتماد</button>
                  <button type="button" class="return" (click)="decide(row, 'return_for_correction')" [disabled]="busyId !== null">إرجاع</button>
                </td>
              </tr>
              <tr *ngIf="rows.length === 0"><td colspan="7" class="empty">لا توجد نشرات مرسلة للمراجعة لهذه المحطة، أو لم يتم تحميل القائمة بعد.</td></tr>
            </tbody>
          </table>
        </div>
      </section>
      
      <section class="panel" *ngIf="activeTab==='returned'">
        <div class="heading"><div><h2>نشراتك المُرجَعة للتصحيح</h2>
          <p>تظهر هنا نشراتك ذات الحالة returned فقط. يمكنك إعادة تقديمها بعد التصحيح.</p></div>
          <span class="count">{{ returnedRows.length }} سجل</span>
        </div>
        <div class="loading" *ngIf="loading"><i class="fa-solid fa-spinner spin"></i> جارٍ التحميل...</div>
        <div class="table-wrap" *ngIf="!loading">
          <table>
            <thead><tr><th>المعرّف</th><th>النوع</th><th>وقت الرصد</th><th>ملاحظة المراجع</th><th>إجراء</th></tr></thead>
            <tbody>
              <tr *ngFor="let row of returnedRows">
                <td><code>{{ row.id }}</code></td>
                <td>{{ typeLabel(row.observation_type) }}</td>
                <td>{{ dateLabel(row.observed_at) }}</td>
                <td>{{ row['review_note'] || '—' }}</td>
                <td><button type="button" class="approve" (click)="openEditor(row)" [disabled]="busyId !== null || editSaving">تصحيح وإعادة التقديم</button></td>
              </tr>
              <tr *ngIf="returnedRows.length === 0"><td colspan="5" class="empty">لا توجد نشرات مُرجَعة لك في هذه المحطة.</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      
      <section class="return-dialog" *ngIf="editTarget" role="dialog" aria-modal="true" aria-labelledby="editTitle">
        <div class="return-panel edit-panel">
          <h2 id="editTitle">تصحيح النشرة المُرجَعة</h2>
          <p class="review-note" *ngIf="editTarget.review_note">
            <strong>ملاحظة المراجع:</strong> {{ editTarget.review_note }}
          </p>
          <p class="review-note muted" *ngIf="!editTarget.review_note">لا توجد ملاحظة مكتوبة من المراجع.</p>
          <p class="meta">{{ typeLabel(editTarget.observation_type) }} — {{ dateLabel(editTarget.observed_at) }}</p>
          <div class="fields" *ngIf="editFields.length > 0">
            <div class="field" *ngFor="let field of editFields" [class.needs-attention]="field.highlighted" [class.has-error]="!!field.error">
              <label [attr.for]="'f-' + field.key">
                {{ field.label }}
                <code *ngIf="field.label !== field.key">({{ field.key }})</code>
                <span class="badge" *ngIf="field.highlighted">مطلوب التصحيح</span>
              </label>
              <input [id]="'f-' + field.key" type="text" [(ngModel)]="field.value" maxlength="200" [disabled]="editSaving" (ngModelChange)="field.error=''" />
              <small class="hint" *ngIf="field.hint && !field.error">{{ field.hint }}</small>
              <small class="field-error" *ngIf="field.error">{{ field.error }}</small>
            </div>
          </div>
          <p class="empty" *ngIf="editFields.length === 0">لا توجد حقول قابلة للتحرير في حمولة هذه النشرة.</p>
          <div class="return-actions">
            <button type="button" class="cancel" (click)="closeEditor()" [disabled]="editSaving">إلغاء</button>
            <button type="button" class="confirm-return" (click)="submitEditedResubmit()" [disabled]="editSaving || editFields.length === 0">
              {{ editSaving ? 'جارٍ الإرسال...' : 'حفظ وإعادة التقديم' }}
            </button>
          </div>
        </div>
      </section>

      <section class="return-dialog" *ngIf="returnTarget" role="dialog" aria-modal="true" aria-labelledby="returnTitle">
        <div class="return-panel">
          <h2 id="returnTitle">إرجاع النشرة للتصحيح</h2>
          <p>اكتب ملاحظة واضحة للراصد تشرح سبب الإرجاع. لا يمكن إرسال القرار دون سبب.</p>
          <label for="returnNote">سبب الإرجاع</label>
          <textarea id="returnNote" rows="4" maxlength="2000" [(ngModel)]="returnNote"
            placeholder="مثال: يرجى مراجعة قيمة درجة الحرارة ووقت الرصد..."></textarea>
          <div class="return-actions">
            <button type="button" class="cancel" (click)="cancelReturn()" [disabled]="busyId !== null">إلغاء</button>
            <button type="button" class="confirm-return" (click)="confirmReturn()"
              [disabled]="busyId !== null || !returnNote.trim()">تأكيد الإرجاع</button>
          </div>
        </div>
      </section>
      <p class="footnote">القرارات تُرسل إلى API وتُنفّذ وفق صلاحيات المستخدم وقواعد قاعدة البيانات. لا تُعرض بيانات تجريبية ولا يُغيّر أي سجل محلياً عند فشل الطلب.</p>
    </div>
  `,
  styles: [`
    .edit-panel{max-width:560px;width:min(96vw,560px);max-height:90vh;overflow:auto}
    .review-note{background:#fff7ed;border:1px solid #fdba74;border-radius:8px;padding:.75rem 1rem;margin:.5rem 0 1rem;color:#9a3412}
    .review-note.muted{background:#f8fafc;border-color:#e2e8f0;color:#64748b}
    .meta{color:#64748b;font-size:.9rem;margin-bottom:.75rem}
    .fields{display:grid;gap:.75rem;margin-bottom:1rem}
    .field label{display:block;font-weight:600;margin-bottom:.25rem}
    .field code{font-weight:400;color:#64748b;font-size:.85em}
    .field input{width:100%;padding:.5rem .65rem;border:1px solid #cbd5e1;border-radius:8px;font:inherit}

    .tabs{display:flex;gap:.5rem;margin-bottom:1rem}
    .tabs button{padding:.4rem .8rem;border:1px solid #cbd5e1;background:#f8fafc;border-radius:6px;cursor:pointer}
    .tabs button.active{background:#0f766e;color:#fff;border-color:#0f766e}

    :host{display:block;color:#2c3e50;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .page{max-width:1500px;margin:auto}header{display:flex;justify-content:space-between;align-items:center;gap:18px;margin-bottom:22px}.eyebrow{color:#287caf;font-size:13px;font-weight:800}.eyebrow i{margin-left:7px}h1{font-size:clamp(24px,3vw,32px);margin:8px 0;font-weight:800}h2{font-size:19px;margin:0 0 5px}p{margin:0;color:#7b8790;font-size:13px;line-height:1.8}
    button{font:inherit;cursor:pointer}.refresh{border:1px solid #cbd8e2;background:white;color:#2876a8;padding:10px 15px;border-radius:8px}.refresh:disabled,button:disabled{opacity:.5;cursor:not-allowed}
    .notice{display:flex;gap:12px;align-items:flex-start;background:#eaf4fb;border:1px solid #c9e2f3;border-right:4px solid #3498db;border-radius:10px;padding:14px 16px;margin-bottom:16px;color:#245575}.notice>i{font-size:20px;margin-top:3px}.notice.error{background:#fff0ee;border-color:#f4c7c2;border-right-color:#d9534f;color:#8e302c}.notice.success{background:#eaf7ef;border-color:#c8e8d2;border-right-color:#27ae60;color:#218348}.notice strong{font-size:14px}.notice code,td code{font-size:11px;overflow-wrap:anywhere}
    .stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-bottom:18px}.stats article,.card{background:#fff;border-radius:12px;padding:18px;box-shadow:0 5px 18px #2233440c}.stats article{display:grid;gap:7px;border-bottom:3px solid #3498db}.stats span{font-size:12px;color:#71808b}.stats strong{font-size:25px}.stats .source{font-size:17px;color:#218348}
    .card{padding:22px}.card-heading{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:18px}.count{background:#edf5fa;color:#2876a8;padding:6px 11px;border-radius:20px;font-size:12px;font-weight:700}.table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;white-space:nowrap}th{text-align:right;background:#f5f7f9;color:#697781;font-size:12px;padding:13px 11px}td{padding:13px 11px;border-bottom:1px solid #edf0f2;font-size:12px}tbody tr:hover{background:#f8fbfd}.status{background:#fff3cd;color:#946200;border-radius:20px;padding:5px 9px;font-size:11px;font-weight:700}.actions{display:flex;gap:6px}.actions button{border:0;border-radius:6px;padding:7px 10px;color:#fff;font-size:11px}.approve{background:#22965b}.return{background:#d9822b}.empty{text-align:center;color:#89949c;padding:30px}.loading{padding:30px;text-align:center;color:#61717d}.return-dialog{position:fixed;inset:0;z-index:1200;background:rgba(18,32,44,.52);display:grid;place-items:center;padding:18px}.return-panel{width:min(100%,520px);background:#fff;border-radius:14px;padding:24px;box-shadow:0 16px 50px #10203035}.return-panel h2{margin-bottom:8px}.return-panel label{display:block;font-size:13px;font-weight:700;margin:16px 0 7px}.return-panel textarea{width:100%;box-sizing:border-box;resize:vertical;border:1px solid #ccd7df;border-radius:8px;padding:11px;font:inherit;line-height:1.7}.return-actions{display:flex;justify-content:flex-start;gap:8px;margin-top:14px}.return-actions button{border:0;border-radius:7px;padding:9px 14px;font-size:12px}.cancel{background:#edf1f4;color:#4b5c68}.confirm-return{background:#d9822b;color:#fff}.return-actions button:disabled{opacity:.5;cursor:not-allowed}.footnote{margin-top:14px;font-size:11px;color:#85919a}.spin{display:inline-block;animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
    @media(max-width:700px){header,.card-heading{align-items:flex-start;flex-direction:column}.stats{grid-template-columns:1fr}.card{padding:14px}table,thead,tbody,tr,td{display:block}thead{display:none}tbody tr{border:1px solid #e8edf0;border-radius:9px;margin-bottom:12px;padding:7px}td{display:flex;justify-content:space-between;gap:10px;white-space:normal;overflow-wrap:anywhere;padding:8px 5px}td:before{content:attr(data-label);font-weight:700;color:#77838c}.actions{justify-content:flex-start}.empty{display:block}.empty:before{display:none}}
  `]
})
export class ObservationWorkflowComponent implements OnInit {
  readonly api = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);
  stationId = '';
  rows: ObservationQueueItem[] = [];
  returnedRows: ObservationQueueItem[] = [];
  activeTab: 'review' | 'returned' = 'review';
  editTarget: ObservationQueueItem | null = null;
  editFields: EditableObservationField[] = [];
  editSaving = false;
  loading = false;
  busyId: string | null = null;
  error = '';
  feedback = '';
  returnTarget: ObservationQueueItem | null = null;
  returnNote = '';

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    this.route.queryParamMap.subscribe(params => {
      const fromQuery = params.get('stationId')?.trim() ?? '';
      if (this.stationContext.isUuid(fromQuery)) {
        this.stationContext.remember(fromQuery);
        this.stationId = fromQuery;
      } else {
        this.stationId = this.stationContext.resolveStationId(this.route);
      }
      this.rows = [];
      this.error = '';
      if (this.stationId && this.api.isConfigured) void this.load();
    });
  }


  onStationPicked(stationId: string): void {
    this.stationId = stationId;
    this.error = '';
    if (this.stationId && this.api.isConfigured) {
      if (this.activeTab === 'returned') {
        void this.loadReturned();
      } else {
        void this.load();
      }
    }
  }

  async load(): Promise<void> {
    if (!this.stationId || !this.api.isConfigured || this.loading) return;
    this.loading = true;
    this.error = '';
    try {
      this.rows = await this.api.getReviewQueue(this.stationId, 100);
    } catch (error: unknown) {
      this.error = this.errorMessage(error);
      this.rows = [];
    } finally {
      this.loading = false;
    }
  }

  async loadReturned(): Promise<void> {
    if (!this.stationId) return;
    this.loading = true;
    this.error = '';
    try {
      this.returnedRows = await this.api.getReturnedObservations(this.stationId, 100);
    } catch (e: unknown) {
      this.error = this.errorMessage(e);
      this.returnedRows = [];
    } finally {
      this.loading = false;
    }
  }

  openEditor(row: ObservationQueueItem): void {
    if (this.busyId || this.editSaving) return;
    this.editTarget = row;
    const payload =
      (row.payload && typeof row.payload === 'object' && !Array.isArray(row.payload))
        ? row.payload as Record<string, unknown>
        : {};
    this.editFields = buildEditableFields(payload, row.review_note ?? row['review_note']);
    // Surface highlighted fields first so the observer sees reviewer cues immediately.
    this.editFields = [
      ...this.editFields.filter((f) => f.highlighted),
      ...this.editFields.filter((f) => !f.highlighted),
    ];
    this.error = '';
    this.feedback = '';
  }

  closeEditor(): void {
    if (this.editSaving) return;
    this.editTarget = null;
    this.editFields = [];
  }

  async submitEditedResubmit(): Promise<void> {
    if (!this.stationId || !this.editTarget || this.editSaving) return;
    if (this.editFields.length === 0) {
      this.error = 'لا توجد حقول لإعادة إرسالها.';
      return;
    }
    const validation = validateEditableFields(this.editFields);
    for (const field of this.editFields) {
      field.error = validation[field.key] ?? '';
    }
    if (Object.keys(validation).length > 0) {
      this.error = 'صحّح الحقول المعلّمة قبل إعادة التقديم.';
      return;
    }
    this.editSaving = true;
    this.error = '';
    this.feedback = '';
    const observationId = this.editTarget.id;
    const payload = fieldsToPayload(this.editFields);
    try {
      await this.api.resubmitObservation(this.stationId, observationId, payload);
      this.feedback = 'تم حفظ التصحيح وإعادة تقديم النشرة للمراجعة.';
      this.returnedRows = this.returnedRows.filter(r => r.id !== observationId);
      this.editTarget = null;
      this.editFields = [];
      await this.load();
    } catch (e: unknown) {
      this.error = this.errorMessage(e);
    } finally {
      this.editSaving = false;
    }
  }

  async decide(row: ObservationQueueItem, decision: 'approve' | 'return_for_correction', note = ''): Promise<void> {
    if (this.busyId) return;
    if (decision === 'return_for_correction' && !note.trim()) {
      this.returnTarget = row;
      this.returnNote = '';
      return;
    }
    this.busyId = row.id;
    this.error = '';
    this.feedback = '';
    try {
      await this.api.decide(this.stationId, row.id, decision, note);
      this.returnTarget = null;
      this.returnNote = '';
      await this.load();
      this.feedback = decision === 'approve' ? 'تم إرسال قرار الاعتماد بنجاح.' : 'تم إرسال قرار الإرجاع بنجاح.';
    } catch (error: unknown) {
      this.error = this.errorMessage(error);
    } finally {
      this.busyId = null;
    }
  }

  async confirmReturn(): Promise<void> {
    if (!this.returnTarget || !this.returnNote.trim() || this.busyId) return;
    await this.decide(this.returnTarget, 'return_for_correction', this.returnNote.trim());
  }

  cancelReturn(): void {
    if (this.busyId) return;
    this.returnTarget = null;
    this.returnNote = '';
  }
  typeLabel(type: string): string {
    return ({ daily: 'نشرة يومية', hourly: 'نشرة ساعية', phenomenon: 'ظاهرة جوية' } as Record<string, string>)[type] ?? type;
  }

  dateLabel(value: string | null): string {
    if (!value) return '—';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 401) return 'انتهت جلسة الدخول أو لم يتم تسجيل الدخول. أعد تسجيل الدخول.';
      if (error.status === 403) return 'ليس لديك صلاحية الوصول إلى مراجعة هذه المحطة أو اتخاذ هذا القرار.';
      if (error.status === 404) return 'النشرة أو المحطة غير موجودة.';
      if (error.status === 409) return 'تعذر التنفيذ بسبب تعارض في حالة النشرة (قد تكون أُعيد تقديمها أو اعتُمدت). حدّث القائمة.';
      if (error.status === 0) return 'تعذر الاتصال بالخادم. تحقق من عنوان API وإعدادات CORS.';
      if (error.status >= 500) return 'الخدمة غير متاحة حالياً. تحقق من إعدادات الخادم وقاعدة البيانات.';
      return `رفض الخادم الطلب (HTTP ${error.status}).`;
    }
    return error instanceof Error ? error.message : 'حدث خطأ غير متوقع أثناء تنفيذ الطلب.';
  }
}
