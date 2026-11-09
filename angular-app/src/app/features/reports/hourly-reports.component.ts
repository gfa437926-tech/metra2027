import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy } from '@angular/core';
import { ObservationApiService, StationDirectoryItem } from '../../core/api/observation-api.service';
import { DailyOfflineQueue, DailyOfflineSubmission } from '../../core/offline/daily-offline-queue';
import { createIdempotencyKey, getConfirmedDailySubmission, getSubmissionErrorMessage } from './daily-submission.utils';

type HourlyStatus = 'draft' | 'submitted';
interface HourlyPreview {
  reference: string;
  date: string;
  hour: string;
  station: string;
  status: HourlyStatus;
  values: Record<string, string>;
}

@Component({
  standalone: true,
  selector: 'metra-hourly-reports',
  imports: [CommonModule],
  template: `
    <div class="page" dir="rtl">
      <header class="page-head">
        <div class="head-icon"><i class="fa-regular fa-clock"></i></div>
        <div><h1>النشرات الساعية</h1><p>إدخال بيانات الرصد والتحقق منها قبل إرسالها للمراجعة</p></div>
        <span class="preview-tag"><i class="fa-solid fa-cloud-arrow-up"></i> إرسال محمي عبر API</span>
      </header>

      <div class="demo-warning" role="status" aria-live="polite"><i class="fa-solid fa-circle-info"></i><div><strong>{{ isOnline ? 'متصل بالشبكة' : 'غير متصل بالشبكة' }}</strong><span>{{ pendingOfflineCount }} نشرة ساعية بانتظار المزامنة</span><span *ngIf="blockedOfflineCount">{{ blockedOfflineCount }} نشرة متوقفة بسبب رفض الخادم</span><button *ngIf="blockedOfflineCount" type="button" (click)="retryBlockedOffline()">إعادة محاولة النشرات المتوقفة</button><ul *ngIf="blockedOfflineItems.length" class="offline-blocked-list"><li *ngFor="let item of blockedOfflineItems"><strong>{{ item.stationName }} — {{ item.reportDate }} ({{ item.reportType }} UTC)</strong><span>{{ item.lastError || 'رفض الخادم النشرة دون تفاصيل إضافية.' }}</span></li></ul><span *ngIf="syncing">جارٍ الإرسال تلقائياً...</span><span *ngIf="stationsError">{{ stationsError }}</span></div></div>

      <section class="panel preview-panel" *ngIf="pendingOfflineItems.length">
        <h2><i class="fa-solid fa-cloud-arrow-down"></i> نشرات ساعية محفوظة على هذا الجهاز</h2>
        <p>يمكن إعادة فتح النشرة ومراجعة قيمها دون إرسالها أو حذفها من قائمة الانتظار.</p>
        <article class="preview-row" *ngFor="let item of pendingOfflineItems">
          <div><strong>{{ item.stationName }} — {{ item.reportDate }} · {{ item.reportType }} UTC</strong><p>{{ item.state === 'blocked' ? 'تحتاج إلى مراجعة' : 'بانتظار المزامنة' }}</p></div>
          <button type="button" class="secondary" (click)="restoreOfflineSubmission(item, hourlyForm)">إعادة فتح النشرة</button>
        </article>
      </section>

      <section class="stats">
        <article><i class="fa-solid fa-calendar-day"></i><span>تاريخ اليوم</span><strong>{{ today }}</strong></article>
        <article><i class="fa-regular fa-clock"></i><span>التوقيت المحلي</span><strong>{{ now }}</strong></article>
        <article><i class="fa-solid fa-list-check"></i><span>نشرات هذه المعاينة</span><strong>{{ previews.length }}</strong></article>
      </section>

      <form #hourlyForm (submit)="submit($event, hourlyForm)">
        <section class="panel">
          <h2><i class="fa-solid fa-user-tie"></i> التعريف بالمحطة والراصد</h2>
          <div class="grid">
            <label>المحطة<select name="stationId" required [value]="selectedStationId" (change)="setStation($any($event.target).value)"><option value="">اختر المحطة</option><option *ngFor="let station of stations" [value]="station.id">{{ station.name_ar }} — {{ station.local_station_code || station.wmo_station_id || station.station_type }}</option></select><small *ngIf="stationsLoading">جارٍ تحميل المحطات...</small></label>
            <label>التاريخ (ميلادي)<input type="text" name="observationDate" [value]="today" readonly></label>
            <label>الوقت الحالي<input type="text" [value]="now" readonly></label>
          </div>
        </section>
        <section class="panel">
          <h2><i class="fa-solid fa-circle-info"></i> المعلومات الأساسية</h2>
          <div class="grid">
            <label>التوقيت العالمي (UTC) - الساعة<select name="utcTime" required (change)="setHour($any($event.target).value)"><option value="">اختر ساعة التوقيت العالمي</option>@for (h of hours; track h) {<option [value]="h">{{ h }}</option>}</select></label>
          </div>
        </section>

        <section class="panel">
          <h2><i class="fa-solid fa-temperature-half"></i> درجات الحرارة</h2>
          <div class="grid">
            <label>درجة الحرارة الجافة (سْ) *<input name="dryTemp" placeholder="+25.5" maxlength="5" required (blur)="formatField($event)"><small>التنسيق ±dd.d أو #</small></label>
            <label>درجة الحرارة الرطبة (سْ) *<input name="wetTemp" placeholder="+20.0" maxlength="5" required (blur)="formatField($event)"></label>
          </div>
        </section>
        <section class="panel">
          <h2><i class="fa-solid fa-gauge-high"></i> الضغط الجوي</h2>
          <div class="conditional-note" *ngIf="isSynoptic">هذه ساعة سينوبتية؛ حقول ميل الضغط وشكل الضغط والطقس الغابر مطلوبة.</div>
          <div class="grid">
            <label>ضغط المحطة (ميلبار) *<input name="stationPressure" placeholder="1013.2" maxlength="6" required (blur)="formatField($event)"></label>
            <label>ضغط سطح البحر (ميلبار) *<input name="seaLevelPressure" placeholder="1013.2" maxlength="6" required (blur)="formatField($event)"></label>
            <label [class.required-field]="isSynoptic">ميل الضغط (د.د)<input name="pressureSlope" placeholder="2.3" maxlength="4" [required]="isSynoptic" (blur)="formatField($event)"></label>
            <label [class.required-field]="isSynoptic">شكل الضغط<input name="pressureShape" placeholder="5" maxlength="1" [required]="isSynoptic" (blur)="formatField($event)"></label>
          </div>
        </section>
        <section class="panel">
          <h2><i class="fa-solid fa-calculator"></i> الحسابات المستخرجة</h2>
          <div class="grid">
            <label>الرطوبة النسبية (%) *<input name="relativeHumidity" placeholder="065" maxlength="3" required (blur)="formatField($event)"></label>
            <label>درجة الندى (سْ) *<input name="dewPoint" placeholder="+18.5" maxlength="5" required (blur)="formatField($event)"></label>
            <label>ضغط بخار الماء (ميلبار)<input name="vaporPressure" placeholder="16.8" maxlength="4" (blur)="formatField($event)"></label>
            <label>فرق ضغط بخار الماء<input name="vaporPressureDiff" placeholder="12.3" maxlength="4" (blur)="formatField($event)"></label>
          </div>
        </section>

        <section class="panel">
          <h2><i class="fa-solid fa-wind"></i> الرياح والرؤية</h2>
          <div class="grid">
            <label>اتجاه الرياح السطحية (عشرات) *<input name="windDirection" placeholder="18" maxlength="2" required (blur)="formatField($event)"></label>
            <label>سرعة الرياح السطحية (م/ثا) *<input name="windSpeed" placeholder="12" maxlength="2" required (blur)="formatField($event)"></label>
            <label>متوسط الاتجاه (درجة)<input name="avgWindDirection" placeholder="18" maxlength="2" (blur)="formatField($event)"></label>
            <label>متوسط السرعة (م/ثا)<input name="avgWindSpeed" placeholder="10" maxlength="2" (blur)="formatField($event)"></label>
            <label>الرؤية الأفقية (مئات الأمتار) *<input name="visibility" placeholder="050" maxlength="3" required (blur)="formatField($event)"></label>
            <label>الطقس الحاضر (الكود)<input name="currentWeather" placeholder="01" maxlength="2" (blur)="formatField($event)"></label>
            <label [hidden]="!isSynoptic" [class.required-field]="isSynoptic">الطقس الغابر (الكود) *<input name="pastWeather" placeholder="0" maxlength="1" [required]="isSynoptic" (blur)="formatField($event)"></label>
          </div>
        </section>

        <section class="panel" [hidden]="!isPrecipitationHour">
          <div class="grid"><label>كمية الهطول (ملم)<input name="precipitationAmount" placeholder="012.5" maxlength="5" [required]="isPrecipitationHour" (blur)="formatField($event)"></label></div>
        </section>

        <section class="panel">
          <h2><i class="fa-solid fa-cloud"></i> السحب والتغطية</h2>
          <div class="grid">
            <label>التغطية الكلية للسحب *<select name="totalCloudCover" required><option value="">اختر</option>@for (n of cloudValues; track n) {<option [value]="n">{{ n }}</option>}<option value="#">#</option></select></label>
            <label>مجموع التغطية 1+2 *<input name="cover12" placeholder="0-8 أو #" maxlength="1" required (blur)="formatField($event)"></label>
            <label>مجموع التغطية 1+2+3 *<input name="cover123" placeholder="0-8 أو #" maxlength="1" required (blur)="formatField($event)"></label>
          </div>
          <div class="cloud-grid">
            @for (n of cloudLayers; track n) {
              <div class="cloud-layer"><strong>{{ cloudLayerTitle(n) }}</strong><div class="grid">
                <label>كمية السحب<input [name]="'cloud' + n + 'Amount'" maxlength="1" placeholder="0-8" (blur)="formatField($event)"></label>
                <label *ngIf="n !== 4">نوع السحب<input [name]="'cloud' + n + 'Type'" maxlength="50" placeholder="مثال: Cs1, Ac, Cu" (blur)="formatField($event)"></label>
                <label *ngIf="n !== 4">ارتفاع السحب (عشرات الأمتار)<input [name]="'cloud' + n + 'Height'" maxlength="3" placeholder="مثال: 120" (blur)="formatField($event)"></label>
              </div></div>
            }
          </div>
        </section>

        <section class="panel">
          <label>مقطع السينوب إلى مطار دمشق الدولي synop<textarea name="observerNotes" rows="3" placeholder="المكان المخصص لإدخال مقطع السينوب برجى الحذر أثناء الإدخال "></textarea></label>
          <label class="agreement"><input type="checkbox" name="responsibilityAgreement" required> أقر بأنني قمت بإدخال جميع البيانات بدقة وأتحمل المسؤولية الكاملة عن صحة المعلومات المقدمة.</label>
        </section>

        <div class="actions"><button class="primary" type="submit" [disabled]="saving || !selectedStationId"><i class="fa-solid fa-paper-plane"></i> {{ saving ? "جارٍ الإرسال..." : "إرسال النشرة للمراجعة" }}</button><button class="secondary" type="reset" (click)="resetMessage()">مسح الحقول</button></div>
      </form>

      <div class="validation-box error-box" *ngIf="issues.length"><strong><i class="fa-solid fa-triangle-exclamation"></i> يرجى تصحيح الملاحظات التالية</strong><ul><li *ngFor="let issue of issues">{{ issue }}</li></ul></div>
      <div class="validation-box success-box" *ngIf="message" role="status"><i class="fa-solid fa-circle-check"></i> {{ message }}</div>

      <section class="panel preview-panel" *ngIf="previews.length">
        <h2><i class="fa-solid fa-inbox"></i> سجل الإرسال المؤكد</h2>
        <article class="preview-row" *ngFor="let item of previews">
          <div><strong>{{ item.reference }}</strong><p>{{ item.station }} · {{ item.date }} · {{ item.hour }} UTC</p></div>
          <span class="status" [class.submitted]="item.status === 'submitted'">{{ item.status === 'draft' ? 'مسودة' : 'بانتظار المراجعة' }}</span>
          
        </article>
      </section>
      <p class="footnote">قواعد الحقول المشروطة والتنسيقات هنا مبنية على نموذج الرصد الساعي الأصلي. يلزم إكمال المطابقة والاختبار مع واجهة API قبل استخدامها تشغيلياً.</p>
    </div>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,sans-serif;color:#2c3e50}.page{max-width:1500px;margin:auto}.page-head{display:flex;align-items:center;gap:18px;background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;padding:24px 28px;border-radius:16px;margin-bottom:18px;box-shadow:0 8px 24px #667eea30}.head-icon{width:62px;height:62px;border-radius:15px;background:#ffffff25;display:grid;place-items:center;font-size:30px}.page-head h1{margin:0 0 5px;font-size:27px}.page-head p{margin:0;opacity:.9}.preview-tag{margin-right:auto;background:#fff3cd;color:#856404;padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700;white-space:nowrap}.demo-warning{display:flex;gap:12px;align-items:flex-start;padding:13px 16px;margin-bottom:20px;border-radius:9px;background:#eaf4fb;border-right:4px solid #3498db;color:#245575}.demo-warning>i{font-size:19px}.demo-warning div{display:grid;gap:4px}.demo-warning span{font-size:12px}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:22px}.stats article{background:#fff;border:1px solid #e8edf1;border-radius:12px;padding:15px 18px;display:grid;grid-template-columns:32px 1fr;align-items:center;gap:3px 10px}.stats i{grid-row:span 2;color:#3498db;font-size:20px}.stats span{font-size:12px;color:#82909a}.stats strong{font-size:14px}.panel{background:#fff;border:1px solid #e5eaee;border-radius:14px;padding:22px;margin-bottom:18px;box-shadow:0 5px 18px #2638490a}.panel h2{font-size:18px;margin:0 0 20px;padding-bottom:12px;border-bottom:2px solid #edf1f4;color:#34495e}.panel h2 i{color:#3498db;margin-left:9px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.grid label{display:flex;flex-direction:column;gap:7px;font-size:13px;font-weight:700;color:#536471}.grid input,.grid select,.panel textarea{width:100%;box-sizing:border-box;border:1px solid #d9e1e7;border-radius:8px;padding:11px 12px;background:#fbfcfd;color:#2c3e50;font:inherit;font-weight:400;outline:none}.grid input:focus,.grid select:focus,.panel textarea:focus{border-color:#3498db;box-shadow:0 0 0 3px #3498db20}.grid small{font-size:10px;color:#84919a;font-weight:400}.required-field:after{content:'مطلوب لهذه الساعة';font-size:10px;color:#b66a16}.conditional-note{font-size:12px;color:#805d19;background:#fff8e9;padding:9px 12px;border-radius:7px;margin-bottom:14px}.cloud-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:16px}.cloud-layer{padding:14px;border:1px solid #e8edf1;border-radius:9px;background:#fafcfd}.cloud-layer>strong{display:block;margin-bottom:12px;color:#2980b9}.agreement{display:flex;align-items:center;gap:9px;margin-top:17px;padding:12px;background:#f4f8fb;border-radius:8px;font-size:13px}.actions{display:flex;gap:10px}.actions button,.send-btn{border:0;border-radius:9px;padding:12px 20px;font:inherit;font-weight:700;cursor:pointer}.primary,.send-btn{background:#2980b9;color:#fff}.secondary{background:#ecf0f1;color:#34495e}.validation-box{margin-top:16px;padding:14px 16px;border-radius:9px;font-size:13px}.error-box{background:#fff0ef;border-right:4px solid #dc3545;color:#9d2929}.error-box ul{margin:8px 0 0;padding-right:20px}.success-box{background:#eaf7ef;border-right:4px solid #27ae60;color:#218348}.preview-panel{margin-top:20px}.preview-row{display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #edf0f2}.preview-row:last-child{border-bottom:0}.preview-row>div{flex:1}.preview-row p{margin:5px 0 0;color:#84919a;font-size:12px}.status{padding:5px 10px;border-radius:20px;background:#edf0f2;color:#59636b;font-size:11px}.status.submitted{background:#fff3cd;color:#946200}.footnote{font-size:12px;color:#8a969e;margin-top:18px}@media(max-width:850px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.stats{grid-template-columns:1fr}.grid,.cloud-grid{grid-template-columns:1fr}.page-head{padding:18px;flex-wrap:wrap}.page-head h1{font-size:22px}.head-icon{width:50px;height:50px}.preview-tag{margin-right:0}.panel{padding:16px}.actions{flex-direction:column}.preview-row{align-items:flex-start;flex-wrap:wrap}}
  `]
})
export class HourlyReportsComponent implements OnDestroy {
  readonly api = inject(ObservationApiService);
  stations: StationDirectoryItem[] = [];
  stationsLoading = false;
  stationsError = '';
  selectedStationId = '';
  saving = false;
  private readonly offlineQueue = new DailyOfflineQueue();
  private readonly syncOwner = 'hourly-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  private syncChannel?: BroadcastChannel;
  private readonly handleSyncAvailable = (event: MessageEvent<{ owner?: string; type?: string; retry?: boolean }>): void => { if (event.data?.owner === this.syncOwner) return; if (event.data?.type === 'network-online') { this.isOnline = true; void this.flushHourlyQueue(); return; } if (event.data?.type === 'lease-released' && event.data.retry !== false && this.isOnline) void this.flushHourlyQueue(); };
  private readonly handleOnline = (): void => { this.isOnline = true; this.syncChannel?.postMessage({ type: 'network-online', owner: this.syncOwner, at: Date.now() }); void this.flushHourlyQueue(); };
  private readonly handleOffline = (): void => { this.isOnline = false; };
  isOnline = typeof navigator === 'undefined' ? true : navigator.onLine;
  pendingOfflineCount = 0;
  pendingOfflineItems: DailyOfflineSubmission[] = [];
  blockedOfflineCount = 0;
  blockedOfflineItems: DailyOfflineSubmission[] = [];
  syncing = false;
  private syncRequested = false;

