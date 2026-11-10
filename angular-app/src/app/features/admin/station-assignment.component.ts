import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import {
  AssignableStationRole,
  StationAssignmentApiService
} from '../../core/api/station-assignment-api.service';
import {
  StationUserDirectoryApiService,
  StationUserItem
} from '../../core/api/station-user-directory-api.service';
import { StationContextService } from '../../core/station/station-context.service';

@Component({
  standalone: true,
  selector: 'metra-station-assignment',
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <h1>تعيين المستخدمين للمحطة</h1>
          <p>الطلبات والقرارات والإلغاء تُنفَّذ عبر API ضمن نطاق المحطة. لا صلاحيات تُمنح من الواجهة وحدها.</p>
        </div>
        <div class="header-actions">
          <a *ngIf="stationId" class="link" [routerLink]="['/stations', stationId]">تفاصيل المحطة</a>
          <button type="button" class="primary" [disabled]="loading" (click)="reload()">تحديث</button>
        </div>
      </header>

      <div class="toolbar">
        <label>
          المحطة
          <select [(ngModel)]="stationId" (ngModelChange)="onStationChange($event)">
            <option value="">— اختر محطة —</option>
            <option *ngFor="let s of stations" [value]="s.id">
              {{ s.name_ar }} ({{ s.local_station_code || s.id }})
            </option>
          </select>
        </label>
      </div>

      <div class="tabs" *ngIf="stationId">
        <button type="button" [class.active]="tab==='active'" (click)="tab='active'">التعيينات النشطة ({{ activeUsers.length }})</button>
        <button type="button" [class.active]="tab==='pending'" (click)="tab='pending'">بانتظار القرار ({{ pendingUsers.length }})</button>
        <button type="button" [class.active]="tab==='request'" (click)="tab='request'">طلب جديد</button>
      </div>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner ok" *ngIf="feedback">{{ feedback }}</div>
      <div class="banner info" *ngIf="loading">جاري التحميل...</div>
      <div class="banner info" *ngIf="!loading && !stationId">اختر محطة مصرّحاً بها قبل إدارة التعيينات.</div>

      <ng-container *ngIf="stationId && !loading">
        <section class="card" *ngIf="tab==='active'">
          <h2>التعيينات النشطة / المعتمدة</h2>
          <div class="banner info" *ngIf="activeUsers.length===0">لا توجد تعيينات نشطة معروضة.</div>
          <div class="table-wrap" *ngIf="activeUsers.length">
            <table>
              <thead>
                <tr>
                  <th>الاسم</th>
                  <th>الدور</th>
                  <th>الحالة</th>
                  <th>من / إلى (UTC)</th>
                  <th>إجراء</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let u of activeUsers">
                  <td>
                    <strong>{{ fullName(u) }}</strong>
                    <small>{{ u.user_id }}</small>
                  </td>
                  <td>{{ u.role_name_ar || u.assignment_role_code }}</td>
                  <td>{{ u.assignment_status }}</td>
                  <td class="ltr">{{ u.valid_from }} → {{ u.valid_to || 'مفتوح' }}</td>
                  <td>
                    <button type="button" class="warn" [disabled]="busyId===u.assignment_id" (click)="revoke(u)">إلغاء</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="card" *ngIf="tab==='pending'">
          <h2>طلبات بانتظار الاعتماد أو الرفض</h2>
          <div class="banner info" *ngIf="pendingUsers.length===0">لا توجد طلبات معلّقة في دليل المحطة.</div>
          <div class="table-wrap" *ngIf="pendingUsers.length">
            <table>
              <thead>
                <tr>
                  <th>الاسم</th>
                  <th>الدور</th>
                  <th>الحالة</th>
                  <th>من (UTC)</th>
                  <th>قرار</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let u of pendingUsers">
                  <td>
                    <strong>{{ fullName(u) }}</strong>
                    <small>{{ u.user_id }}</small>
                  </td>
                  <td>{{ u.role_name_ar || u.assignment_role_code }}</td>
                  <td>{{ u.assignment_status }}</td>
                  <td class="ltr">{{ u.valid_from }}</td>
                  <td class="actions">
                    <button type="button" class="ok" [disabled]="busyId===u.assignment_id" (click)="decide(u,'approve')">اعتماد</button>
                    <button type="button" class="warn" [disabled]="busyId===u.assignment_id" (click)="decide(u,'reject')">رفض</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="card" *ngIf="tab==='request'">
          <h2>طلب تعيين جديد</h2>
          <label>
            معرّف المستخدم (UUID)
            <input [(ngModel)]="form.userId" placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" />
          </label>
          <label>
            الدور
            <select [(ngModel)]="form.roleCode">
              <option *ngFor="let r of roles" [value]="r.role_code">{{ r.name_ar }} ({{ r.role_code }})</option>
            </select>
          </label>
          <label>
            السبب
            <textarea rows="3" [(ngModel)]="form.reason" maxlength="1000"></textarea>
          </label>
          <label>
            صالح من (UTC ISO)
            <input [(ngModel)]="form.validFrom" />
          </label>
          <label>
            صالح إلى (اختياري، UTC ISO)
            <input [(ngModel)]="form.validTo" placeholder="فارغ = مفتوح" />
          </label>
          <button type="button" class="primary" [disabled]="submitting" (click)="submit()">إرسال طلب التعيين</button>
        </section>
      </ng-container>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1200px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px}
    .header-actions{display:flex;gap:10px;align-items:center}
    h1{margin:0 0 6px;font-size:1.4rem} h2{margin:0 0 12px;font-size:1.05rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .toolbar{margin-bottom:12px}
    .tabs{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px}
    .tabs button{border:1px solid #d5dee4;background:#fff;border-radius:999px;padding:8px 14px;cursor:pointer}
    .tabs button.active{background:#1f6f8b;color:#fff;border-color:#1f6f8b}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64;margin-bottom:10px}
    input,select,textarea{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .primary,.ok{background:#1f6f8b;color:#fff;border:0;border-radius:8px;padding:10px 14px;cursor:pointer}
    .warn{background:#c45c26;color:#fff;border:0;border-radius:8px;padding:8px 12px;cursor:pointer}
    .link{color:#1f6f8b;font-weight:700;text-decoration:none}
    .banner{padding:12px;border-radius:10px;margin-bottom:10px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.ok{background:#e8f6ee;color:#1f6b3c}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .card{border:1px solid #e4ebf0;border-radius:12px;padding:14px;background:#fff}
    .table-wrap{overflow:auto}
    table{width:100%;border-collapse:collapse;min-width:640px}
    th,td{padding:10px;border-bottom:1px solid #edf1f4;text-align:right;vertical-align:top;font-size:13px}
    th{background:#f5f8fa;color:#5b6a74}
    td small{display:block;color:#7a8791;direction:ltr}
    .ltr{direction:ltr;text-align:right}
    .actions{display:flex;gap:6px;flex-wrap:wrap}
  `]
})
export class StationAssignmentComponent implements OnInit {
  private readonly assignmentApi = inject(StationAssignmentApiService);
  private readonly usersApi = inject(StationUserDirectoryApiService);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);

  stations: StationDirectoryItem[] = [];
  stationId = '';
  users: StationUserItem[] = [];
  roles: AssignableStationRole[] = [];
  tab: 'active' | 'pending' | 'request' = 'pending';
  loading = false;
  submitting = false;
  error = '';
  feedback = '';
  busyId: string | null = null;

  form = {
    userId: '',
    roleCode: 'observer' as 'observer' | 'station_auditor',
    reason: '',
    validFrom: new Date().toISOString(),
    validTo: ''
  };

  get pendingUsers(): StationUserItem[] {
    return this.users.filter(u => this.isPendingStatus(u.assignment_status));
  }

  get activeUsers(): StationUserItem[] {
    return this.users.filter(u => !this.isPendingStatus(u.assignment_status));
  }

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    void this.loadStations().then(() => this.reload());
  }

  fullName(u: StationUserItem): string {
    return [u.first_name, u.father_name, u.last_name].filter(Boolean).join(' ');
  }

  isPendingStatus(status: string | null | undefined): boolean {
    const s = (status || '').toLowerCase();
    return s.includes('pending') || s.includes('requested') || s.includes('await') || s === 'submitted';
  }

  onStationChange(id: string): void {
    if (this.stationContext.isUuid(id)) this.stationContext.remember(id);
    void this.reload();
  }

  async loadStations(): Promise<void> {
    try {
      if (this.stationsApi.isConfigured) {
        this.stations = await this.stationsApi.getAllStations();
      }
    } catch {
      this.stations = [];
    }
  }

  async reload(): Promise<void> {
    this.error = '';
    this.feedback = '';
    this.users = [];
    this.roles = [];
    if (!this.stationId) return;
    this.loading = true;
    try {
      if (!this.assignmentApi.isConfigured || !this.usersApi.isConfigured) {
        throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة أولاً.');
      }
      const [users, roles] = await Promise.all([
        this.usersApi.getUsers(this.stationId),
        this.assignmentApi.getAssignableRoles(this.stationId)
      ]);
      this.users = users;
      this.roles = roles.length ? roles : [
        { role_code: 'observer', name_ar: 'راصد جوي', name_en: 'Observer' },
        { role_code: 'station_auditor', name_ar: 'مدقق محطة', name_en: 'Station auditor' }
      ];
      if (!this.roles.find(r => r.role_code === this.form.roleCode) && this.roles[0]) {
        this.form.roleCode = this.roles[0].role_code;
      }
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تحميل بيانات التعيين.';
    } finally {
      this.loading = false;
    }
  }

  async submit(): Promise<void> {
    this.error = '';
    this.feedback = '';
    if (!this.stationId) {
      this.error = 'اختر محطة أولاً.';
      return;
    }
    if (!this.form.userId.trim() || !this.form.reason.trim() || !this.form.validFrom.trim()) {
      this.error = 'معرّف المستخدم والسبب وتاريخ البداية مطلوبة.';
      return;
    }
    this.submitting = true;
    try {
      await this.assignmentApi.request(this.stationId, {
        userId: this.form.userId.trim(),
        roleCode: this.form.roleCode,
        reason: this.form.reason.trim(),
        validFrom: this.form.validFrom.trim(),
        validTo: this.form.validTo.trim() ? this.form.validTo.trim() : null
      });
      this.feedback = 'أُرسل طلب التعيين إلى الخادم.';
      this.form.userId = '';
      this.form.reason = '';
      this.tab = 'pending';
      await this.reload();
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر إرسال طلب التعيين.';
    } finally {
      this.submitting = false;
    }
  }

  async decide(user: StationUserItem, decision: 'approve' | 'reject'): Promise<void> {
    let note = '';
    if (decision === 'reject') {
      note = prompt('سبب رفض التعيين؟')?.trim() || '';
      if (!note) {
        this.error = 'سبب الرفض مطلوب.';
        return;
      }
    } else {
      note = prompt('ملاحظة الاعتماد (اختياري):')?.trim() || '';
    }
    this.busyId = user.assignment_id;
    this.error = '';
    this.feedback = '';
    try {
      await this.assignmentApi.decide(this.stationId, user.assignment_id, decision, note);
      this.feedback = decision === 'approve' ? 'تم اعتماد التعيين.' : 'تم رفض التعيين.';
      await this.reload();
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تنفيذ قرار التعيين.';
    } finally {
      this.busyId = null;
    }
  }

  async revoke(user: StationUserItem): Promise<void> {
    const reason = prompt('سبب إلغاء التعيين؟');
    if (!reason?.trim()) return;
    this.busyId = user.assignment_id;
    this.error = '';
    this.feedback = '';
    try {
      await this.assignmentApi.revoke(this.stationId, user.assignment_id, reason.trim());
      this.feedback = 'تم إرسال طلب إلغاء التعيين.';
      await this.reload();
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر إلغاء التعيين.';
    } finally {
      this.busyId = null;
    }
  }
}
