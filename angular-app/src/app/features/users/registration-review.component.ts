import { Component, OnInit, inject } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';
import {
  RegistrationDecision,
  RegistrationRequestItem,
  RegistrationReviewApiService,
  RegistrationReviewStage
} from '../../core/api/registration-review-api.service';

@Component({
  selector: 'metra-registration-review',
  standalone: true,
  template: `
    <section class="review-panel" dir="rtl" aria-labelledby="registration-review-title">
      <div class="review-heading">
        <div>
          <span class="eyebrow">مسار اعتماد الحسابات</span>
          <h2 id="registration-review-title">طلبات التسجيل والاعتماد</h2>
          <p>مراجعة مرحلية مرتبطة بالمحطة، مع فصل اعتماد المحطة عن الاعتماد النظامي النهائي.</p>
        </div>
        <button type="button" class="refresh" (click)="loadQueue()" [disabled]="loadingQueue || !selectedStationId">
          {{ loadingQueue ? 'جارٍ التحديث…' : 'تحديث القائمة' }}
        </button>
      </div>

      @if (!api.isConfigured) {
        <div class="notice warning">واجهة المراجعة غير متصلة بعد. يلزم ضبط عنوان API العام وإعدادات Supabase العامة في بيئة العرض.</div>
      } @else {
        <div class="filters">
          <label>
            <span>المحطة</span>
            <select [value]="selectedStationId" (change)="onStationChange($event)" [disabled]="loadingStations">
              <option value="">اختر المحطة لمراجعة طلباتها</option>
              @for (station of stations; track station.id) {
                <option [value]="station.id">{{ station.name_ar }} — {{ station.local_station_code || station.id }}</option>
              }
            </select>
          </label>
          <div class="stage-switch" role="group" aria-label="مرحلة الاعتماد">
            <button type="button" [class.active]="stage === 'station'" [attr.aria-pressed]="stage === 'station'" (click)="setStage('station')">اعتماد المحطة</button>
            <button type="button" [class.active]="stage === 'system'" [attr.aria-pressed]="stage === 'system'" (click)="setStage('system')">الاعتماد النظامي</button>
          </div>
        </div>

        @if (error) { <div class="notice error" role="alert">{{ error }}</div> }
        @if (notice) { <div class="notice success" role="status">{{ notice }}</div> }

        @if (loadingStations) {
          <div class="empty">جارٍ تحميل دليل المحطات…</div>
        } @else if (!selectedStationId) {
          <div class="empty">اختر محطة لعرض الطلبات التي تقع ضمن نطاق صلاحياتك.</div>
        } @else if (loadingQueue) {
          <div class="empty">جارٍ تحميل طلبات التسجيل…</div>
        } @else if (requests.length === 0) {
          <div class="empty">لا توجد طلبات معلّقة في هذه المرحلة لهذه المحطة.</div>
        } @else {
          <div class="queue-meta">{{ requests.length }} طلبات معروضة — الأقدم أولاً</div>
          <div class="request-list">
            @for (item of requests; track item.id) {
              <article class="request-card">
                <div class="request-main">
                  <div class="person">
                    <strong>{{ displayName(item) }}</strong>
                    <span>{{ item.metra_role_catalogue?.name_ar || item.requested_role_code }}</span>
                  </div>
                  <div class="details">
                    <span>الهاتف: {{ item.phone_snapshot || 'غير مسجل' }}</span>
                    <span>المحطة: {{ item.station_catalogue?.name_ar || selectedStationName }}</span>
                    <span>تاريخ الطلب: {{ formatDate(item.submitted_at) }}</span>
                    <span>إصدار الشروط: {{ item.terms_version }}</span>
                  </div>
                </div>
                <div class="decision">
                  <label>
                    <span>{{ stage === 'station' ? 'ملاحظة مراجعة المحطة' : 'ملاحظة الاعتماد النهائي' }}</span>
                    <textarea #note rows="2" maxlength="2000" placeholder="اكتب سبب القرار، وهو إلزامي عند الرفض"></textarea>
                  </label>
                  <div class="actions">
                    <button type="button" class="approve" [disabled]="busyRequestId === item.id" (click)="decide(item, 'approve', note.value)">
                      {{ busyRequestId === item.id ? 'جارٍ الحفظ…' : 'اعتماد' }}
                    </button>
                    <button type="button" class="reject" [disabled]="busyRequestId === item.id" (click)="decide(item, 'reject', note.value)">رفض</button>
                  </div>
                </div>
              </article>
            }
          </div>
        }
      }
      <p class="security-note">لا تمنح هذه الشاشة دوراً أو صلاحية مباشرة. الاعتماد النهائي ينشئ التكليف المعتمد عبر إجراء قاعدة البيانات فقط، ويُرفض اعتماد صاحب الطلب لنفسه.</p>
    </section>
  `,
  styles: [`
    :host{display:block;margin:22px 0;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .review-panel{background:#fff;border:1px solid #e6edf1;border-radius:14px;padding:22px;box-shadow:0 5px 18px #2233440b}
    .review-heading{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:18px}
    .eyebrow{font-size:12px;font-weight:800;color:#287caf}.review-heading h2{margin:5px 0;font-size:20px}.review-heading p{margin:0;color:#7b8992;font-size:12px;line-height:1.8}
    button,select,textarea{font:inherit}.refresh{border:1px solid #d5e1e8;background:#f8fbfd;color:#31576d;border-radius:8px;padding:9px 13px;font-size:12px;font-weight:700;cursor:pointer}.refresh:disabled,button:disabled{opacity:.55;cursor:not-allowed}
    .filters{display:flex;align-items:flex-end;justify-content:space-between;gap:14px;flex-wrap:wrap;margin-bottom:16px}.filters label,.decision label{display:grid;gap:6px;min-width:min(100%,300px);font-size:12px;color:#647682;font-weight:700}.filters select{min-width:300px;max-width:100%;padding:10px;border:1px solid #dce5ea;border-radius:8px;background:#fff;color:#304b5b}
    .stage-switch{display:flex;gap:5px;background:#f0f4f6;padding:4px;border-radius:9px}.stage-switch button{border:0;background:transparent;color:#687985;padding:8px 12px;border-radius:7px;font-size:12px;cursor:pointer}.stage-switch button.active{background:#fff;color:#176b9c;box-shadow:0 1px 5px #22334418;font-weight:800}
    .notice{padding:11px 13px;border-radius:8px;font-size:12px;margin:12px 0}.warning{background:#fff8e9;color:#795a20}.error{background:#fff0ef;color:#a33d35}.success{background:#eaf7ef;color:#247247}
    .empty{padding:28px 14px;text-align:center;background:#f8fafb;border:1px dashed #d8e2e8;border-radius:10px;color:#7b8992;font-size:13px}.queue-meta{font-size:11px;color:#84919a;margin:8px 0}.request-list{display:grid;gap:12px}.request-card{border:1px solid #e6edf1;border-radius:10px;padding:15px;display:grid;grid-template-columns:minmax(0,1fr) minmax(250px,.8fr);gap:18px}.person{display:grid;gap:5px}.person strong{font-size:14px}.person span{font-size:12px;color:#287caf}.details{display:flex;flex-wrap:wrap;gap:7px 16px;margin-top:12px}.details span{font-size:11px;color:#71808b}.decision{display:grid;gap:9px}.decision textarea{width:100%;box-sizing:border-box;resize:vertical;border:1px solid #dce5ea;border-radius:8px;padding:9px;color:#304b5b;font-size:12px}.actions{display:flex;gap:8px;justify-content:flex-start}.actions button{border:0;border-radius:7px;padding:8px 15px;font-size:12px;font-weight:800;cursor:pointer}.approve{background:#e7f5ec;color:#26754a}.reject{background:#fff0ef;color:#a33d35}.security-note{margin:14px 0 0;color:#85929a;font-size:10px;line-height:1.8}
    @media(max-width:760px){.review-panel{padding:14px}.review-heading{flex-direction:column}.filters{align-items:stretch}.filters select{min-width:0;width:100%}.stage-switch button{flex:1}.request-card{grid-template-columns:1fr}.actions button{flex:1}}
  `]
})
export class RegistrationReviewComponent implements OnInit {
  readonly api = inject(RegistrationReviewApiService);
  private readonly stationsApi = inject(ObservationApiService);

