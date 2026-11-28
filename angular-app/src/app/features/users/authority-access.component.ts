import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  AuthorityAccessApiService, AuthorityAccessKind, AuthorityAccessQueueItem,
  AuthorityAccessAuditItem, AuthorityItem, AuthorityMembershipRole, AuthorityPermissionOption
} from '../../core/api/authority-access-api.service';

@Component({
  selector: 'metra-authority-access',
  standalone: true,
  imports: [FormsModule],
  template: `
    <section class="authority-panel" dir="rtl" aria-labelledby="authority-access-title">
      <header class="heading">
        <div>
          <span class="eyebrow">إدارة نطاق السلطة</span>
          <h2 id="authority-access-title">العضويات والمنح والصلاحيات</h2>
          <p>طلبات العضوية والمنح تخضع لمراجعة مستقلة داخل السلطة المختارة، مع سجل تدقيق مركزي.</p>
        </div>
        <button type="button" class="refresh" (click)="refresh()" [disabled]="busy || !selectedAuthorityId">تحديث</button>
      </header>

      @if (!api.isConfigured) {
        <div class="notice warning">يلزم إعداد عنوان API وإعدادات Supabase العامة لتفعيل إدارة الوصول.</div>
      } @else {
        <label class="authority-select">السلطة الجوية
          <select [(ngModel)]="selectedAuthorityId" name="authority" (ngModelChange)="onAuthorityChanged()" [disabled]="loadingAuthorities">
            <option value="">اختر السلطة</option>
            @for (authority of authorities; track authority.id) {
              <option [value]="authority.id">{{ authority.name_ar }} — {{ authority.country_name_ar }}</option>
            }
          </select>
        </label>

        @if (error) { <div class="notice error" role="alert">{{ error }}</div> }
        @if (notice) { <div class="notice success" role="status">{{ notice }}</div> }

        @if (!selectedAuthorityId) {
          <div class="empty">اختر السلطة لعرض الأدوار والطلبات التابعة لها.</div>
        } @else {
          <div class="request-grid">
            <form class="request-card" (ngSubmit)="submitMembership()">
              <h3>طلب عضوية في السلطة</h3>
              <label>الدور
                <select name="role" [(ngModel)]="roleCode" required>
                  <option value="">اختر الدور</option>
                  @for (role of roles; track role.role_code) {
                    <option [value]="role.role_code">{{ role.name_ar }}{{ role.is_requestable ? ' — طلب ذاتي' : ' — يتطلب ترشيحاً إدارياً' }}</option>
                  }
                </select>
              </label>
              <label>معرّف المستخدم المستهدف (اختياري للترشيح الإداري)
                <input name="targetUser" [(ngModel)]="targetUserId" maxlength="36" dir="ltr" placeholder="اتركه فارغاً لطلب عضويتك">
              </label>
              <label>مبرر الطلب
                <textarea name="membershipReason" [(ngModel)]="membershipReason" rows="2" maxlength="2000" required></textarea>
              </label>
              <button type="submit" [disabled]="busy || !roleCode || membershipReason.trim().length < 5">إرسال طلب العضوية</button>
            </form>

            <form class="request-card" (ngSubmit)="submitGrant()">
              <h3>طلب منحة صلاحية فردية</h3>
              <label>الصلاحية المتاحة لدورك
                <select name="permission" [(ngModel)]="permissionCode" required>
                  <option value="">اختر الصلاحية</option>
                  @for (permission of permissions; track permission.permission_code) {
                    <option [value]="permission.permission_code">{{ permission.permission_code }}</option>
                  }
                </select>
              </label>
              <label>مبرر الطلب
                <textarea name="grantReason" [(ngModel)]="grantReason" rows="2" maxlength="2000" required></textarea>
              </label>
              <button type="submit" [disabled]="busy || !permissionCode || grantReason.trim().length < 5">إرسال طلب المنحة</button>
              @if (permissions.length === 0) {
                <small class="hint">لا تظهر خيارات الصلاحيات إلا بعد اعتماد عضويتك في هذه السلطة وربطها بدور فعّال.</small>
              }
            </form>
          </div>

          <div class="view-switch" role="group" aria-label="قائمة إدارة الوصول">
            <button type="button" [class.active]="view === 'membership'" (click)="setView('membership')">طلبات العضوية</button>
            <button type="button" [class.active]="view === 'permission_grant'" (click)="setView('permission_grant')">طلبات المنح</button>
            <button type="button" [class.active]="view === 'membership_active'" (click)="setView('membership_active')">العضويات الفعالة</button>
            <button type="button" [class.active]="view === 'permission_grant_active'" (click)="setView('permission_grant_active')">المنح الفعالة</button>
            <button type="button" [class.active]="view === 'audit'" (click)="setView('audit')">سجل التدقيق</button>
          </div>

          @if (loading) {
            <div class="empty">جارٍ تحميل بيانات السلطة…</div>
          } @else if (view === 'audit') {
            @if (audit.length === 0) {
              <div class="empty">لا توجد أحداث تدقيق مسجلة لهذه السلطة.</div>
            } @else {
              <div class="audit-list">
                @for (event of audit; track event.id) {
                  <article>
                    <div><strong>{{ auditLabel(event) }}</strong><time>{{ formatDate(event.occurred_at) }}</time></div>
                    <p>{{ event.reason }}</p>
                    <small>{{ event.target_kind }} · {{ event.target_id }} · المنفذ {{ shortId(event.actor_user_id) }} · المستهدف {{ shortId(event.subject_user_id) }}</small>
                  </article>
                }
              </div>
            }
          } @else if (queue.length === 0) {
            <div class="empty">لا توجد طلبات معلّقة في هذه القائمة أو لا تملك صلاحية مراجعتها.</div>
          } @else {
            <div class="queue-meta">{{ queue.length }} طلبات معلّقة</div>
            <div class="queue-list">
              @for (item of queue; track item.id) {
                <article class="queue-card">
                  <div class="item-head">
                    <strong>{{ item.role_code || item.permission_code }}</strong>
                    <span>{{ item.status }}</span>
                  </div>
                  <p>المستخدم: {{ item.user_id }}</p>
                  <p>مبرر الطلب: {{ item.reason }}</p>
                  <small>رقم الطلب: {{ item.id }} · تاريخ الإنشاء: {{ formatDate(item.created_at) }}</small>
                  <label>سبب القرار
                    <textarea #decisionReason rows="2" maxlength="2000" placeholder="سبب الاعتماد أو الرفض (5 أحرف على الأقل)"></textarea>
                  </label>
                  <div class="actions">
                    @if (view === 'membership_active' || view === 'permission_grant_active') {
                      <button type="button" class="reject" [disabled]="busy || decisionReason.value.trim().length < 5" (click)="revoke(item, decisionReason.value)">إلغاء الصلاحية</button>
                    } @else {
                      <button type="button" class="approve" [disabled]="busy || decisionReason.value.trim().length < 5" (click)="decide(item, 'approve', decisionReason.value)">اعتماد</button>
                      <button type="button" class="reject" [disabled]="busy || decisionReason.value.trim().length < 5" (click)="decide(item, 'reject', decisionReason.value)">رفض</button>
                    }
                  </div>
                </article>
              }
            </div>
          }
        }
      }
      <p class="security-note">لا تُمنح الصلاحيات من الواجهة مباشرة؛ قاعدة البيانات تتحقق من العضوية والدور والمنحة والسلطة وتمنع اعتماد صاحب الطلب لنفسه.</p>
    </section>
  `,
  styles: [`
    :host{display:block;margin:20px 0;color:#263b4b;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .authority-panel{background:#fff;border:1px solid #e5edf1;border-radius:14px;padding:22px;box-shadow:0 5px 18px #2233440b}
    .heading{display:flex;justify-content:space-between;gap:14px;align-items:flex-start;margin-bottom:16px}
    .eyebrow{font-size:12px;color:#287caf;font-weight:800}.heading h2{font-size:20px;margin:5px 0}.heading p{font-size:12px;color:#778691;line-height:1.8;margin:0}
    label{display:grid;gap:6px;font-size:12px;font-weight:700;color:#627581}
    input,select,textarea{font:inherit;border:1px solid #dce5ea;border-radius:8px;padding:9px;background:#fff;color:#2d4858;min-width:0}
    .authority-select{max-width:520px;margin:12px 0 16px}.authority-select select{width:100%}
    .refresh,.request-card button,.actions button{border:0;border-radius:8px;padding:9px 13px;font:inherit;font-size:12px;font-weight:800;cursor:pointer;background:#287eae;color:white}
    button:disabled{opacity:.55;cursor:not-allowed}.refresh{background:#f0f5f8;color:#315b72;border:1px solid #dce6ec}
    .request-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin:14px 0}
    .request-card{display:grid;gap:10px;padding:16px;border:1px solid #e7edf1;border-radius:11px;background:#fbfcfd}
    .request-card h3{margin:0;font-size:15px;color:#29495e}.hint{font-size:11px;color:#87939b;line-height:1.7}
    .view-switch{display:flex;gap:5px;background:#f1f5f7;padding:4px;border-radius:9px;width:max-content;max-width:100%;margin:18px 0 12px}
    .view-switch button{border:0;background:transparent;color:#657985;padding:8px 13px;border-radius:7px;font:inherit;font-size:12px;cursor:pointer}
    .view-switch button.active{background:white;color:#176b9c;font-weight:800;box-shadow:0 1px 5px #22334418}
    .notice{padding:10px 12px;border-radius:8px;font-size:12px;margin:10px 0}.warning{background:#fff7e8;color:#875d19}.error{background:#fff0ef;color:#a33e35}.success{background:#edf8f1;color:#287448}
    .empty{padding:24px;text-align:center;background:#f7f9fa;border:1px dashed #dce5ea;border-radius:9px;color:#87939b;font-size:12px}
    .queue-meta{font-size:12px;color:#75848d;margin:8px 0}.queue-list,.audit-list{display:grid;gap:10px}
    .queue-card,.audit-list article{border:1px solid #e7edf1;border-radius:10px;padding:14px;background:#fff}
    .item-head,.audit-list article>div{display:flex;justify-content:space-between;gap:10px;align-items:center}.item-head strong{font-size:13px}.item-head span{font-size:11px;color:#6f7f89}
    .queue-card p,.audit-list p{font-size:12px;color:#647682;margin:7px 0;overflow-wrap:anywhere}.queue-card small,.audit-list small{font-size:10px;color:#87939b;overflow-wrap:anywhere}
    .queue-card label{margin-top:10px}.actions{display:flex;gap:7px;margin-top:9px}.actions .reject{background:#a64c43}.actions .approve{background:#287eae}
    .audit-list time{font-size:11px;color:#87939b}.audit-list strong{font-size:12px}.security-note{font-size:10px;color:#8a969e;margin:16px 0 0;line-height:1.7}
    @media(max-width:760px){.request-grid{grid-template-columns:1fr}.heading{flex-direction:column}.view-switch{width:100%;flex-wrap:wrap}.view-switch button{flex:1}}
  `]
})
export class AuthorityAccessComponent implements OnInit {
  readonly api = inject(AuthorityAccessApiService);
  authorities: AuthorityItem[] = [];
  roles: AuthorityMembershipRole[] = [];
  permissions: AuthorityPermissionOption[] = [];
  queue: AuthorityAccessQueueItem[] = [];
  audit: AuthorityAccessAuditItem[] = [];
  selectedAuthorityId = '';
  roleCode = '';
  targetUserId = '';
  membershipReason = '';
  permissionCode = '';
  grantReason = '';
  view: AuthorityAccessKind | 'audit' = 'membership';
  loadingAuthorities = false;
  loading = false;
  busy = false;
  error = '';
  notice = '';