  constructor() {
    void this.loadStations();
    void this.refreshOfflineCount();
    if (typeof window !== 'undefined') {
      if (typeof BroadcastChannel !== 'undefined') {
        this.syncChannel = new BroadcastChannel('metra-offline-outbox-sync');
        this.syncChannel.addEventListener('message', this.handleSyncAvailable);
      }
      window.addEventListener('online', this.handleOnline);
      window.addEventListener('offline', this.handleOffline);
      if (navigator.onLine) void this.flushHourlyQueue();
    }
  }

  ngOnDestroy(): void {
    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.handleOnline);
      window.removeEventListener('offline', this.handleOffline);
    }
    this.syncChannel?.removeEventListener('message', this.handleSyncAvailable);
    this.syncChannel?.close();
  }

  private async refreshOfflineCount(): Promise<void> {
    try { const items = (await this.offlineQueue.list()).filter(x => x.observationType === 'hourly'); this.pendingOfflineItems = items.filter(x => x.state === 'pending' || x.state === 'blocked'); this.pendingOfflineCount = items.filter(x => x.state === 'pending').length; this.blockedOfflineItems = items.filter(x => x.state === 'blocked'); this.blockedOfflineCount = this.blockedOfflineItems.length; } catch { /* local storage unavailable */ }
  }

  restoreOfflineSubmission(item: DailyOfflineSubmission, form: HTMLFormElement): void {
    const payload = item.payload ?? {};
    const values = payload['values'] && typeof payload['values'] === 'object'
      ? payload['values'] as Record<string, unknown> : {};
    this.selectedStationId = item.stationId;
    this.selectedHour = item.reportType;
    const setValue = (name: string, value: unknown): void => {
      const field = form.elements.namedItem(name) as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | null;
      if (field && typeof value === 'string') field.value = value;
    };
    setValue('stationId', item.stationId);
    setValue('observationDate', item.reportDate);
    setValue('utcTime', item.reportType);
    for (const [name, value] of Object.entries(values)) setValue(name, value);
    const agreement = form.elements.namedItem('responsibilityAgreement') as HTMLInputElement | null;
    if (agreement) agreement.checked = values['responsibilityAgreement'] === 'on' || values['responsibilityAgreement'] === true;
    this.issues = [];
    this.message = 'أُعيد فتح النشرة الساعية المحفوظة محلياً؛ ما زالت في قائمة الانتظار ولم تُرسل بعد.';
  }

  async retryBlockedOffline(): Promise<void> {
    const items = await this.offlineQueue.list();
    for (const item of items) if (item.observationType === 'hourly' && item.state === 'blocked') {
      await this.offlineQueue.update({ ...item, state: 'pending', lastError: undefined });
    }
    await this.refreshOfflineCount();
    if (this.isOnline && this.apiReady) await this.flushHourlyQueue();
  }

  private async flushHourlyQueue(): Promise<void> {
    if (this.syncing) { this.syncRequested = true; return; }
    if (!this.isOnline || !this.apiReady) return;
    this.syncing = true;
    let leaseAcquired = false;
    let stoppedForTransientFailure = false;
    try {
      leaseAcquired = await this.offlineQueue.acquireSyncLease(this.syncOwner);
      if (!leaseAcquired) return;
      // Re-read the shared outbox after each item so both report types
      // are drained even when another tab enqueues during synchronization.
      while (this.isOnline) {
        const item = (await this.offlineQueue.list()).find(candidate => candidate.state === 'pending');
        if (!item) break;
        if (!(await this.offlineQueue.renewSyncLease(this.syncOwner))) break;
        try {
          const result = await this.api.submitObservation(item.stationId, { idempotencyKey: item.idempotencyKey, observationType: item.observationType ?? 'daily', observedAt: item.observedAt, payload: item.payload, submit: true });
          const receipt = getConfirmedDailySubmission(result);
          if (!receipt) throw new Error('لم يصل إيصال حفظ مؤكد.');
          const id = receipt.id;
          await this.offlineQueue.remove(item.idempotencyKey);
          this.previews.unshift({reference:id,date:item.reportDate,hour:item.reportType,station:item.stationName,status:'submitted',values:{}});
        } catch (error) {
          const status = error && typeof error === 'object' && 'status' in error ? Number((error as {status:unknown}).status) : 0;
          if ([400,403,422].includes(status)) await this.offlineQueue.update({...item,state:'blocked',lastError:getSubmissionErrorMessage(error,'رفض الخادم النشرة؛ راجع البيانات أو الصلاحيات.')});
          else {
            await this.offlineQueue.update({...item,state:'pending',attempts:item.attempts+1,lastError:getSubmissionErrorMessage(error,'تعذر الاتصال بالخادم.')});
            stoppedForTransientFailure = true;
            break;
          }
        }
      }
    } finally {
      if (leaseAcquired) {
        try {
          await this.offlineQueue.releaseSyncLease(this.syncOwner);
          this.syncChannel?.postMessage({ type: 'lease-released', owner: this.syncOwner, at: Date.now(), retry: !stoppedForTransientFailure });
        } catch { /* lease expires automatically */ }
      }
      this.syncing = false;
      await this.refreshOfflineCount();
      const pendingRemain = (await this.offlineQueue.list()).some(item => item.state === 'pending');
      if (this.isOnline && this.apiReady && !stoppedForTransientFailure &&
          (this.syncRequested || pendingRemain)) {
        this.syncRequested = false;
        // When a competing tab owns the lease, rely on its explicit release
        // message. A transient failure releases the lease with retry=false,
        // preventing another tab from immediately repeating the failed POST.
        if (leaseAcquired || !this.syncChannel) {
          window.setTimeout(() => void this.flushHourlyQueue(), leaseAcquired ? 150 : 500);
        }
      }
    }
  }

  get apiReady(): boolean { return this.api.isConfigured; }
  setStation(value: string): void { this.selectedStationId = value; }

  private async loadStations(): Promise<void> {
    try { const cached = await this.offlineQueue.getCachedStations<StationDirectoryItem>(); if (cached.length) this.stations = cached; } catch { /* cache unavailable */ }
    if (!this.apiReady || !this.isOnline) {
      this.stationsError = 'الاتصال الفعلي غير مهيأ: يلزم ضبط API وSupabase.';
      return;
    }
    this.stationsLoading = true;
    try {
      this.stations = await this.api.getAllStations();
      await this.offlineQueue.cacheStations(this.stations);
      if (!this.stations.length) this.stationsError = 'لا توجد محطات تشغيلية متاحة في الدليل.';
    } catch {
      this.stationsError = 'تعذر تحميل المحطات؛ تحقق من الدخول واتصال API وصلاحيات الدليل.';
    } finally {
      this.stationsLoading = false;
    }
  }

  readonly today = this.localDate(new Date());
  private localDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }


  readonly now = new Intl.DateTimeFormat('ar', { hour: '2-digit', minute: '2-digit' }).format(new Date());
  readonly hours = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0'));
  readonly cloudValues = ['0','1','2','3','4','5','6','7','8'];
  readonly cloudLayers = [1,2,3,4];
  selectedHour = '';
  issues: string[] = [];
  message = '';
  previews: HourlyPreview[] = [];
  private nextReference = 1;

  get isSynoptic(): boolean {
    return ['00','03','06','09','12','15','18','21'].includes(this.selectedHour);
  }

  get isPrecipitationHour(): boolean {
    return ['00','06','12','18'].includes(this.selectedHour);
  }

  cloudLayerTitle(layer: number): string {
    return ['الطبقة الأولى', 'الطبقة الثانية', 'الطبقة الثالثة', 'الطبقة الرابعة'][layer - 1] ?? '';
  }

  setHour(value: string): void {
    this.selectedHour = value;
    this.issues = [];
    this.message = '';
  }

  resetMessage(): void {
    this.issues = [];
    this.message = '';
    this.selectedHour = '';
    this.selectedStationId = '';
  }

  formatField(event: FocusEvent): void {
    const field = event.target as HTMLInputElement;
    if (!field || field.type === 'date' || field.type === 'checkbox') return;
    let value = field.value.trim();
    if (!value || value === '#') return;
    const digits = (input: string) => input.replace(/[^0-9]/g, '');
    const decimal = (input: string, width: number) => {
      const parts = input.split('.');
      const whole = digits(parts[0]).slice(0, width).padStart(width, '0');
      const fraction = digits(parts[1] ?? '').slice(0, 1) || '0';
      return whole + '.' + fraction;
    };

    switch (field.name) {
      case 'dryTemp':
      case 'wetTemp':
      case 'dewPoint': {
        const sign = value.startsWith('-') ? '-' : '+';
        const raw = value.replace(/^[+-]/, '');
        field.value = sign + decimal(raw, 2);
        break;
      }
      case 'stationPressure':
      case 'seaLevelPressure':
        field.value = decimal(value, 4);
        break;
      case 'vaporPressure':
      case 'vaporPressureDiff':
        field.value = decimal(value, 2);
        break;
      case 'pressureSlope': {
        const raw = digits(value).slice(0, 3);
        field.value = raw.length > 1
          ? raw.slice(0, -1) + '.' + raw.slice(-1)
          : (raw || '0') + '.0';
        break;
      }
      case 'precipitationAmount':
        field.value = decimal(value, 3);
        break;
      case 'relativeHumidity':
        field.value = digits(value).slice(0, 3).padStart(3, '0');
        break;
      case 'windDirection':
      case 'avgWindDirection':
        field.value = digits(value).slice(0, 2).padStart(2, '0');
        break;
      case 'windSpeed':
      case 'avgWindSpeed':
      case 'currentWeather':
        field.value = digits(value).slice(0, 2).padStart(2, '0');
        break;
      case 'visibility':
        field.value = digits(value).slice(0, 3).padStart(3, '0');
        break;
      case 'pastWeather':
        field.value = digits(value).slice(0, 1);
        break;
      case 'cloud1Height':
      case 'cloud2Height':
      case 'cloud3Height':
        field.value = digits(value).slice(0, 3).padStart(3, '0');
        break;
      default:
        break;
    }
  }

  async submit(event: Event, form: HTMLFormElement): Promise<void> {
    event.preventDefault();
    this.issues = [];
    this.message = '';
    if (this.saving) return;
    if (!this.selectedStationId) { this.issues = ['اختر محطة من دليل المحطات قبل الإرسال.']; return; }
    if (!form.reportValidity()) return;

    const formData = new FormData(form);
    const values: Record<string, string> = {};
    formData.forEach((value, key) => {
      if (typeof value === 'string') values[key] = value.trim();
    });

    const required = ['dryTemp','wetTemp','stationPressure','seaLevelPressure','windDirection','windSpeed','visibility','totalCloudCover','relativeHumidity','dewPoint','cover12','cover123'];
    if (this.isSynoptic) required.push('pressureSlope','pressureShape','pastWeather');
    if (this.isPrecipitationHour) required.push('precipitationAmount');

    for (const key of required) {
      const value = values[key] ?? '';
      if (!value) this.issues.push(this.label(key) + ': هذا الحقل مطلوب في ساعة الرصد المختارة.');
    }

    const rules: Record<string, { pattern: RegExp; min: number; max: number; label: string }> = {
      dryTemp:{pattern:/^[+-]\d{2}\.\d$/,min:-20,max:50,label:'الحرارة الجافة'},
      wetTemp:{pattern:/^[+-]\d{2}\.\d$/,min:-20,max:50,label:'الحرارة الرطبة'},
      dewPoint:{pattern:/^[+-]\d{2}\.\d$/,min:-20,max:50,label:'نقطة الندى'},
      stationPressure:{pattern:/^\d{4}\.\d$/,min:850,max:1050,label:'ضغط المحطة'},
      seaLevelPressure:{pattern:/^\d{4}\.\d$/,min:0,max:1050,label:'ضغط سطح البحر'},
      relativeHumidity:{pattern:/^\d{3}$/,min:1,max:100,label:'الرطوبة النسبية'},
      vaporPressure:{pattern:/^\d{2}\.\d$/,min:0,max:99,label:'ضغط البخار'},
      vaporPressureDiff:{pattern:/^\d{2}\.\d$/,min:0,max:99,label:'فرق ضغط البخار'},
      windDirection:{pattern:/^\d{2}$/,min:0,max:36,label:'اتجاه الرياح'},
      avgWindDirection:{pattern:/^\d{2}$/,min:0,max:36,label:'متوسط الاتجاه (درجة)'},
      windSpeed:{pattern:/^\d{2}$/,min:0,max:99,label:'سرعة الرياح'},
      avgWindSpeed:{pattern:/^\d{2}$/,min:0,max:99,label:'متوسط السرعة (م/ثا)'},
      visibility:{pattern:/^\d{3}$/,min:0,max:200,label:'مدى الرؤية'},
      currentWeather:{pattern:/^\d{2}$/,min:0,max:99,label:'الطقس الحاضر (الكود)'},
      pastWeather:{pattern:/^\d$/,min:0,max:9,label:'الطقس السابق'},
      pressureSlope:{pattern:/^\d{1,2}\.\d$/,min:0,max:99,label:'ميل الضغط'},
      pressureShape:{pattern:/^[0-8]$/,min:0,max:8,label:'شكل الضغط'},
      precipitationAmount:{pattern:/^\d{3}\.\d$/,min:0,max:999.9,label:'كمية الهطول'},
      cover12:{pattern:/^[0-8]$/,min:0,max:8,label:'تغطية الطبقتين'},
      cover123:{pattern:/^[0-8]$/,min:0,max:8,label:'تغطية الطبقات الثلاث'}
    };

    for (const [key, rule] of Object.entries(rules)) {
      const value = values[key] ?? '';
      if (!value || value === '#') continue;
      const numeric = Number(value);
      if (!rule.pattern.test(value) || !Number.isFinite(numeric) || numeric < rule.min || numeric > rule.max) {
        this.issues.push(rule.label + ': التنسيق أو القيمة خارج المجال المسموح.');
      }
    }

    for (const key of ['cloud1Amount','cloud2Amount','cloud3Amount','cloud4Amount']) {
      const value = values[key] ?? '';
      if (value && value !== '#' && !/^[0-8]$/.test(value)) this.issues.push(this.label(key) + ': أدخل رقماً من 0 إلى 8 أو #.');
    }
    for (const key of ['cloud1Height','cloud2Height','cloud3Height']) {
      const value = values[key] ?? '';
      if (value && value !== '#' && !/^\d{1,3}$/.test(value)) this.issues.push(this.label(key) + ': أدخل ارتفاعاً من 0 إلى 999 أو #.');
    }

    const dry = values['dryTemp'];
    const wet = values['wetTemp'];
    if (dry && wet && dry !== '#' && wet !== '#' && Number(dry) < Number(wet)) {
      this.issues.push('يجب أن تكون درجة الحرارة الجافة أكبر من أو تساوي درجة الحرارة الرطبة.');
    }

    if (this.issues.length) return;

    const station = this.stations.find(item => item.id === this.selectedStationId);
    if (!station) { this.issues = ['المحطة المختارة غير موجودة في دليل المحطات الحالي.']; return; }
    const payloadValues = { ...values };
    delete payloadValues['stationId'];
    const hour = values['utcTime'] ?? this.selectedHour;
    const payload = { stationName: station.name_ar, utcHour: hour, values: payloadValues };
    const reportDate = values['observationDate'] ?? this.today;
    const observedAt = new Date(reportDate + 'T' + hour + ':00:00.000Z').toISOString();
    let idempotencyKey: string;
    try { idempotencyKey = createIdempotencyKey(); }
    catch (error) { this.message = error instanceof Error ? error.message : 'تعذر إنشاء مفتاح إرسال آمن.'; return; }
    this.saving = true;
    try {
      if (!this.isOnline || !this.apiReady) {
        await this.offlineQueue.enqueue({idempotencyKey,observationType:'hourly',stationId:this.selectedStationId,stationName:station.name_ar,reportDate,reportType:hour,observedAt,payload,createdAt:new Date().toISOString(),attempts:0,state:'pending'});
        await this.refreshOfflineCount();
        this.message = this.isOnline
          ? 'حُفظت النشرة الساعية محلياً؛ ستُرسل بعد تهيئة API وتوفر الاتصال، ولم تُعتمد بعد.'
          : 'حُفظت النشرة الساعية محلياً وستُرسل تلقائياً عند عودة الشبكة؛ لم تُعتمد بعد.';
        return;
      }
      const result = await this.api.submitObservation(this.selectedStationId, {
        idempotencyKey,
        observationType: 'hourly',
        observedAt,
        payload,
        submit: true
      });
      const receipt = getConfirmedDailySubmission(result);
      if (!receipt) throw new Error('لم يصل إيصال حفظ مؤكد من الخادم؛ لم يتم اعتماد النشرة.');
      const id = receipt.id;
      this.previews.unshift({
        reference: id,
        date: values['observationDate'] ?? this.today,
        hour,
        station: station.name_ar,
        status: 'submitted',
        values
      });
      this.message = 'تم حفظ النشرة الساعية وإرسالها للمراجعة. رقم النشرة: ' + id;
      form.reset();
      this.selectedHour = '';
      this.selectedStationId = '';
    } catch (error) {
      const status = error && typeof error === 'object' && 'status' in error ? Number((error as {status:unknown}).status) : 0;
      if (!this.isOnline || status === 0) {
        await this.offlineQueue.enqueue({idempotencyKey,observationType:'hourly',stationId:this.selectedStationId,stationName:station.name_ar,reportDate,reportType:hour,observedAt,payload,createdAt:new Date().toISOString(),attempts:1,state:'pending',lastError:'انقطع الاتصال أو لم يصل تأكيد الخادم.'});
        await this.refreshOfflineCount();
        this.message = 'لم يصل تأكيد الخادم؛ حُفظت النشرة في قائمة الانتظار وستعاد المحاولة تلقائياً.';
      } else {
        this.message = error instanceof Error ? 'لم يتم تأكيد الحفظ: ' + error.message : 'تعذر إرسال النشرة إلى الخادم.';
      }
    } finally {
      this.saving = false;
    }
  }

  private label(key: string): string {
    const labels: Record<string, string> = {
      dryTemp:'الحرارة الجافة',wetTemp:'الحرارة الرطبة',stationPressure:'ضغط المحطة',
      seaLevelPressure:'ضغط سطح البحر',windDirection:'اتجاه الرياح',windSpeed:'سرعة الرياح',
      visibility:'الرؤية',totalCloudCover:'الغطاء السحابي',relativeHumidity:'الرطوبة النسبية',
      dewPoint:'نقطة الندى',cover12:'تغطية الطبقتين',cover123:'تغطية الطبقات الثلاث',
      pressureSlope:'ميل الضغط',pressureShape:'شكل الضغط',pastWeather:'الطقس السابق',
      precipitationAmount:'كمية الهطول',cloud1Amount:'كمية السحب الأولى',cloud2Amount:'كمية السحب الثانية',
      cloud3Amount:'كمية السحب الثالثة',cloud4Amount:'كمية السحب الرابعة',
      cloud1Height:'ارتفاع السحب الأولى',cloud2Height:'ارتفاع السحب الثانية',cloud3Height:'ارتفاع السحب الثالثة'
    };
    return labels[key] ?? key;
  }
}