  stations: StationDirectoryItem[] = [];
  requests: RegistrationRequestItem[] = [];
  selectedStationId = '';
  stage: RegistrationReviewStage = 'station';
  loadingStations = false;
  loadingQueue = false;
  busyRequestId: string | null = null;
  error = '';
  notice = '';

  get selectedStationName(): string {
    return this.stations.find(station => station.id === this.selectedStationId)?.name_ar ?? 'المحطة المحددة';
  }

  async ngOnInit(): Promise<void> {
    if (!this.api.isConfigured) return;
    this.loadingStations = true;
    try {
      this.stations = await this.stationsApi.getAllStations();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.loadingStations = false;
    }
  }

  async onStationChange(event: Event): Promise<void> {
    this.selectedStationId = (event.target as HTMLSelectElement).value;
    this.notice = '';
    await this.loadQueue();
  }

  async setStage(stage: RegistrationReviewStage): Promise<void> {
    if (this.stage === stage) return;
    this.stage = stage;
    this.notice = '';
    await this.loadQueue();
  }

  async loadQueue(): Promise<void> {
    if (!this.selectedStationId || !this.api.isConfigured) {
      this.requests = [];
      return;
    }
    this.loadingQueue = true;
    this.error = '';
    try {
      this.requests = await this.api.getQueue(this.selectedStationId, this.stage);
    } catch (error) {
      this.requests = [];
      this.error = this.errorMessage(error);
    } finally {
      this.loadingQueue = false;
    }
  }

  async decide(item: RegistrationRequestItem, decision: RegistrationDecision, note: string): Promise<void> {
    if (this.busyRequestId) return;
    this.busyRequestId = item.id;
    this.error = '';
    this.notice = '';
    try {
      await this.api.decide(this.selectedStationId, item.id, this.stage, decision, note);
      this.notice = decision === 'approve' ? 'تم تسجيل قرار الاعتماد بنجاح.' : 'تم تسجيل قرار الرفض بنجاح.';
      await this.loadQueue();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.busyRequestId = null;
    }
  }

  displayName(item: RegistrationRequestItem): string {
    const profile = item.metra_user_profiles;
    return [profile?.first_name, profile?.father_name, profile?.last_name].filter(Boolean).join(' ') || 'مستخدم جديد';
  }

  formatDate(value: string): string {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'غير متاح' : new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      if (error.status === 401) return 'انتهت جلسة الدخول أو لم يتم تسجيل الدخول.';
      if (error.status === 403) return 'لا تملك صلاحية مراجعة هذه المحطة أو هذه المرحلة.';
      if (error.status === 404) return 'طلب التسجيل غير موجود.';
      if (error.status === 409) return 'تغيرت حالة الطلب؛ حدّث القائمة قبل اتخاذ قرار جديد.';
      if (error.status === 503) return 'خدمة المراجعة أو اتصال قاعدة البيانات غير متاح حالياً.';
    }
    return error instanceof Error ? error.message : 'تعذر تنفيذ العملية.';
  }
}