  ngOnInit(): void { void this.loadAuthorities(); }

  async loadAuthorities(): Promise<void> {
    this.loadingAuthorities = true;
    this.error = '';
    try {
      this.authorities = await this.api.getAuthorities();
      if (this.authorities.length) {
        this.selectedAuthorityId = this.authorities[0].id;
        await this.loadAuthorityData();
      }
    } catch (error) {
      this.error = this.message(error, 'تعذر تحميل دليل السلطات الجوية.');
    } finally { this.loadingAuthorities = false; }
  }

  async onAuthorityChanged(): Promise<void> { await this.loadAuthorityData(); }

  async refresh(): Promise<void> {
    await this.loadAuthorityData();
  }

  async loadAuthorityData(): Promise<void> {
    if (!this.selectedAuthorityId) return;
    this.loading = true;
    this.error = '';
    try {
      const [roles, permissions] = await Promise.all([
        this.api.getMembershipRoles(this.selectedAuthorityId),
        this.api.getPermissionOptions(this.selectedAuthorityId).catch(() => [])
      ]);
      this.roles = roles;
      this.permissions = permissions;
      this.roleCode = this.roles.find(role => role.is_requestable)?.role_code ?? '';
      this.permissionCode = this.permissions[0]?.permission_code ?? '';
      await this.loadCurrentView();
    } catch (error) {
      this.error = this.message(error, 'تعذر تحميل بيانات السلطة.');
    } finally { this.loading = false; }
  }

