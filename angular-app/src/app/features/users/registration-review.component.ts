import { Component, OnInit, inject } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';
import { StationAssignmentApiService, AssignableStationRole } from '../../core/api/station-assignment-api.service';
import { StationUserDirectoryApiService, StationUserItem } from '../../core/api/station-user-directory-api.service';
import {
  RegistrationAuditItem,
  RegistrationDecision,
  RegistrationRequestItem,
  RegistrationReviewApiService,
  RegistrationReviewStage
} from '../../core/api/registration-review-api.service';

@Component({
  selector: 'metra-registration-review',
  standalone: true,
  imports: [FormsModule],
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
            <button type="button" [class.active]="stage === 'station' && viewMode === 'queue'" [attr.aria-pressed]="stage === 'station' && viewMode === 'queue'" (click)="setStage('station')">اعتماد المحطة</button>
            <button type="button" [class.active]="stage === 'system' && viewMode === 'queue'" [attr.aria-pressed]="stage === 'system' && viewMode === 'queue'" (click)="setStage('system')">الاعتماد النظامي</button>
            <button type="button" [class.active]="viewMode === 'audit'" [attr.aria-pressed]="viewMode === 'audit'" (click)="setView('audit')">سجل التدقيق</button>
            <button type="button" [class.active]="viewMode === 'users'" [attr.aria-pressed]="viewMode === 'users'" (click)="setView('users')">المستخدمون المسندون</button>
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


        } @else if (viewMode === 'users') {
          @if (canManageAssignments) {
            <form class="assignment-form" (ngSubmit)="requestAssignment()">
              <div class="assignment-form-title">
                <strong>طلب تكليف مستخدم بالمحطة</strong>
                <span>يقتصر هذا المسار على المراقب ومدقق المحطة، ويحتاج اعتماد مراجع آخر.</span>
              </div>
              <div class="assignment-fields">
                <label>معرّف المستخدم
                  <input name="targetUserId" [(ngModel)]="targetUserId" placeholder="UUID لمستخدم METRA" required maxlength="36" dir="ltr">
                </label>
                <label>الدور
                  <select name="assignmentRole" [(ngModel)]="assignmentRole" required>
                    <option value="">اختر الدور</option>
                    @for (role of assignableRoles; track role.role_code) {
                      <option [value]="role.role_code">{{ role.name_ar || role.role_code }}</option>
                    }
                  </select>
                </label>
                <label>بداية التكليف
                  <input name="assignmentValidFrom" type="datetime-local" [(ngModel)]="assignmentValidFrom" required>
                </label>
                <label>نهاية التكليف (اختياري)
                  <input name="assignmentValidTo" type="datetime-local" [(ngModel)]="assignmentValidTo">
                </label>
                <label class="reason-field">مبرر التكليف
                  <textarea name="assignmentReason" [(ngModel)]="assignmentReason" rows="2" maxlength="2000" required></textarea>
                </label>
              </div>
              <button class="approve" type="submit" [disabled]="assignmentBusy || !targetUserId.trim() || !assignmentRole || !assignmentReason.trim() || !assignmentValidFrom">
                {{ assignmentBusy ? 'جارٍ إنشاء الطلب…' : 'إرسال طلب التكليف للمراجعة' }}
              </button>
            </form>
          }
          @if (stationUsers.length === 0) {
            <div class="empty">لا توجد تكليفات مسجلة لهذه المحطة.</div>
          } @else {
            <div class="queue-meta">{{ stationUsers.length }} مستخدم/تكليف — حالة الحساب والتكليف الفعلية</div>
            <div class="user-directory-wrap">
              <table class="user-directory">
                <thead><tr><th>المستخدم</th><th>الدور</th><th>حالة الحساب</th><th>حالة التكليف</th><th>سريان التكليف</th><th>الإجراء</th></tr></thead>
                <tbody>
                  @for (user of stationUsers; track user.assignment_id) {
                    <tr>
                      <td><strong>{{ stationUserName(user) }}</strong><small>{{ user.phone || 'لا يوجد هاتف' }}</small><small class="user-id">{{ user.user_id }}</small></td>
                      <td>{{ user.role_name_ar || user.assignment_role_code }}</td>
                      <td><span class="state-tag">{{ accountStateLabel(user.account_state) }}</span></td>
                      <td>{{ assignmentStateLabel(user.assignment_status) }}</td>
                      <td>{{ formatDate(user.valid_from) }}<small>{{ user.valid_to ? 'حتى ' + formatDate(user.valid_to) : 'دون تاريخ انتهاء' }}</small></td>
                      <td>
                        @if (canManageAssignments && user.assignment_status === 'pending') {
                          <textarea #assignmentNote rows="2" maxlength="2000" placeholder="ملاحظة الرفض (مطلوبة عند الرفض)"></textarea>
                          <div class="actions">
                            <button type="button" class="approve" [disabled]="assignmentBusy" (click)="decideAssignment(user, 'approve', assignmentNote.value)">اعتماد</button>
                            <button type="button" class="reject" [disabled]="assignmentBusy" (click)="decideAssignment(user, 'reject', assignmentNote.value)">رفض</button>
                          </div>
                        } @else { <small>—</small> }
                      </td>
                    </tr>
                  }
                </tbody>
              </table>
            </div>
          }
        } @else if (viewMode === 'audit') {
          @if (auditEvents.length === 0) {
            <div class="empty">لا توجد أحداث تدقيق مسجلة لهذه المحطة.</div>
          } @else {
            <div class="audit-list">
              @for (event of auditEvents; track event.id) {
                <article class="audit-item">
                  <div class="audit-top">
                    <strong>{{ eventLabel(event.event_type) }}</strong>
                    <time>{{ formatDate(event.occurred_at) }}</time>
                  </div>
                  <p>{{ event.decision_note || 'لم تُسجل ملاحظة للقرار.' }}</p>
                  <small>رقم الطلب: {{ event.request_id }} · المنفذ: {{ shortId(event.actor_user_id) }} · إصدار الشروط: {{ event.terms_version }}</small>
                </article>
              }
            </div>
          }
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
                    <span>معرّف المستخدم: {{ item.user_id }}</span>
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
                    <button type="button" class="reject" [disabled]="busyRequestId !== null" (click)="decide(item, 'reject', note.value)">رفض</button>
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
    .empty{padding:28px 14px;text-align:center;background:#f8fafb;border:1px dashed #d8e2e8;border-radius:10px;color:#7b8992;font-size:13px}.queue-meta{font-size:11px;color:#84919a;margin:8px 0}.assignment-form{border:1px solid #dce8ee;background:#f8fbfd;border-radius:10px;padding:14px;margin-bottom:15px;display:grid;gap:12px}.assignment-form-title{display:grid;gap:4px}.assignment-form-title strong{font-size:13px;color:#31566d}.assignment-form-title span{font-size:10px;color:#83919a}.assignment-fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.assignment-fields label{display:grid;gap:5px;font-size:11px;color:#647682}.assignment-fields input,.assignment-fields select,.assignment-fields textarea{box-sizing:border-box;width:100%;border:1px solid #dce5ea;border-radius:7px;padding:8px;font:inherit;background:#fff;color:#304b5b}.assignment-fields .reason-field{grid-column:1/-1}.user-id{direction:ltr;text-align:right;user-select:all}.user-directory-wrap{overflow:auto;border:1px solid #e6edf1;border-radius:9px}.user-directory{width:100%;border-collapse:collapse;min-width:680px}.user-directory th{text-align:right;background:#f5f8fa;color:#70808b;font-size:11px;padding:11px}.user-directory td{padding:11px;border-top:1px solid #edf1f3;font-size:11px;vertical-align:top}.user-directory small{display:block;color:#87939b;font-size:10px;margin-top:4px;overflow-wrap:anywhere}.state-tag{display:inline-block;border-radius:20px;background:#eef4f7;padding:4px 8px;font-size:10px}.audit-list{display:grid;gap:9px}.audit-item{border:1px solid #e6edf1;border-right:3px solid #6b9fbd;border-radius:9px;padding:12px 14px}.audit-top{display:flex;justify-content:space-between;gap:12px;align-items:center}.audit-top strong{font-size:12px;color:#31566d}.audit-top time{font-size:10px;color:#87939b}.audit-item p{font-size:12px;color:#536774;margin:8px 0}.audit-item small{font-size:10px;color:#87939b;overflow-wrap:anywhere}.request-list{display:grid;gap:12px}.request-card{border:1px solid #e6edf1;border-radius:10px;padding:15px;display:grid;grid-template-columns:minmax(0,1fr) minmax(250px,.8fr);gap:18px}.person{display:grid;gap:5px}.person strong{font-size:14px}.person span{font-size:12px;color:#287caf}.details{display:flex;flex-wrap:wrap;gap:7px 16px;margin-top:12px}.details span{font-size:11px;color:#71808b}.decision{display:grid;gap:9px}.decision textarea{width:100%;box-sizing:border-box;resize:vertical;border:1px solid #dce5ea;border-radius:8px;padding:9px;color:#304b5b;font-size:12px}.actions{display:flex;gap:8px;justify-content:flex-start}.actions button{border:0;border-radius:7px;padding:8px 15px;font-size:12px;font-weight:800;cursor:pointer}.approve{background:#e7f5ec;color:#26754a}.reject{background:#fff0ef;color:#a33d35}.security-note{margin:14px 0 0;color:#85929a;font-size:10px;line-height:1.8}
    @media(max-width:760px){.assignment-fields{grid-template-columns:1fr}.assignment-fields .reason-field{grid-column:auto}.review-panel{padding:14px}.review-heading{flex-direction:column}.filters{align-items:stretch}.filters select{min-width:0;width:100%}.stage-switch button{flex:1}.request-card{grid-template-columns:1fr}.actions button{flex:1}}
  `]
})
export class RegistrationReviewComponent implements OnInit {
  readonly api = inject(RegistrationReviewApiService);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly userDirectoryApi = inject(StationUserDirectoryApiService);
  private readonly assignmentApi = inject(StationAssignmentApiService);

  stations: StationDirectoryItem[] = [];
  requests: RegistrationRequestItem[] = [];
  auditEvents: RegistrationAuditItem[] = [];
  stationUsers: StationUserItem[] = [];
  assignableRoles: AssignableStationRole[] = [];
  canManageAssignments = false;
  targetUserId = '';
  assignmentRole: 'observer' | 'station_auditor' | '' = '';
  assignmentReason = '';
  assignmentValidFrom = '';
  assignmentValidTo = '';
  assignmentBusy = false;
  viewMode: 'queue' | 'audit' | 'users' = 'queue';
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
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
    this.assignmentValidFrom = now.toISOString().slice(0, 16);
    if (!this.api.isConfigured) return;
    this.loadingStations = true;
    try {
      this.stations = (await this.stationsApi.getAllStations()).filter(station =>
        station.approval_status === 'approved' &&
        station.operational_status === 'active' &&
        !station.is_demo
      );
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
    if (this.stage === stage && this.viewMode === 'queue') return;
    this.stage = stage;
    this.viewMode = 'queue';
    this.notice = '';
    await this.loadQueue();
  }

  async setView(view: 'audit' | 'users'): Promise<void> {
    this.viewMode = view;
    this.notice = '';
    await this.loadQueue();
  }

  async loadQueue(): Promise<void> {
    if (!this.selectedStationId || !this.api.isConfigured) {
      this.requests = [];
      this.auditEvents = [];
      this.stationUsers = [];
      return;
    }
    this.loadingQueue = true;
    this.error = '';
    try {
      if (this.viewMode === 'audit') {
        this.auditEvents = await this.api.getAudit(this.selectedStationId, this.stage);
        this.requests = [];
        this.stationUsers = [];
      } else if (this.viewMode === 'users') {
        this.stationUsers = await this.userDirectoryApi.getUsers(this.selectedStationId);
        this.requests = [];
        this.auditEvents = [];
        try {
          this.assignableRoles = await this.assignmentApi.getAssignableRoles(this.selectedStationId);
          this.canManageAssignments = this.assignableRoles.length > 0;
        } catch {
          this.assignableRoles = [];
          this.canManageAssignments = false;
        }
      } else {
        this.requests = await this.api.getQueue(this.selectedStationId, this.stage);
        this.auditEvents = [];
        this.stationUsers = [];
      }
    } catch (error) {
      this.requests = [];
      this.auditEvents = [];
      this.stationUsers = [];
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



  async requestAssignment(): Promise<void> {
    if (this.assignmentBusy || !this.selectedStationId || !this.targetUserId.trim() ||
        !this.assignmentRole || !this.assignmentReason.trim() || !this.assignmentValidFrom) return;
    this.assignmentBusy = true;
    this.error = '';
    this.notice = '';
    try {
      await this.assignmentApi.request(this.selectedStationId, {
        userId: this.targetUserId.trim(),
        roleCode: this.assignmentRole,
        reason: this.assignmentReason.trim(),
        validFrom: new Date(this.assignmentValidFrom).toISOString(),
        validTo: this.assignmentValidTo ? new Date(this.assignmentValidTo).toISOString() : null
      });
      this.notice = 'تم إنشاء طلب التكليف بحالة معلّقة. يجب أن يعتمد مراجع آخر الطلب قبل تفعيله.';
      this.targetUserId = '';
      this.assignmentRole = '';
      this.assignmentReason = '';
      this.assignmentValidTo = '';
      await this.loadQueue();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.assignmentBusy = false;
    }
  }

  async decideAssignment(user: StationUserItem, decision: 'approve' | 'reject', note: string): Promise<void> {
    if (this.assignmentBusy || !this.selectedStationId) return;
    this.assignmentBusy = true;
    this.error = '';
    this.notice = '';
    try {
      await this.assignmentApi.decide(this.selectedStationId, user.assignment_id, decision, note);
      this.notice = decision === 'approve' ? 'تم اعتماد التكليف.' : 'تم رفض التكليف.';
      await this.loadQueue();
    } catch (error) {
      this.error = this.errorMessage(error);
    } finally {
      this.assignmentBusy = false;
    }
  }

  stationUserName(user: StationUserItem): string {
    return [user.first_name, user.father_name, user.last_name].filter(Boolean).join(' ');
  }

  accountStateLabel(state: string | null): string {
    const labels: Record<string, string> = {
      active: 'فعال',
      pending_station_approval: 'بانتظار المحطة',
      pending_system_approval: 'بانتظار النظام',
      rejected: 'مرفوض',
      suspended: 'موقوف',
      disabled: 'معطل'
    };
    return state ? labels[state] ?? state : 'غير محدد';
  }

  assignmentStateLabel(state: string): string {
    const labels: Record<string, string> = {
      approved: 'معتمد',
      pending: 'معلق',
      rejected: 'مرفوض',
      revoked: 'ملغى'
    };
    return labels[state] ?? state;
  }

  eventLabel(eventType: string): string {
    const labels: Record<string, string> = {
      station_approved: 'اعتماد المحطة',
      station_rejected: 'رفض طلب التسجيل من المحطة',
      system_approved: 'الاعتماد النظامي النهائي',
      system_rejected: 'رفض الاعتماد النظامي'
    };
    return labels[eventType] ?? eventType;
  }

  shortId(value: string): string {
    return value ? value.slice(0, 8) : 'غير متاح';
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
      if (error.status === 403) return 'لا تملك صلاحية الوصول إلى مستخدمي هذه المحطة أو مراجعة طلباتها في هذه المرحلة.';
      if (error.status === 404) return 'طلب التسجيل غير موجود.';
      if (error.status === 409) return 'تغيرت حالة الطلب؛ حدّث القائمة قبل اتخاذ قرار جديد.';
      if (error.status === 503) return 'خدمة المراجعة أو اتصال قاعدة البيانات غير متاح حالياً.';
    }
    return error instanceof Error ? error.message : 'تعذر تنفيذ العملية.';
  }
}
