import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import {
  RegistrationAuditItem,
  RegistrationRequestItem,
  RegistrationReviewApiService,
  RegistrationReviewStage
} from '../../core/api/registration-review-api.service';
import { StationContextService } from '../../core/station/station-context.service';

@Component({
  standalone: true,
  selector: 'metra-registration-review',
  imports: [CommonModule, FormsModule],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <h1>مراجعة طلبات التسجيل</h1>
          <p>القرارات تُنفَّذ على الخادم ضمن نطاق المحطة المحددة. رفض الطلب يتطلب سبباً.</p>
        </div>
        <button type="button" class="primary" [disabled]="loading" (click)="reload()">تحديث</button>
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
        <label>
          مرحلة المراجعة
          <select [(ngModel)]="stage" (ngModelChange)="reload()">
            <option value="station">مراجعة المحطة</option>
            <option value="system">المراجعة النظامية</option>
          </select>
        </label>
      </div>

      <div class="tabs">
        <button type="button" [class.active]="tab==='queue'" (click)="tab='queue'">الطلبات</button>
        <button type="button" [class.active]="tab==='audit'" (click)="tab='audit'">سجل التدقيق</button>
      </div>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner ok" *ngIf="feedback">{{ feedback }}</div>
      <div class="banner info" *ngIf="loading">جاري التحميل...</div>

      <ng-container *ngIf="!loading && tab==='queue'">
        <div class="banner info" *ngIf="!stationId">اختر محطة ضمن صلاحياتك أولاً.</div>
        <div class="banner info" *ngIf="stationId && queue.length===0">لا توجد طلبات في هذه المرحلة.</div>
        <div class="table-wrap" *ngIf="queue.length">
          <table>
            <thead>
              <tr>
                <th>مقدم الطلب</th>
                <th>الدور المطلوب</th>
                <th>المحطة</th>
                <th>الحالة</th>
                <th>تاريخ الإرسال (UTC)</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let item of queue">
                <td>
                  <strong>{{ displayName(item) }}</strong>
                  <small>{{ item.user_id }}</small>
                </td>
                <td>{{ item.metra_role_catalogue?.name_ar || item.requested_role_code }}</td>
                <td>{{ item.station_catalogue?.name_ar || item.requested_station_id }}</td>
                <td>{{ item.status }}</td>
                <td class="ltr">{{ item.submitted_at }}</td>
                <td class="actions">
                  <button type="button" class="ok" [disabled]="busyId===item.id" (click)="decide(item,'approve')">موافقة</button>
                  <button type="button" class="warn" [disabled]="busyId===item.id" (click)="openReject(item)">رفض</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </ng-container>

      <ng-container *ngIf="!loading && tab==='audit'">
        <div class="banner info" *ngIf="stationId && audit.length===0">لا توجد أحداث تدقيق معروضة.</div>
        <div class="table-wrap" *ngIf="audit.length">
          <table>
            <thead>
              <tr>
                <th>الحدث</th>
                <th>الطلب</th>
                <th>الممثل</th>
                <th>ملاحظة</th>
                <th>الوقت (UTC)</th>
              </tr>
            </thead>
            <tbody>
              <tr *ngFor="let a of audit">
                <td>{{ a.event_type }}</td>
                <td class="ltr">{{ a.request_id }}</td>
                <td class="ltr">{{ a.actor_user_id }}</td>
                <td>{{ a.decision_note || '—' }}</td>
                <td class="ltr">{{ a.occurred_at }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </ng-container>

      <div class="modal" *ngIf="rejectTarget">
        <div class="panel">
          <h2>رفض طلب التسجيل</h2>
          <p>يجب إدخال سبب واضح. يُرسل القرار إلى الخادم ضمن نطاق المحطة.</p>
          <label>
            سبب الرفض
            <textarea rows="4" [(ngModel)]="rejectNote" maxlength="2000"></textarea>
          </label>
          <div class="panel-actions">
            <button type="button" class="ghost" (click)="rejectTarget=null">إلغاء</button>
            <button type="button" class="warn" [disabled]="!rejectNote.trim() || busyId===rejectTarget.id" (click)="decide(rejectTarget,'reject')">تأكيد الرفض</button>
          </div>
        </div>
      </div>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1200px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;margin-bottom:12px}
    h1{margin:0 0 6px;font-size:1.4rem}
    p{margin:0;color:#5c6b75;line-height:1.7}
    .toolbar{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-bottom:12px}
    label{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#4d5b64}
    input,select,textarea{border:1px solid #d5dee4;border-radius:10px;padding:10px 12px;font:inherit}
    .tabs{display:flex;gap:8px;margin-bottom:12px}
    .tabs button{border:1px solid #d5dee4;background:#fff;border-radius:999px;padding:8px 14px;cursor:pointer}
    .tabs button.active{background:#1f6f8b;color:#fff;border-color:#1f6f8b}
    .primary,.ok{background:#1f6f8b;color:#fff;border:0;border-radius:8px;padding:8px 12px;cursor:pointer}
    .warn{background:#c45c26;color:#fff;border:0;border-radius:8px;padding:8px 12px;cursor:pointer}
    .ghost{background:#edf1f4;border:0;border-radius:8px;padding:8px 12px}
    .banner{padding:12px;border-radius:10px;margin-bottom:10px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.ok{background:#e8f6ee;color:#1f6b3c}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .table-wrap{overflow:auto;border:1px solid #e4ebf0;border-radius:12px}
    table{width:100%;border-collapse:collapse;min-width:860px}
    th,td{padding:11px;border-bottom:1px solid #edf1f4;text-align:right;vertical-align:top;font-size:13px}
    th{background:#f5f8fa;color:#5b6a74}
    td small{display:block;color:#7a8791;direction:ltr}
    .ltr{direction:ltr;text-align:right}
    .actions{display:flex;gap:6px;flex-wrap:wrap}
    .modal{position:fixed;inset:0;background:rgba(16,28,40,.45);display:grid;place-items:center;padding:16px;z-index:40}
    .panel{background:#fff;border-radius:14px;padding:20px;width:min(100%,480px)}
    .panel-actions{display:flex;gap:8px;justify-content:flex-start;margin-top:12px}
    @media(max-width:800px){.toolbar{grid-template-columns:1fr}}
  `]
})
export class RegistrationReviewComponent implements OnInit {
  private readonly api = inject(RegistrationReviewApiService);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly stationContext = inject(StationContextService);

  stations: StationDirectoryItem[] = [];
  stationId = '';
  stage: RegistrationReviewStage = 'station';
  tab: 'queue' | 'audit' = 'queue';
  queue: RegistrationRequestItem[] = [];
  audit: RegistrationAuditItem[] = [];
  loading = false;
  error = '';
  feedback = '';
  busyId: string | null = null;
  rejectTarget: RegistrationRequestItem | null = null;
  rejectNote = '';

  ngOnInit(): void {
    this.stationId = this.stationContext.resolveStationId(this.route);
    void this.loadStations().then(() => this.reload());
  }

  displayName(item: RegistrationRequestItem): string {
    const p = item.metra_user_profiles;
    if (!p) return 'مستخدم';
    return [p.first_name, p.father_name, p.last_name].filter(Boolean).join(' ');
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
    this.queue = [];
    this.audit = [];
    if (!this.stationId) return;
    this.loading = true;
    try {
      if (!this.api.isConfigured) {
        throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة أولاً.');
      }
      const [queue, audit] = await Promise.all([
        this.api.getQueue(this.stationId, this.stage),
        this.api.getAudit(this.stationId, this.stage)
      ]);
      this.queue = queue;
      this.audit = audit;
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تحميل طلبات التسجيل.';
    } finally {
      this.loading = false;
    }
  }

  openReject(item: RegistrationRequestItem): void {
    this.rejectTarget = item;
    this.rejectNote = '';
  }

  async decide(item: RegistrationRequestItem, decision: 'approve' | 'reject'): Promise<void> {
    this.error = '';
    this.feedback = '';
    const note = decision === 'reject' ? this.rejectNote.trim() : undefined;
    if (decision === 'reject' && !note) {
      this.error = 'سبب الرفض مطلوب.';
      return;
    }
    this.busyId = item.id;
    try {
      await this.api.decide(this.stationId, item.id, this.stage, decision, note);
      this.feedback = decision === 'approve' ? 'تمت الموافقة على الطلب.' : 'تم رفض الطلب.';
      this.rejectTarget = null;
      this.rejectNote = '';
      await this.reload();
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تنفيذ قرار المراجعة.';
    } finally {
      this.busyId = null;
    }
  }
}