  async setView(view: AuthorityAccessKind | 'audit'): Promise<void> {
    this.view = view;
    await this.loadCurrentView();
  }

  async loadCurrentView(): Promise<void> {
    if (!this.selectedAuthorityId) return;
    try {
      if (this.view === 'audit') {
        this.audit = await this.api.getAudit(this.selectedAuthorityId);
        this.queue = [];
      } else {
        this.queue = await this.api.getQueue(this.selectedAuthorityId, this.view);
        this.audit = [];
      }
    } catch (error) {
      this.queue = [];
      this.audit = [];
      this.error = this.message(error, 'تعذر تحميل القائمة؛ قد لا تتوفر صلاحية المراجعة لهذا الحساب.');
    }
  }

  async submitMembership(): Promise<void> {
    if (!this.selectedAuthorityId || !this.roleCode || this.membershipReason.trim().length < 5) return;
    await this.run(async () => {
      await this.api.requestMembership(this.selectedAuthorityId, this.roleCode,
        this.membershipReason.trim(), this.targetUserId.trim() || undefined);
      this.membershipReason = '';
      this.targetUserId = '';
      this.notice = 'تم إرسال طلب العضوية للمراجعة.';
    });
  }

  async submitGrant(): Promise<void> {
    if (!this.selectedAuthorityId || !this.permissionCode || this.grantReason.trim().length < 5) return;
    await this.run(async () => {
      await this.api.requestPermissionGrant(this.selectedAuthorityId, this.permissionCode, this.grantReason.trim());
      this.grantReason = '';
      this.notice = 'تم إرسال طلب المنحة للمراجعة.';
    });
  }

