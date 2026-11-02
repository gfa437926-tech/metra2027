import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  StationCatalogueItem,
  StationCatalogueLoadState,
  StationCatalogueQuery,
  StationSourceKind
} from './station-catalogue.models';
import { StationCatalogueHttpError, StationCatalogueService } from './station-catalogue.service';

@Component({
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <main class="stations-page" dir="rtl">
      <header class="page-heading">
        <div>
          <p class="eyebrow">إدارة البنية الميدانية</p>
          <h1>دليل المحطات</h1>
          <p class="subtitle">عرض موحّد للمحطات الكلاسيكية والآلية مع الاحتفاظ بمصدر كل سجل</p>
        </div>
        <button class="refresh-button" type="button" (click)="load()" [disabled]="state() === 'loading'">
          <i class="fa-solid fa-rotate" [class.spinning]="state() === 'loading'"></i>
          تحديث البيانات
        </button>
      </header>

      <section class="source-legend" aria-label="تمييز مصادر المحطات">
        <div class="legend-item"><span class="source-icon classic"><i class="fa-solid fa-house-chimney"></i></span><span><strong>محطة كلاسيكية</strong><small>سجل من المصدر الكلاسيكي</small></span></div>
        <div class="legend-item"><span class="source-icon automatic"><i class="fa-solid fa-tower-broadcast"></i></span><span><strong>محطة آلية</strong><small>سجل من المصدر الآلي</small></span></div>
      </section>

      <section class="stats-grid" aria-label="ملخص دليل المحطات">
        <article class="stat-card"><span>إجمالي السجلات المعروضة</span><strong>{{ items().length }}</strong></article>
        <article class="stat-card"><span>الكلاسيكية المحمّلة</span><strong>{{ classicCount() }}</strong></article>
        <article class="stat-card"><span>الآلية المحمّلة</span><strong>{{ automaticCount() }}</strong></article>
        <article class="stat-card"><span>دون إحداثيات</span><strong>{{ withoutCoordinatesCount() }}</strong></article>
      </section>

      <section class="catalogue-panel">
        <div class="toolbar">
          <div class="search-field">
            <label for="station-name-prefix">بحث باسم المحطة</label>
            <input id="station-name-prefix" type="search" aria-label="بداية اسم المحطة" [ngModel]="searchText()" (ngModelChange)="searchText.set($event)" (keyup.enter)="applyFilters()" placeholder="اكتب بداية اسم المحطة..." autocomplete="off">
            <button type="button" class="apply-search" (click)="applyFilters()" [disabled]="state() === 'loading'">بحث</button>
          </div>
          <div class="filter-group" aria-label="تصفية حسب نوع المحطة">
            <button type="button" [class.selected]="sourceFilter() === 'all'" (click)="setSourceFilter('all')">الكل</button>
            <button type="button" [class.selected]="sourceFilter() === 'classic'" (click)="setSourceFilter('classic')">الكلاسيكية</button>
            <button type="button" [class.selected]="sourceFilter() === 'automatic'" (click)="setSourceFilter('automatic')">الآلية</button>
          </div>
        </div>

        @if (state() === 'unconfigured') {
          <div class="state-panel">
            <i class="fa-solid fa-plug-circle-xmark"></i>
            <h2>مصدر بيانات المحطات غير موصول بعد</h2>
            <p>واجهة الدليل جاهزة، لكن خدمة القراءة الآمنة لم تُفعّل. لن نعرض سجلات تجريبية أو بيانات غير موثقة.</p>
          </div>
        } @else if (state() === 'loading') {
          <div class="state-panel"><i class="fa-solid fa-spinner spinning"></i><h2>جارٍ تحميل دليل المحطات</h2><p>يتم طلب البيانات من واجهة النظام.</p></div>
        } @else if (state() === 'unauthenticated') {
          <div class="state-panel"><i class="fa-solid fa-lock"></i><h2>يلزم تسجيل الدخول</h2><p>سجّل الدخول بحساب معتمد للوصول إلى دليل المحطات.</p></div>
        } @else if (state() === 'forbidden') {
          <div class="state-panel"><i class="fa-solid fa-shield-halved"></i><h2>لا تملك صلاحية عرض المحطات</h2><p>يجب اعتماد صلاحية قراءة دليل المحطات من الجهة المختصة.</p></div>
        } @else if (state() === 'unavailable') {
          <div class="state-panel"><i class="fa-solid fa-triangle-exclamation"></i><h2>تعذّر تحميل الدليل</h2><p>{{ errorMessage() }}</p><button type="button" class="retry-button" (click)="load()">إعادة المحاولة</button></div>
        } @else if (filteredItems().length === 0) {
          <div class="state-panel"><i class="fa-solid fa-magnifying-glass"></i><h2>لا توجد محطات مطابقة</h2><p>جرّب تغيير عبارة البحث أو نوع المحطة.</p></div>
        } @else {
          <div class="table-wrap">
            <table>
              <thead><tr><th>المحطة</th><th>المصدر</th><th>رمز المصدر</th><th>الإحداثيات</th><th>الارتفاع</th><th>حالة الموقع</th></tr></thead>
              <tbody>
                @for (station of filteredItems(); track station.sourceKind + ':' + station.sourceRecordId) {
                  <tr>
                    <td><strong>{{ station.displayName }}</strong><small class="record-id">المعرّف الأصلي: {{ station.sourceRecordId }}</small></td>
                    <td><span class="source-pill" [class.classic-pill]="station.sourceKind === 'classic'" [class.automatic-pill]="station.sourceKind === 'automatic'">{{ sourceLabel(station.sourceKind) }}</span></td>
                    <td>{{ station.sourceCode || '—' }}</td>
                    <td class="coordinates">{{ coordinates(station) }}</td>
                    <td>{{ station.elevationMetres === null ? '—' : station.elevationMetres + ' م' }}</td>
                    <td><span class="location-state" [class.missing]="!hasCoordinates(station)">{{ hasCoordinates(station) ? 'محدد الموقع' : 'دون إحداثيات' }}</span></td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
          @if (loadMoreError()) {
            <div class="load-more-error" role="alert">
              <span>{{ errorMessage() }}</span>
              <button type="button" (click)="loadMoreErrorRequiresReload() ? load() : loadMore()" [disabled]="isLoadingMore()">{{ loadMoreErrorRequiresReload() ? 'إعادة تحميل الدليل' : 'إعادة المحاولة' }}</button>
            </div>
          }
          @if (hasMore()) {
            <div class="load-more">
              <button type="button" (click)="loadMore()" [disabled]="isLoadingMore()">
                {{ isLoadingMore() ? 'جارٍ تحميل المزيد…' : 'تحميل المزيد' }}
              </button>
            </div>
          }
        }
      </section>

      <section class="map-readiness">
        <div class="map-readiness-icon"><i class="fa-solid fa-map-location-dot"></i></div>
        <div><h2>طبقة الخريطة الموحدة</h2><p>كل محطة ذات إحداثيات ستظهر بعلامة مستقلة حسب مصدرها: أيقونة للكلاسيكية وأخرى للآلية. السجلات غير محددة الموقع ستبقى في الدليل ولن تُمنح إحداثيات افتراضية.</p><small>عرض الخريطة الجغرافية الفعلي ينتظر اعتماد مزود الخرائط وربط واجهة القراءة الآمنة.</small></div>
      </section>
    </main>
  `,
  styles: [`
    :host{display:block;color:#263747;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
    .stations-page{max-width:1500px;margin:0 auto}
    .page-heading{display:flex;justify-content:space-between;align-items:center;gap:20px;margin-bottom:24px}
    .eyebrow{color:#2780b9;font-size:12px;font-weight:800;margin:0 0 5px}.page-heading h1{font-size:clamp(25px,3vw,34px);margin:0;font-weight:900}.subtitle{color:#6c7a89;margin:8px 0 0;font-size:14px}
    .refresh-button,.retry-button{border:0;border-radius:9px;background:#247eaf;color:white;padding:11px 16px;font-weight:700;cursor:pointer;display:flex;align-items:center;gap:8px}.refresh-button:disabled{opacity:.6;cursor:wait}
    .source-legend{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:20px}.legend-item{display:flex;align-items:center;gap:10px;background:#fff;border:1px solid #e4eaf0;border-radius:12px;padding:12px 16px;min-width:220px}.legend-item strong,.legend-item small{display:block}.legend-item strong{font-size:13px}.legend-item small{font-size:11px;color:#7c8995;margin-top:3px}
    .source-icon{width:38px;height:38px;border-radius:10px;display:grid;place-items:center}.source-icon.classic{background:#eaf3ff;color:#2769b1}.source-icon.automatic{background:#e8f7f0;color:#16845a}
    .stats-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:13px;margin-bottom:20px}.stat-card{background:#fff;border:1px solid #e5ebf0;border-radius:12px;padding:16px}.stat-card span{display:block;color:#778592;font-size:12px}.stat-card strong{display:block;font-size:26px;margin-top:7px;font-weight:900}
    .catalogue-panel{background:#fff;border:1px solid #e2e8ee;border-radius:15px;overflow:hidden}.toolbar{padding:17px;display:flex;justify-content:space-between;align-items:end;gap:16px;border-bottom:1px solid #e9eef2;flex-wrap:wrap}.search-field{display:grid;gap:7px;min-width:min(100%,300px);font-size:12px;font-weight:700;color:#536272}.search-field input{border:1px solid #dce4eb;border-radius:8px;padding:10px 12px;font:inherit;min-width:270px;outline-color:#2780b9}.apply-search{border:1px solid #247eaf;border-radius:8px;background:#247eaf;color:#fff;padding:10px 15px;font:inherit;font-size:12px;font-weight:800;cursor:pointer}.apply-search:disabled{opacity:.6;cursor:wait}
    .filter-group{display:flex;gap:6px;flex-wrap:wrap}.filter-group button{border:1px solid #dce4eb;background:#fff;color:#5d6b78;padding:9px 13px;border-radius:8px;cursor:pointer;font:inherit;font-size:12px}.filter-group button.selected{background:#eaf4fb;color:#176b9f;border-color:#9fc9e2;font-weight:800}
    .state-panel{padding:54px 20px;text-align:center;color:#71808e}.state-panel>i{font-size:35px;color:#7d9aaf}.state-panel h2{font-size:18px;color:#34495e;margin:14px 0 8px}.state-panel p{font-size:13px;line-height:1.8;max-width:650px;margin:0 auto 14px}
    .table-wrap{overflow:auto}table{width:100%;border-collapse:collapse;min-width:850px;text-align:right}th{background:#f7f9fb;color:#697987;font-size:12px;font-weight:800;padding:13px 15px;white-space:nowrap}td{padding:14px 15px;border-top:1px solid #edf1f4;font-size:13px}td strong{display:block}td .record-id{display:block;color:#8a97a3;font-size:10px;margin-top:5px}.source-pill,.location-state{display:inline-block;border-radius:20px;padding:5px 9px;font-size:11px;font-weight:800;white-space:nowrap}.classic-pill{background:#eaf3ff;color:#2769b1}.automatic-pill{background:#e8f7f0;color:#16845a}.location-state{background:#e8f7f0;color:#16845a}.location-state.missing{background:#fff4df;color:#9a6811}.coordinates{direction:ltr;text-align:right;font-variant-numeric:tabular-nums}.load-more{padding:16px;text-align:center;border-top:1px solid #edf1f4}.load-more button{border:1px solid #b8d2e2;border-radius:8px;background:#f3f9fc;color:#176b9f;padding:9px 18px;font-weight:800;cursor:pointer}
    .load-more-error{display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;padding:13px 16px;color:#9a4b18;background:#fff8ef;border-top:1px solid #f2dfc8;font-size:12px}.load-more-error button{border:1px solid #d7a77c;border-radius:8px;background:#fff;color:#8b4b1b;padding:7px 12px;font-weight:800;cursor:pointer}
    .map-readiness{display:flex;gap:15px;align-items:flex-start;background:#f1f7fb;border:1px solid #d8e8f2;border-radius:13px;padding:17px;margin-top:18px}.map-readiness-icon{width:42px;height:42px;flex:none;border-radius:10px;background:#dceefa;color:#267cae;display:grid;place-items:center;font-size:18px}.map-readiness h2{font-size:15px;margin:0 0 6px}.map-readiness p{font-size:12px;line-height:1.8;color:#586b7a;margin:0 0 5px}.map-readiness small{font-size:11px;color:#7d8b96}
    .spinning{animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
    @media(max-width:850px){.stats-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.page-heading{align-items:flex-start;flex-direction:column}.refresh-button{align-self:flex-start}}
    @media(max-width:480px){.stats-grid{grid-template-columns:1fr 1fr}.legend-item{min-width:100%}.search-field,.search-field input{min-width:100%;width:100%}}
  `]
})
export class StationsComponent {
  private readonly catalogue = inject(StationCatalogueService);
  readonly state = signal<StationCatalogueLoadState>(
    this.catalogue.isConfigured ? 'loading' : 'unconfigured'
  );
  readonly items = signal<readonly StationCatalogueItem[]>([]);
  readonly hasMore = signal(false);
  readonly nextCursor = signal<string | null>(null);
  readonly isLoadingMore = signal(false);
  readonly loadMoreError = signal(false);
  readonly loadMoreErrorRequiresReload = signal(false);
  readonly sourceFilter = signal<'all' | StationSourceKind>('all');
  readonly errorMessage = signal('تعذّر الاتصال بخدمة دليل المحطات.');
  readonly searchText = signal('');
  private readonly appliedSearch = signal('');
  private readonly consumedCursors = new Set<string>();
  private requestGeneration = 0;

  readonly classicCount = computed(() => this.items().filter(x => x.sourceKind === 'classic').length);
  readonly automaticCount = computed(() => this.items().filter(x => x.sourceKind === 'automatic').length);
  readonly withoutCoordinatesCount = computed(() => this.items().filter(x => !this.hasCoordinates(x)).length);
  readonly filteredItems = computed(() => this.items());

  constructor() {
    if (this.catalogue.isConfigured) void this.load();
  }

  async load(): Promise<void> {
    const generation = ++this.requestGeneration;
    if (!this.catalogue.isConfigured) {
      this.state.set('unconfigured');
      return;
    }
    this.state.set('loading');
    this.isLoadingMore.set(false);
    this.loadMoreError.set(false);
    this.loadMoreErrorRequiresReload.set(false);
    this.items.set([]);
    this.hasMore.set(false);
    this.nextCursor.set(null);
    this.consumedCursors.clear();
    try {
      const page = await this.catalogue.readPage(this.buildQuery());
      if (generation !== this.requestGeneration) return;
      this.items.set(page.items);
      this.hasMore.set(page.hasMore);
      this.nextCursor.set(page.nextCursor);
      this.state.set('loaded');
    } catch (error: unknown) {
      if (generation === this.requestGeneration) this.setErrorState(error);
    }
  }

  async loadMore(): Promise<void> {
    const cursor = this.nextCursor();
    const generation = this.requestGeneration;
    if (!cursor || this.state() !== 'loaded' || this.isLoadingMore()) return;
    if (this.consumedCursors.has(cursor)) {
      this.errorMessage.set('تم اكتشاف مؤشر صفحات مكرر؛ أعد تحميل الدليل للمتابعة بأمان.');
      this.loadMoreError.set(true);
      this.loadMoreErrorRequiresReload.set(true);
      return;
    }
    this.isLoadingMore.set(true);
    this.loadMoreError.set(false);
    this.loadMoreErrorRequiresReload.set(false);
    try {
      const page = await this.catalogue.readPage({ ...this.buildQuery(), cursor });
      if (generation !== this.requestGeneration) return;
      const known = new Set(this.items().map(x => x.sourceKind + ':' + x.sourceRecordId));
      if (page.items.some(x => known.has(x.sourceKind + ':' + x.sourceRecordId))) {
        throw new StationCatalogueHttpError(502, 'Duplicate station identity across catalogue pages.');
      }
      if (page.nextCursor && (page.nextCursor === cursor || this.consumedCursors.has(page.nextCursor))) {
        throw new StationCatalogueHttpError(502, 'Station catalogue cursor cycle detected.');
      }
      this.consumedCursors.add(cursor);
      this.items.update(current => [...current, ...page.items]);
      this.hasMore.set(page.hasMore);
      this.nextCursor.set(page.nextCursor);
    } catch (error: unknown) {
      if (generation === this.requestGeneration) {
        if (error instanceof StationCatalogueHttpError &&
            (error.status === 401 || error.status === 403)) {
          this.setErrorState(error);
        } else {
          const requiresReload = error instanceof StationCatalogueHttpError && error.status === 502;
          this.errorMessage.set(requiresReload
            ? 'وصلت استجابة غير متوافقة أو مكررة من الخادم. أعد تحميل الدليل لبدء تسلسل صفحات جديد.'
            : error instanceof Error
              ? error.message
              : 'تعذّر تحميل الصفحة التالية. يمكنك إعادة المحاولة.');
          this.loadMoreErrorRequiresReload.set(requiresReload);
          this.loadMoreError.set(true);
        }
      }
    } finally {
      if (generation === this.requestGeneration) this.isLoadingMore.set(false);
    }
  }

  setSourceFilter(value: 'all' | StationSourceKind): void {
    if (this.sourceFilter() === value) return;
    this.sourceFilter.set(value);
    void this.load();
  }

  applyFilters(): void {
    this.appliedSearch.set(this.searchText().trim());
    void this.load();
  }

  private buildQuery(): StationCatalogueQuery {
    const sourceKind = this.sourceFilter();
    const namePrefix = this.appliedSearch();
    return {
      pageSize: 50,
      ...(sourceKind === 'all' ? {} : { sourceKind }),
      ...(namePrefix ? { namePrefix } : {})
    };
  }
  sourceLabel(value: StationSourceKind): string { return value === 'classic' ? 'كلاسيكية' : 'آلية'; }
  hasCoordinates(item: StationCatalogueItem): boolean {
    return item.latitude !== null && item.longitude !== null;
  }
  coordinates(item: StationCatalogueItem): string {
    return this.hasCoordinates(item) ? `${item.latitude}, ${item.longitude}` : '—';
  }

  private setErrorState(error: unknown): void {
    if (error instanceof StationCatalogueHttpError && error.status === 401) {
      this.state.set('unauthenticated');
    } else if (error instanceof StationCatalogueHttpError && error.status === 403) {
      this.state.set('forbidden');
    } else {
      this.errorMessage.set(error instanceof Error ? error.message : 'حدث خطأ غير متوقع.');
      this.state.set('unavailable');
    }
  }
}
