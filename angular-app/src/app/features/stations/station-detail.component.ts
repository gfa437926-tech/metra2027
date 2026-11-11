import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  ObservationApiService,
  StationDirectoryItem
} from '../../core/api/observation-api.service';
import {
  StationUserDirectoryApiService,
  StationUserItem
} from '../../core/api/station-user-directory-api.service';
import { StationContextService } from '../../core/station/station-context.service';

@Component({
  standalone: true,
  selector: 'metra-station-detail',
  imports: [CommonModule, RouterLink],
  template: `
    <section class="page" dir="rtl">
      <header class="page-header">
        <div>
          <p class="crumb">
            <a routerLink="/stations">دليل المحطات</a>
            <span> / تفاصيل المحطة</span>
          </p>
          <h1>{{ station?.name_ar || 'تفاصيل المحطة' }}</h1>
          <p *ngIf="station?.name_en">{{ station?.name_en }}</p>
        </div>
        <div class="header-actions" *ngIf="stationId">
          <a class="link" [routerLink]="['/admin/station-assignments']" [queryParams]="{ stationId: stationId }">إدارة التعيينات</a>
          <a class="link" [routerLink]="['/admin/registration-review']" [queryParams]="{ stationId: stationId }">مراجعة التسجيل</a>
          <a class="link" [routerLink]="['/observations/workflow']" [queryParams]="{ stationId: stationId }">مراجعة النشرات</a>
        </div>
      </header>

      <div class="banner error" *ngIf="error">{{ error }}</div>
      <div class="banner info" *ngIf="loading">جاري تحميل بيانات المحطة...</div>
      <div class="banner info" *ngIf="!loading && !error && !station">لم يُعثر على المحطة في الكتالوج المتاح لحسابك.</div>

      <ng-container *ngIf="station as s">
        <div class="grid">
          <section class="card">
            <h2>بيانات المحطة</h2>
            <dl>
              <div><dt>المعرّف</dt><dd class="ltr">{{ s.id }}</dd></div>
              <div><dt>الرمز المحلي</dt><dd>{{ s.local_station_code || '—' }}</dd></div>
              <div><dt>WMO</dt><dd>{{ s.wmo_station_id || '—' }}</dd></div>
              <div><dt>النوع</dt><dd>{{ s.station_type }}</dd></div>
              <div><dt>الحالة التشغيلية</dt><dd>{{ s.operational_status }}</dd></div>
              <div><dt>حالة الاعتماد</dt><dd>{{ s.approval_status }}</dd></div>
              <div><dt>الارتفاع (م)</dt><dd>{{ s.elevation_m ?? '—' }}</dd></div>
              <div><dt>تجريبية؟</dt><dd>{{ s.is_demo ? 'نعم' : 'لا' }}</dd></div>
              <div>
                <dt>الإحداثيات</dt>
                <dd class="ltr" *ngIf="s.station_coordinates?.length; else noCoords">
                  {{ s.station_coordinates[0].latitude }}, {{ s.station_coordinates[0].longitude }}
                </dd>
                <ng-template #noCoords><dd>—</dd></ng-template>
              </div>
            </dl>
          </section>

          <section class="card">
            <h2>المستخدمون المرتبطون ({{ users.length }})</h2>
            <div class="banner info" *ngIf="!usersLoading && users.length===0">لا يوجد مستخدمون معروضون أو لا صلاحية للعرض.</div>
            <div class="banner info" *ngIf="usersLoading">جاري تحميل المستخدمين...</div>
            <ul class="user-list" *ngIf="users.length">
              <li *ngFor="let u of users">
                <strong>{{ u.first_name }} {{ u.last_name }}</strong>
                <span>{{ u.role_name_ar || u.assignment_role_code }} · {{ u.assignment_status }}</span>
              </li>
            </ul>
            <p class="footnote">الأوقات المعروضة من الخادم بصيغة UTC حيث تنطبق. المصدر: دليل المحطات ودليل مستخدمي المحطة عبر API.</p>
          </section>
        </div>
      </ng-container>
    </section>
  `,
  styles: [`
    .page{padding:18px;max-width:1100px;margin:0 auto}
    .page-header{display:flex;justify-content:space-between;gap:12px;margin-bottom:14px;flex-wrap:wrap}
    .crumb{margin:0 0 6px;color:#6a7882;font-size:13px}
    .crumb a{color:#1f6f8b;text-decoration:none;font-weight:700}
    h1{margin:0 0 6px;font-size:1.45rem}
    h2{margin:0 0 12px;font-size:1.05rem}
    p{margin:0;color:#5c6b75}
    .header-actions{display:flex;gap:12px;flex-wrap:wrap;align-items:center}
    .link{color:#1f6f8b;font-weight:700;text-decoration:none}
    .banner{padding:12px;border-radius:10px;margin-bottom:10px}
    .banner.error{background:#fdecee;color:#8a1f2d}
    .banner.info{background:#eef6fa;color:#1f5f7a}
    .grid{display:grid;grid-template-columns:1.2fr 1fr;gap:14px}
    .card{border:1px solid #e4ebf0;border-radius:12px;padding:14px;background:#fff}
    dl{margin:0;display:grid;gap:10px}
    dl > div{display:grid;grid-template-columns:140px 1fr;gap:8px;padding:8px 0;border-bottom:1px solid #f0f3f5}
    dt{color:#6a7882;font-size:12px}
    dd{margin:0;font-weight:600}
    .ltr{direction:ltr;text-align:right}
    .user-list{list-style:none;margin:0;padding:0}
    .user-list li{padding:10px 0;border-bottom:1px solid #f0f3f5;display:flex;flex-direction:column;gap:4px}
    .user-list span{color:#6a7882;font-size:12px}
    .footnote{margin-top:12px;font-size:11px;color:#7a8791}
    @media(max-width:900px){.grid{grid-template-columns:1fr} dl > div{grid-template-columns:1fr}}
  `]
})
export class StationDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly stationsApi = inject(ObservationApiService);
  private readonly usersApi = inject(StationUserDirectoryApiService);
  private readonly stationContext = inject(StationContextService);

  stationId = '';
  station: StationDirectoryItem | null = null;
  users: StationUserItem[] = [];
  loading = false;
  usersLoading = false;
  error = '';

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const id = params.get('stationId')?.trim() ?? '';
      this.stationId = this.stationContext.isUuid(id) ? id : '';
      if (this.stationId) {
        this.stationContext.remember(this.stationId);
        void this.load();
      } else {
        this.error = 'معرّف المحطة غير صالح.';
        this.station = null;
      }
    });
  }

  async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.station = null;
    this.users = [];
    try {
      if (!this.stationsApi.isConfigured) {
        throw new Error('يلزم ضبط عنوان API وإعدادات المصادقة أولاً.');
      }
      const all = await this.stationsApi.getAllStations();
      this.station = all.find(s => s.id === this.stationId) ?? null;
      if (!this.station) {
        this.error = 'المحطة غير موجودة ضمن الكتالوج المتاح أو لا صلاحية لعرضها.';
      }
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'تعذر تحميل المحطة.';
    } finally {
      this.loading = false;
    }

    if (!this.stationId || !this.station) return;
    this.usersLoading = true;
    try {
      if (this.usersApi.isConfigured) {
        this.users = await this.usersApi.getUsers(this.stationId);
      }
    } catch {
      // Directory may be forbidden for some roles; detail still useful without users.
      this.users = [];
    } finally {
      this.usersLoading = false;
    }
  }
}