  async decide(item: AuthorityAccessQueueItem, decision: 'approve' | 'reject', reason: string): Promise<void> {
    if (!this.selectedAuthorityId || reason.trim().length < 5) return;
    if (this.view !== 'membership' && this.view !== 'permission_grant') return;
    await this.run(async () => {
      if (this.view === 'membership')
        await this.api.decideMembership(this.selectedAuthorityId, item.id, decision, reason.trim());
      else
        await this.api.decidePermissionGrant(this.selectedAuthorityId, item.id, decision, reason.trim());
      this.notice = decision === 'approve' ? 'تم اعتماد الطلب.' : 'تم رفض الطلب.';
    });
  }


  async revoke(item: AuthorityAccessQueueItem, reason: string): Promise<void> {
    if (!this.selectedAuthorityId || reason.trim().length < 5) return;
    if (this.view !== 'membership_active' && this.view !== 'permission_grant_active') return;
    await this.run(async () => {
      if (this.view === 'membership_active')
        await this.api.revokeMembership(this.selectedAuthorityId, item.id, reason.trim());
      else
        await this.api.revokePermissionGrant(this.selectedAuthorityId, item.id, reason.trim());
      this.notice = 'تم إلغاء الصلاحية وتسجيل الحدث في سجل التدقيق.';
    });
  }

  auditLabel(event: AuthorityAccessAuditItem): string {
    const target = event.target_kind === 'membership' ? 'عضوية' : 'منحة صلاحية';
    const action: Record<string, string> = {
      requested: 'طلب جديد', approved: 'اعتماد', rejected: 'رفض', revoked: 'إلغاء'
    };
    return `${target} — ${action[event.action_code] ?? event.action_code}`;
  }

  formatDate(value: string): string {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(date);
  }

  shortId(value: string): string { return value ? `${value.slice(0, 8)}…${value.slice(-4)}` : '—'; }

  private async run(action: () => Promise<void>): Promise<void> {
    this.busy = true;
    this.error = '';
    this.notice = '';
    try {
      await action();
      await this.loadCurrentView();
    } catch (error) {
      this.error = this.message(error, 'تعذر تنفيذ العملية؛ تحقّق من صلاحيات الحساب والسلطة المحددة.');
    } finally { this.busy = false; }
  }

  private message(error: unknown, fallback: string): string {
    const value = error as { error?: { title?: string; error?: string }; message?: string };
    return value?.error?.title || value?.error?.error || value?.message || fallback;
  }
}
