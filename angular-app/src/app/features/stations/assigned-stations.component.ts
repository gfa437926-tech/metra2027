import { CommonModule } from '@angular/common';
import { Component, computed, inject } from '@angular/core';
import { CurrentUserContextService } from '../../core/identity/current-user-context.service';

@Component({
  standalone: true,
  imports: [CommonModule],
  template: `
    <main class="assigned-page" dir="rtl">
      <header class="heading">
        <div>
          <p class="eyebrow">حساب المستخدم</p>
          <h1>المحطات المرتبطة بحسابي</h1>
          <p>تعيينات المحطات والأدوار الواردة من خدمة الهوية.</p>
        </div>
        <button type="button" (click)="refresh()" [disabled]="identity.state() === 'loading'">
          <i class="fa-solid fa-rotate" [class.spinning]="identity.state() === 'loading'"></i>
          تحديث الحساب
        </button>
      </header>

      @if (identity.state() === 'unconfigured') {
        <section class="state-card">
          <i class="fa-solid fa-plug-circle-xmark"></i>
          <h2>خدمة الهوية غير مهيأة</h2>
          <p>لن نعرض تعيينات افتراضية. فعّل مزود الهوية وواجهة /identity/me بعد اعتماد إعدادات النشر.</p>
        </section>
      } @else if (identity.state() === 'loading') {
        <section class="state-card" role="status"><i class="fa-solid fa-spinner spinning"></i><h2>جارٍ تحميل الحساب</h2><p>يتم جلب سياق المستخدم من واجهة النظام.</p></section>
      } @else if (identity.state() !== 'active' && identity.state() !== 'pendingApproval') {
        <section class="state-card"><i class="fa-solid fa-shield-halved"></i><h2>لا يمكن عرض تعيينات المحطات</h2><p>{{ stateLabel }}</p></section>
      } @else {
        <section class="summary">
          <article><span>إجمالي التعيينات</span><strong>{{ assignments().length }}</strong></article>
          <article><span>التعيينات الفعالة</span><strong>{{ activeCount() }}</strong></article>
        </section>
        @if (assignments().length === 0) {
          <section class="state-card"><i class="fa-solid fa-location-dot"></i><h2>لا توجد محطة مرتبطة</h2><p>لم تُرجع خدمة الهوية أي تعيين لهذا الحساب.</p></section>
        } @else {
          <section class="assignment-list" aria-label="تعيينات المحطات">
            @for (item of assignments(); track item.stationId + ':' + item.roleCode + ':' + item.validFrom) {
              <article class="assignment-card">
                <header>
                  <span class="station-icon"><i class="fa-solid fa-location-dot"></i></span>
                  <div class="station-title"><h2>{{ item.stationName }}</h2><small>{{ item.stationId }}</small></div>
                  <span class="status" [class.inactive]="!item.isActive">{{ item.isActive ? 'فعال' : 'غير فعال' }}</span>
                </header>
                <div class="details">
                  <div><span>الدور</span><strong>{{ roleLabel(item.roleCode) }}</strong></div>
                  <div><span>بداية التعيين</span><strong>{{ item.validFrom | date:'yyyy-MM-dd' }}</strong></div>
                  @if (item.validTo) {
                    <div><span>نهاية التعيين</span><strong>{{ item.validTo | date:'yyyy-MM-dd' }}</strong></div>
                  }
                </div>
              </article>
            }
          </section>
        }
        <p class="security-note"><i class="fa-solid fa-lock"></i> هذه البيانات للعرض فقط؛ الخادم يعيد فحص الصلاحيات ونطاق المحطة عند كل عملية.</p>
      }
    </main>
  `,
  styles: [`
    :host{display:block;color:#263747;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .assigned-page{max-width:1250px;margin:0 auto}.heading{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:22px}.eyebrow{color:#2780b9;font-size:12px;font-weight:800;margin:0 0 5px}.heading h1{font-size:clamp(24px,3vw,32px);margin:0;font-weight:900}.heading p:not(.eyebrow){color:#71808b;font-size:13px;margin:7px 0 0}.heading button{border:0;border-radius:9px;background:#247eaf;color:#fff;padding:11px 16px;font:inherit;font-weight:700;cursor:pointer}.heading button:disabled{opacity:.6;cursor:wait}
    .summary{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin-bottom:18px}.summary article,.assignment-card,.state-card{background:#fff;border:1px solid #e3eaf0;border-radius:13px;box-shadow:0 5px 18px #2233440a}.summary article{padding:17px}.summary span{display:block;color:#71808b;font-size:12px}.summary strong{display:block;font-size:27px;margin-top:7px}
    .assignment-list{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:13px}.assignment-card{padding:17px}.assignment-card header{display:flex;align-items:center;gap:10px}.station-icon{width:40px;height:40px;border-radius:10px;background:#eaf3f8;color:#2980b9;display:grid;place-items:center}.station-title{flex:1;min-width:0}.station-title h2{font-size:15px;margin:0 0 4px}.station-title small{font-size:11px;color:#87949d}.status{padding:5px 9px;border-radius:18px;background:#e7f5ec;color:#218348;font-size:11px;font-weight:800}.status.inactive{background:#f1f2f4;color:#66717a}.details{display:grid;gap:10px;margin-top:16px;padding-top:14px;border-top:1px solid #edf1f4}.details div{display:flex;justify-content:space-between;gap:10px;font-size:12px}.details span{color:#71808b}.details strong{font-weight:700;text-align:left}.security-note{margin-top:16px;color:#687887;font-size:12px;line-height:1.8}.security-note i{color:#2980b9;margin-left:5px}
    .state-card{padding:48px 20px;text-align:center;color:#71808b}.state-card>i{font-size:34px;color:#7d9aaf}.state-card h2{font-size:18px;color:#34495e;margin:13px 0 7px}.state-card p{font-size:13px;line-height:1.8;max-width:650px;margin:0 auto}.spinning{animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
    @media(max-width:650px){.heading{align-items:flex-start;flex-direction:column}.summary{gap:9px}.assignment-list{grid-template-columns:1fr}}
  `]
})
export class AssignedStationsComponent {
  readonly identity = inject(CurrentUserContextService);
  readonly assignments = computed(() => this.identity.context()?.assignments ?? []);
  readonly activeCount = computed(() => this.assignments().filter(item => item.isActive).length);

  refresh(): void { void this.identity.refresh(); }

  get stateLabel(): string {
    const labels: Record<string, string> = {
      unauthenticated: 'يلزم تسجيل الدخول بحساب معتمد.',
      suspended: 'الحساب موقوف أو غير مفعّل.',
      forbidden: 'لا تملك صلاحية قراءة سياق الحساب.',
      unavailable: 'خدمة الهوية غير متاحة حالياً.',
      unknownAccountState: 'حالة الحساب غير معروفة؛ تم إخفاء التعيينات.'
    };
    return labels[this.identity.state()] ?? 'لا تتوفر بيانات موثقة.';
  }

  roleLabel(code: string): string {
    const labels: Record<string, string> = {
      observer: 'راصد جوي',
      station_manager: 'رئيس محطة',
      stationmanager: 'رئيس محطة',
      supervisor: 'مشرف',
      admin: 'مدير النظام'
    };
    return labels[code.toLowerCase()] ?? code;
  }
}
