import { CommonModule } from '@angular/common';
import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Component, OnInit, inject } from '@angular/core';
import { firstValueFrom, timeout } from 'rxjs';
import { METRA_API_BASE_URL } from '../../core/identity/current-user-context.service';

interface HourlyReviewQueueItem {
  observationId: string;
  stationId: string;
  observationDate: string;
  utcHour: number;
  submittedBy: string;
  submittedAtUtc: string;
}

interface HourlyReviewQueuePage {
  items: HourlyReviewQueueItem[];
  hasMore: boolean;
  nextCursor: string | null;
}

type ReviewDecision = 1 | 2;

@Component({
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="workflow-page" dir="rtl">
      <header class="page-heading">
        <div>
          <div class="eyebrow"><i class="fa-solid fa-list-check"></i> إدارة ومتابعة السجلات</div>
          <h1>مراجعة النشرات الساعية</h1>
          <p>قائمة حقيقية من الخادم للنشرات المعلقة ضمن المحطات المسندة إلى حساب المراجع.</p>
        </div>
        <button class="refresh-btn" type="button" (click)="refreshQueue()" [disabled]="isLoading">
          <i class="fa-solid" [ngClass]="isLoading ? 'fa-spinner fa-spin' : 'fa-rotate'"></i>
          تحديث القائمة
        </button>
      </header>

      <div class="notice" role="note">
        <i class="fa-solid fa-shield-halved"></i>
        <div>
          <strong>الوصول محكوم بصلاحيات الخادم.</strong>
          <span>لا يرسل المتصفح معرف المستخدم أو المحطة المصرح بها. الخادم يستخرج الهوية والتكليفات ويتحقق منها عند كل قراءة واعتماد.</span>
        </div>
      </div>

      <section class="summary-grid" aria-label="ملخص قائمة المراجعة">
        <article class="summary-card">
          <span>النشرات المعروضة</span><strong>{{ items.length }}</strong>
          <i class="fa-solid fa-inbox"></i>
        </article>
        <article class="summary-card pending">
          <span>الحالة</span><strong>{{ isLoading ? 'جارٍ التحميل' : hasMore ? 'توجد صفحات أخرى' : 'نهاية القائمة' }}</strong>
          <i class="fa-solid fa-hourglass-half"></i>
        </article>
      </section>

      <section class="workflow-card">
        <div class="toolbar">
          <div><h2>النشرات بانتظار المراجعة</h2><p>تعرض هذه القائمة بيانات تعريفية فقط، ولا تعرض قيم الرصد الحساسة.</p></div>
          <span class="count-pill">{{ items.length }} نشرة</span>
        </div>

        <div class="state-panel loading" *ngIf="isLoading && items.length === 0" role="status">
          <i class="fa-solid fa-spinner fa-spin"></i><span>جارٍ جلب قائمة النشرات من الخادم...</span>
        </div>
        <div class="state-panel error" *ngIf="errorMessage" role="alert">
          <i class="fa-solid fa-triangle-exclamation"></i><span>{{ errorMessage }}</span>
        </div>
        <div class="state-panel success" *ngIf="message" role="status">
          <i class="fa-solid fa-circle-check"></i><span>{{ message }}</span>
        </div>

        <div class="table-wrap" *ngIf="items.length > 0">
          <table>
            <thead>
              <tr>
                <th>معرّف النشرة</th><th>معرّف المحطة</th><th>تاريخ الرصد</th>
                <th>ساعة UTC</th><th>معرّف الراصد</th><th>وقت الإرسال</th><th>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let item of items; trackBy: trackByObservationId">
                <td data-label="معرّف النشرة"><code>{{ item.observationId }}</code></td>
                <td data-label="معرّف المحطة"><code>{{ item.stationId }}</code></td>
                <td data-label="تاريخ الرصد">{{ item.observationDate }}</td>
                <td data-label="ساعة UTC">{{ item.utcHour.toString().padStart(2, '0') }}:00</td>
                <td data-label="معرّف الراصد"><code>{{ item.submittedBy }}</code></td>
                <td data-label="وقت الإرسال">{{ item.submittedAtUtc | date:'yyyy-MM-dd HH:mm:ss':'UTC' }} UTC</td>
                <td data-label="الإجراء">
                  <div class="row-actions">
                    <button class="approve" type="button" (click)="decide(item, 1)" [disabled]="workingId === item.observationId || isLoading">
                      <i class="fa-solid fa-check"></i> اعتماد
                    </button>
                    <button class="reject" type="button" (click)="prepareReject(item)" [disabled]="workingId === item.observationId || isLoading">
                      <i class="fa-solid fa-rotate-left"></i> رفض
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="empty-state" *ngIf="!isLoading && !errorMessage && items.length === 0">
          <i class="fa-regular fa-folder-open"></i>
          <strong>لا توجد نشرات بانتظار المراجعة</strong>
          <span>ستظهر هنا النشرات المرسلة إلى المحطات المسندة إليك بعد تفعيل خدمة الحفظ على الخادم.</span>
        </div>

        <div class="load-more" *ngIf="hasMore">
          <button type="button" (click)="loadMore()" [disabled]="isLoading">
            {{ isLoading ? 'جارٍ التحميل...' : 'تحميل المزيد' }}
          </button>
        </div>
      </section>

      <section class="workflow-card reject-panel" *ngIf="rejectTarget as target">
        <div class="toolbar">
          <div><h2>رفض النشرة</h2><p>النشرة: {{ target.observationId }}</p></div>
          <button class="close-btn" type="button" (click)="cancelReject()" aria-label="إلغاء">×</button>
        </div>
        <label class="note-field">سبب الرفض (إلزامي)
          <textarea rows="3" maxlength="1000" [(ngModel)]="rejectNote" placeholder="اكتب سبب الرفض ليظهر ضمن سجل المراجعة..."></textarea>
        </label>
        <div class="row-actions">
          <button class="reject" type="button" (click)="confirmReject()" [disabled]="!rejectNote.trim() || workingId === target.observationId">تأكيد الرفض</button>
          <button class="cancel" type="button" (click)="cancelReject()">إلغاء</button>
        </div>
      </section>
    </div>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#2c3e50}
    .workflow-page{max-width:1500px;margin:0 auto}.page-heading{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:22px}
    .eyebrow{color:#2980b9;font-weight:700;font-size:13px}.eyebrow i{margin-left:7px}h1{font-size:clamp(24px,3vw,32px);margin:7px 0;font-weight:800}h2{font-size:19px;margin:0 0 5px}p{margin:0;color:#7b8790;font-size:13px}
    .refresh-btn,.load-more button{border:0;border-radius:9px;background:#287fb5;color:white;padding:11px 16px;font:inherit;font-weight:700;cursor:pointer}.refresh-btn:disabled,.row-actions button:disabled,.load-more button:disabled{opacity:.55;cursor:wait}
    .notice{display:flex;gap:12px;align-items:flex-start;background:#eaf4fb;border:1px solid #c9e2f3;border-right:4px solid #3498db;border-radius:10px;padding:14px 16px;margin-bottom:20px;color:#245575}.notice>i{font-size:20px;margin-top:2px}.notice div{display:grid;gap:4px}.notice span{font-size:12px}
    .summary-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:15px;margin-bottom:20px}.summary-card{background:white;border-radius:12px;padding:18px;box-shadow:0 5px 18px #2233440c;position:relative;display:grid;gap:8px;border-bottom:3px solid #3498db}.summary-card span{font-size:13px;color:#71808b}.summary-card strong{font-size:20px}.summary-card>i{position:absolute;left:18px;top:20px;color:#3498db;font-size:22px;opacity:.7}.summary-card.pending{border-color:#e6a23c}.summary-card.pending>i{color:#e6a23c}
    .workflow-card{background:#fff;border-radius:13px;padding:22px;margin-bottom:20px;box-shadow:0 5px 18px #2233440c}.toolbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}.count-pill{border-radius:20px;background:#eaf4fb;color:#2876a8;padding:7px 12px;font-size:12px;font-weight:700;white-space:nowrap}
    .state-panel{display:flex;gap:10px;align-items:center;padding:13px 15px;border-radius:9px;margin:12px 0;font-size:13px}.loading{background:#eef6fc;color:#2876a8}.error{background:#fff0ef;color:#a52c2c}.success{background:#eaf7ef;color:#218348}
    .table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;white-space:nowrap}th{text-align:right;background:#f5f7f9;color:#697781;font-size:12px;font-weight:700;padding:13px 12px}td{padding:13px 12px;border-bottom:1px solid #edf0f2;font-size:12px}tbody tr:hover{background:#f7fbfe}code{font-family:ui-monospace,Consolas,monospace;font-size:11px;color:#526575}
    .row-actions{display:flex;gap:7px;flex-wrap:wrap}.row-actions button{border:0;border-radius:7px;padding:8px 11px;color:white;cursor:pointer;font:inherit;font-size:12px;font-weight:700}.row-actions i{margin-left:5px}.approve{background:#24965a}.reject{background:#d65a50}.cancel{background:#edf0f2;color:#52616c!important}
    .empty-state{display:grid;justify-items:center;gap:9px;padding:45px 15px;text-align:center;color:#73818b}.empty-state>i{font-size:32px;color:#9aabb6}.empty-state strong{color:#52616c}.empty-state span{font-size:12px;max-width:560px;line-height:1.8}
    .load-more{display:flex;justify-content:center;margin-top:18px}.reject-panel{border-top:3px solid #d65a50}.close-btn{border:0;background:transparent;font-size:25px;cursor:pointer;color:#74818a}.note-field{display:grid;gap:8px;font-size:13px;font-weight:700}.note-field textarea{width:100%;box-sizing:border-box;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;font:inherit;resize:vertical}.reject-panel .row-actions{margin-top:14px}
    @media(max-width:1000px){table,thead,tbody,tr,td{display:block}thead{display:none}tbody tr{border:1px solid #e8edf0;border-radius:9px;margin-bottom:12px;padding:8px}td{display:flex;justify-content:space-between;gap:10px;padding:8px 5px;white-space:normal;border-bottom:1px solid #f0f2f4}td:before{content:attr(data-label);font-weight:700;color:#77838c;min-width:115px}.row-actions{justify-content:flex-start}}
    @media(max-width:650px){.page-heading{align-items:flex-start;flex-direction:column}.summary-grid{gap:9px}.summary-card{padding:14px}.summary-card>i{left:12px;top:16px}.workflow-card{padding:15px}.toolbar{align-items:flex-start;flex-direction:column}.refresh-btn{width:100%}}
  `]
})
export class ObservationWorkflowComponent implements OnInit {
  private readonly http = inject(HttpClient);
  private readonly apiBaseUrl = inject(METRA_API_BASE_URL);
  readonly pageSize = 50;

  items: HourlyReviewQueueItem[] = [];
  nextCursor: string | null = null;
  hasMore = false;
  isLoading = false;
  workingId: string | null = null;
  errorMessage = '';
  message = '';
  rejectTarget: HourlyReviewQueueItem | null = null;
  rejectNote = '';

  ngOnInit(): void {
    void this.refreshQueue();
  }

  trackByObservationId(_index: number, item: HourlyReviewQueueItem): string {
    return item.observationId;
  }

  async refreshQueue(): Promise<void> {
    this.items = [];
    this.nextCursor = null;
    this.hasMore = false;
    await this.fetchPage(null, false);
  }

  async loadMore(): Promise<void> {
    if (!this.nextCursor || this.isLoading) return;
    await this.fetchPage(this.nextCursor, true);
  }

  prepareReject(item: HourlyReviewQueueItem): void {
    this.rejectTarget = item;
    this.rejectNote = '';
    this.message = '';
  }

  cancelReject(): void {
    this.rejectTarget = null;
    this.rejectNote = '';
  }

  async confirmReject(): Promise<void> {
    const target = this.rejectTarget;
    const note = this.rejectNote.trim();
    if (!target || !note) return;
    await this.decide(target, 2, note);
    if (!this.errorMessage) this.cancelReject();
  }

  async decide(item: HourlyReviewQueueItem, decision: ReviewDecision, note: string | null = null): Promise<void> {
    this.workingId = item.observationId;
    this.errorMessage = '';
    this.message = '';
    try {
      const base = this.normalizedBaseUrl();
      await firstValueFrom(
        this.http.post(
          `${base}/observations/hourly/${encodeURIComponent(item.observationId)}/review`,
          { decision, note },
          { withCredentials: true }
        ).pipe(timeout({ first: 15000 }))
      );
      this.items = this.items.filter(row => row.observationId !== item.observationId);
      this.message = decision === 1 ? 'تم اعتماد النشرة وتسجيل قرار المراجعة.' : 'تم رفض النشرة وتسجيل سبب الرفض.';
    } catch (error: unknown) {
      this.errorMessage = this.describeError(error);
    } finally {
      this.workingId = null;
    }
  }

  private async fetchPage(cursor: string | null, append: boolean): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    this.message = '';
    try {
      let params = new HttpParams().set('pageSize', this.pageSize.toString());
      if (cursor) params = params.set('cursor', cursor);
      const page = await firstValueFrom(
        this.http.get<HourlyReviewQueuePage>(
          `${this.normalizedBaseUrl()}/observations/hourly/review-queue`,
          { params, withCredentials: true }
        ).pipe(timeout({ first: 15000 }))
      );
      if (!page || !Array.isArray(page.items) || typeof page.hasMore !== 'boolean' ||
          (page.hasMore && (typeof page.nextCursor !== 'string' || !page.nextCursor))) {
        throw new Error('invalid_queue_response');
      }
      const incoming = page.items.filter(item =>
        !!item && typeof item.observationId === 'string' &&
        typeof item.stationId === 'string' && typeof item.submittedBy === 'string' &&
        Number.isInteger(item.utcHour) && item.utcHour >= 0 && item.utcHour <= 23);
      this.items = append ? [...this.items, ...incoming] : incoming;
      this.hasMore = page.hasMore;
      this.nextCursor = page.nextCursor;
    } catch (error: unknown) {
      this.errorMessage = this.describeError(error);
    } finally {
      this.isLoading = false;
    }
  }

  private normalizedBaseUrl(): string {
    const base = this.apiBaseUrl.endsWith('/') ? this.apiBaseUrl.slice(0, -1) : this.apiBaseUrl;
    return base.endsWith('/api/v1') ? base : `${base}/api/v1`;
  }

  private describeError(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 401) return 'يلزم تسجيل الدخول قبل عرض قائمة المراجعة. إعداد المصادقة غير مفعّل في نسخة المعاينة الحالية.';
      if (error.status === 403) return 'لا يملك الحساب الحالي صلاحية مراجعة النشرات أو لا توجد له محطة مسندة.';
      if (error.status === 404 || error.status === 503) return 'خدمة حفظ ومراجعة النشرات غير مفعّلة على الخادم حالياً؛ لم يتم استخدام بيانات تجريبية بديلة.';
      if (error.status === 0) return 'تعذر الاتصال بالخادم. تحقق من تشغيل API وإعداد عنوان الخدمة.';
      return `تعذر تنفيذ الطلب (HTTP ${error.status}). حاول التحديث أو راجع سجل الخادم.`;
    }
    if (error instanceof Error && error.message === 'invalid_queue_response') {
      return 'أعاد الخادم استجابة غير مطابقة لعقد قائمة المراجعة.';
    }
    return 'حدث خطأ غير متوقع أثناء الاتصال بخدمة المراجعة.';
  }
}
