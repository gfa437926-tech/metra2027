import { CommonModule } from '@angular/common';
import { Component, OnDestroy } from '@angular/core';
import { FormsModule } from '@angular/forms';

interface LocalPhenomenon {
  id: string;
  phenomenon_type: string;
  phenomenon_date: string;
  start_time: string;
  end_time: string;
  start_time_local: string;
  end_time_local: string;
  phenomenon_duration: string;
  phenomenon_status: 'نشطة' | 'منتهية';
  general_notes: string;
  created_at: string;
}

@Component({
  standalone: true,
  selector: 'metra-phenomena-input',
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page" id="mainContainer" dir="rtl">
      <header class="topbar">
        <div class="brand"><span class="brand-icon"><i class="fa-solid fa-cloud-sun-rain"></i></span><div><h1>نظام تسجيل الظواهر الجوية</h1><p>تسجيل بدء وانتهاء الظواهر الجوية ومتابعتها في الوقت الفعلي</p></div></div>
        <div class="header-actions"><span class="preview-badge"><i class="fa-solid fa-flask"></i> معاينة محلية غير محفوظة</span><span>{{ currentDate }} · {{ currentTime }}</span><button type="button" (click)="resetLocalSession()">إعادة ضبط المعاينة</button></div>
      </header>

      <section class="warning">
        <i class="fa-solid fa-triangle-exclamation"></i>
        <div><strong>تنبيه: اتصال قاعدة البيانات غير مفعّل</strong><p>يمكن تجربة المؤقت والتحكم بالظاهرة في هذه الصفحة، لكن السجلات تبقى مؤقتة داخل الصفحة ولا تُرسل إلى قاعدة البيانات أو تُشارك مع المحطة. الوقت المحلي المعروض هو وقت الجهاز. يلزم تحديد المنطقة الزمنية الرسمية للمحطة وربط API وتسجيل دخول موثّق قبل تفعيل التسجيل الفعلي.</p></div>
      </section>

      <section class="stats">
        <article><strong id="totalPhenomena">{{ phenomena.length }}</strong><span>إجمالي الظواهر</span></article>
        <article><strong id="activePhenomena">{{ activeCount }}</strong><span>ظواهر نشطة</span></article>
        <article><strong id="myActivePhenomena">{{ myActiveCount }}</strong><span>ظواهري النشطة</span></article>
        <article><strong id="todayPhenomena">{{ todayCount }}</strong><span>اليوم</span></article>
      </section>

      <section class="panel">
        <h2><i class="fa-solid fa-sliders"></i> التحكم بالظاهرة الحالية</h2>
        <div class="status" [class.running]="activePhenomenon" [class.paused]="isPaused">
          <div><h3 id="currentStatusText">{{ statusText }}</h3><div class="status-detail-row"><span id="statusIndicator" class="status-indicator" [class.active]="!!activePhenomenon" [class.paused]="isPaused"></span><p id="statusDetails">{{ statusDetails }}</p></div></div>
          <div id="durationContainer" class="duration" *ngIf="activePhenomenon"><i class="fa-solid fa-hourglass-half"></i> <span id="currentDuration">{{ currentDuration }}</span></div>
        </div>

        <div class="field">
          <label for="phenomenonType"><i class="fa-solid fa-cloud-showers-heavy"></i> نوع الظاهرة الجوية</label>
          <div class="input-row"><input id="phenomenonType" [(ngModel)]="phenomenonType" [disabled]="!!activePhenomenon" placeholder="اكتب وصف الظاهرة (مثال: مطر خفيف، عاصفة رعدية، ضباب...)" (keyup.enter)="startPhenomenon()"><button id="suggestBtn" type="button" class="outline" (click)="showSuggestions = !showSuggestions"><i class="fa-solid fa-lightbulb"></i> اقتراحات</button></div>
          <div id="suggestions" class="suggestions" *ngIf="showSuggestions"><button type="button" *ngFor="let suggestion of suggestions" (click)="chooseSuggestion(suggestion)">{{ suggestion }}</button></div>
        </div>

        <div class="controls">
          <div><button id="startBtn" class="start" type="button" (click)="startPhenomenon()" [disabled]="!!activePhenomenon || !phenomenonType.trim()"><i class="fa-solid fa-play-circle"></i> بدء الظاهرة</button><small>بدء معاينة تسجيل الظاهرة محلياً</small></div>
          <div><button id="pauseBtn" class="pause" type="button" (click)="togglePause()" [disabled]="!activePhenomenon"><i [class]="isPaused ? 'fa-solid fa-play-circle' : 'fa-solid fa-pause-circle'"></i> {{ isPaused ? 'استئناف' : 'إيقاف مؤقت' }}</button><small>توقف مؤقت في التسجيل</small></div>
          <div><button id="stopBtn" class="stop" type="button" (click)="stopPhenomenon()" [disabled]="!activePhenomenon"><i class="fa-solid fa-stop-circle"></i> إنهاء الظاهرة</button><small>تسجيل وقت انتهاء الظاهرة في المعاينة</small></div>
        </div>

        <div class="times">
          <input type="hidden" id="startTime" name="startTime" [value]="activePhenomenon?.start_time || lastEnded?.start_time || ''">
          <input type="hidden" id="endTime" name="endTime" [value]="activePhenomenon?.end_time || lastEnded?.end_time || ''">
          <div><label><i class="fa-solid fa-play"></i> وقت البدء (UTC)</label><strong id="startTimeDisplay">{{ activePhenomenon?.start_time || lastEnded?.start_time || '--:--:--' }}</strong></div>
          <div><label><i class="fa-solid fa-stop"></i> وقت الانتهاء (UTC)</label><strong id="endTimeDisplay">{{ activePhenomenon?.end_time || lastEnded?.end_time || '--:--:--' }}</strong></div>
          <div><label><i class="fa-solid fa-play"></i> وقت البدء (محلي)</label><strong id="startTimeLocalDisplay">{{ activePhenomenon?.start_time_local || lastEnded?.start_time_local || '--:--:--' }}</strong></div>
          <div><label><i class="fa-solid fa-stop"></i> وقت الانتهاء (محلي)</label><strong id="endTimeLocalDisplay">{{ activePhenomenon?.end_time_local || lastEnded?.end_time_local || '--:--:--' }}</strong></div>
        </div>

        <div class="field"><label for="notes"><i class="fa-solid fa-comment"></i> ملاحظات إضافية</label><textarea id="notes" rows="3" [(ngModel)]="notes" placeholder="ملاحظات حول الظاهرة، شدتها، تأثيرها..."></textarea></div>
        <p class="inline-notice" *ngIf="message">{{ message }}</p>
      </section>

      <section class="panel">
        <div class="panel-heading"><h2><i class="fa-solid fa-history"></i> سجل الظواهر الجوية</h2><div><small>آخر تحديث: <span id="lastUpdateTime">{{ lastUpdateTime }}</span></small><button id="refreshBtn" type="button" class="outline" (click)="refreshLocalView()"><i class="fa-solid fa-redo"></i> تحديث</button></div></div>
        <div class="filters">
          <button type="button" *ngFor="let item of filters" [class.selected]="activeFilter === item.value" (click)="setFilter(item.value)">{{ item.label }}</button>
        </div>
        <div id="filterInfo" class="filter-info"><i class="fa-solid fa-filter"></i> <span id="filterInfoText">{{ filterInfo }}</span></div>
        <div id="phenomenaList" class="record-list" *ngIf="visiblePhenomena.length; else empty">
          <article class="record" *ngFor="let item of visiblePhenomena">
            <div class="record-head"><div><h3><i class="fa-solid fa-cloud-rain"></i> {{ item.phenomenon_type }}</h3><span class="status-pill" [class.done]="item.phenomenon_status === 'منتهية'">{{ item.phenomenon_status }}</span><small>{{ item.phenomenon_date }}</small></div><strong>{{ item.phenomenon_duration || currentDurationFor(item) }}</strong></div>
            <div class="record-times"><span>وقت البدء (محلي): {{ item.start_time_local }}</span><span>وقت البدء (UTC): {{ item.start_time }}</span><span>وقت الانتهاء (محلي): {{ item.end_time_local || '--:--:--' }}</span><span>وقت الانتهاء (UTC): {{ item.end_time || '--:--:--' }}</span></div>
            <p *ngIf="item.general_notes">{{ item.general_notes }}</p>
            <small class="local-label">سجل معاينة محلي — غير محفوظ في قاعدة البيانات</small>
          </article>
        </div>
        <ng-template #empty><div id="emptyState" class="empty"><i class="fa-solid fa-cloud"></i><h3>لا توجد ظواهر مسجلة في محطتك</h3><p>لا توجد سجلات في معاينة الجلسة الحالية. بعد ربط مصدر البيانات ستظهر ظواهر المحطة هنا.</p><button id="startFirstBtn" type="button" (click)="focusPhenomenonType()">ابدأ تسجيل أول ظاهرة</button></div></ng-template>
      </section>

      <section id="stationStats" class="station-stats"><h2><i class="fa-solid fa-chart-pie"></i> إحصائيات تقارير المحطة اليوم</h2><p>إحصائيات المحطة غير متاحة حتى ربط مصدر البيانات المعتمد.</p><div id="statsGrid" class="stats-grid"><span>التقارير الساعية: —</span><span>درجات حرارة التربة: —</span><span>التقارير الزراعية: —</span><span>التقارير المناخية: —</span><span>التقارير اليومية: —</span><span>تقارير هطول الأمطار: —</span></div></section>
    </div>
  `,
  styles: [`
    .page{max-width:1400px;margin:0 auto;color:#2c3e50;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}.topbar{background:linear-gradient(135deg,#3498db,#2c3e50);color:#fff;padding:18px 22px;border-radius:10px;margin-bottom:18px;display:flex;justify-content:space-between;align-items:center;gap:15px;flex-wrap:wrap}.brand{display:flex;align-items:center;gap:13px}.brand-icon{width:52px;height:52px;background:#fff;color:#3498db;border-radius:50%;display:grid;place-items:center;font-size:25px}.brand h1{font-size:1.25rem;margin:0}.brand p{margin:4px 0 0;opacity:.85}.header-actions{display:flex;align-items:center;gap:12px;flex-wrap:wrap;font-size:.85rem}.header-actions button{border:1px solid #ffffff80;background:transparent;color:#fff;border-radius:6px;padding:7px 10px}.preview-badge{background:#fff3cd;color:#795600;border-radius:20px;padding:6px 11px;font-weight:700}.warning{display:flex;gap:14px;background:#fff8e9;border-right:5px solid #f39c12;border-radius:8px;padding:14px 17px;margin-bottom:18px;color:#75520e}.warning>i{font-size:22px;padding-top:3px}.warning p{margin:5px 0 0;line-height:1.7}.stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:18px}.stats article{background:#fff;border-radius:9px;box-shadow:0 3px 10px #0000000d;padding:16px;text-align:center;display:grid;gap:5px}.stats strong{font-size:1.8rem;color:#2980b9}.stats span{font-size:.9rem;color:#71808a}.panel{background:#fff;border-radius:10px;padding:22px;margin-bottom:20px;box-shadow:0 4px 12px #0000000c}.panel h2,.station-stats h2{font-size:1.2rem;margin:0 0 18px;color:#2c3e50}.panel h2 i,.station-stats h2 i{color:#3498db;margin-left:8px}.status{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:15px 17px;background:#f8f9fa;border-radius:8px;border-right:4px solid #95a5a6;margin-bottom:22px}.status.running{border-color:#27ae60}.status.paused{border-color:#f39c12}.status-detail-row{display:flex;align-items:center;gap:9px}.status-detail-row p{margin:0}.status-indicator{display:inline-block;width:11px;height:11px;flex:0 0 11px;border-radius:50%;background:#95a5a6}.status-indicator.active{background:#27ae60;animation:pulse 2s infinite}.status-indicator.paused{background:#f39c12;animation:none}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.45}}.status h3{font-size:1.05rem;margin:0 0 5px}.status p{margin:0;color:#7f8c8d;font-size:.88rem}.duration{font-family:monospace;font-size:1.25rem;font-weight:700;background:#eaf5fc;padding:8px 13px;border-radius:7px}.field{margin:18px 0}.field label{display:block;font-weight:700;margin-bottom:8px}.field label i{color:#3498db;margin-left:5px}.input-row{display:flex;gap:8px}.field input,.field textarea{width:100%;box-sizing:border-box;border:1px solid #ced4da;border-radius:6px;padding:11px 13px;font:inherit;background:#fff;color:#34495e}.field input:focus,.field textarea:focus{outline:2px solid #3498db30;border-color:#3498db}.outline{border:1px solid #6c757d;color:#56616b;background:#fff;border-radius:6px;padding:9px 13px;white-space:nowrap}.suggestions{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}.suggestions button{border:0;background:#6c757d;color:white;border-radius:16px;padding:6px 12px;cursor:pointer}.controls{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.controls>div{display:grid;gap:6px}.controls button{border:0;border-radius:7px;padding:12px;color:white;font:inherit;font-weight:700;cursor:pointer}.controls button:disabled{opacity:.45;cursor:not-allowed}.start{background:#27ae60}.pause{background:#f39c12}.stop{background:#e74c3c}.controls small{text-align:center;color:#7f8c8d}.times{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin:22px 0;padding:16px;background:#f8f9fa;border-radius:8px}.times>div{display:flex;justify-content:space-between;align-items:center;gap:8px}.times label{font-size:.9rem;color:#52616b}.times label i{color:#3498db;margin-left:5px}.times strong{font-family:monospace;color:#2c3e50}.inline-notice{padding:9px 12px;background:#eef7fc;border-radius:6px;color:#2874a6}.panel-heading{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap}.panel-heading h2{margin:0}.panel-heading>div{display:flex;align-items:center;gap:10px}.panel-heading small{color:#7f8c8d}.filters{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0 12px}.filters button{background:#fff;border:1px solid #3498db;color:#2980b9;border-radius:6px;padding:8px 13px;font:inherit}.filters button.selected{background:#3498db;color:#fff}.filter-info{background:#eaf5fc;color:#2874a6;border-radius:6px;padding:10px 13px;margin-bottom:14px}.record-list{display:grid;gap:12px}.record{border:1px solid #e4e9ed;border-radius:8px;padding:15px}.record-head{display:flex;justify-content:space-between;gap:12px;align-items:center}.record-head>div{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.record h3{font-size:1rem;margin:0}.record h3 i{color:#3498db}.record-head>strong{font-family:monospace}.status-pill{background:#d5f5e3;color:#196f3d;padding:4px 10px;border-radius:16px;font-size:.8rem}.status-pill.done{background:#fadbd8;color:#922b21}.record-times{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:14px 0;font-size:.88rem;color:#56616b}.local-label{color:#9a6b17}.empty{text-align:center;padding:35px 15px;color:#7f8c8d}.empty>i{font-size:2.8rem;color:#bdc3c7}.empty h3{margin:12px 0 6px;color:#56616b}.empty button{border:0;background:#3498db;color:#fff;border-radius:6px;padding:9px 15px}.station-stats{background:#34495e;color:#fff;border-radius:10px;padding:20px}.station-stats h2{color:#fff}.station-stats h2 i{color:#5dade2}.station-stats p{color:#d5dce2}.stats-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}.stats-grid span{background:#ffffff12;border-radius:6px;padding:10px;font-size:.88rem}@media(max-width:850px){.stats{grid-template-columns:repeat(2,minmax(0,1fr))}.controls{grid-template-columns:1fr}.times{grid-template-columns:1fr}.record-times{grid-template-columns:1fr}.stats-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:560px){.panel{padding:15px}.stats{gap:8px}.stats article{padding:11px}.input-row{flex-direction:column}.header-actions{font-size:.78rem}.record-head{align-items:flex-start;flex-direction:column}}
  `]
})
export class PhenomenaInputComponent implements OnDestroy {
  readonly suggestions = ['مطر خفيف', 'عاصفة رعدية', 'رذاذ', 'ثلج', 'ضباب', 'عاصفة ترابية', 'برد', 'رياح قوية'];
  readonly filters = [
    { value: 'all', label: 'الكل' },
    { value: 'active', label: 'النشطة' },
    { value: 'ended', label: 'المنتهية' },
    { value: 'my', label: 'ظواهري' },
    { value: 'today', label: 'اليوم' }
  ];
  phenomenonType = '';
  notes = '';
  showSuggestions = false;
  phenomena: LocalPhenomenon[] = [];
  activePhenomenon: LocalPhenomenon | null = null;
  lastEnded: LocalPhenomenon | null = null;
  isPaused = false;
  currentDuration = '00:00:00';
  currentDate = '';
  currentTime = '';
  lastUpdateTime = '--:--';
  activeFilter = 'all';
  message = '';
  private startedAt = 0;
  private timer: ReturnType<typeof setInterval> | null = null;
  private clock: ReturnType<typeof setInterval> | null = null;

  constructor() {
    this.updateClock();
    this.clock = setInterval(() => this.updateClock(), 1000);
  }

  ngOnDestroy(): void {
    if (this.timer) clearInterval(this.timer);
    if (this.clock) clearInterval(this.clock);
  }

  get activeCount(): number { return this.phenomena.filter(p => p.phenomenon_status === 'نشطة').length; }
  get myActiveCount(): string { return '—'; }
  get todayCount(): number { const today = this.localDate(); return this.phenomena.filter(p => p.phenomenon_date === today).length; }
  get statusText(): string {
    if (!this.activePhenomenon) return 'لا توجد ظاهرة نشطة حالياً';
    return this.isPaused ? `تم إيقاف تسجيل الظاهرة مؤقتاً: ${this.activePhenomenon.phenomenon_type}` : `جاري تسجيل الظاهرة: ${this.activePhenomenon.phenomenon_type}`;
  }
  get statusDetails(): string {
    if (!this.activePhenomenon) return 'قم ببدء ظاهرة جديدة';
    return this.isPaused ? 'يستمر احتساب المدة أثناء الإيقاف المؤقت' : 'يتم احتساب المدة في المعاينة المحلية';
  }
  get visiblePhenomena(): LocalPhenomenon[] {
    return this.phenomena.filter(p => {
      switch (this.activeFilter) {
        case 'active': return p.phenomenon_status === 'نشطة';
        case 'ended': return p.phenomenon_status === 'منتهية';
        case 'my': return false;
        case 'today': return p.phenomenon_date === this.localDate();
        default: return true;
      }
    });
  }
  get filterInfo(): string {
    const labels: Record<string, string> = { all: 'جاري عرض جميع الظواهر في سجل المعاينة المحلي', active: 'جاري عرض الظواهر النشطة', ended: 'جاري عرض الظواهر المنتهية', my: 'يتطلب عرض ظواهري تسجيل الدخول وربط هوية المستخدم', today: 'جاري عرض ظواهر اليوم' };
    return labels[this.activeFilter];
  }

  private updateClock(): void {
    const now = new Date();
    this.currentDate = this.localDate();
    this.currentTime = now.toLocaleTimeString('en-GB', { hour12: false });
  }
  private localDate(): string {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  }
  private localTime(): string {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  }
  private formatDuration(ms: number): string {
    const seconds = Math.max(0, Math.floor(ms / 1000));
    const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60), s = seconds % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  startPhenomenon(): void {
    const type = this.phenomenonType.trim();
    if (!type || this.activePhenomenon) return;
    const now = new Date();
    const local = this.localTime();
    this.startedAt = now.getTime();
    this.isPaused = false;
    this.currentDuration = '00:00:00';
    this.activePhenomenon = {
      id: `local_${now.getTime()}`,
      phenomenon_type: type,
      phenomenon_date: this.localDate(),
      start_time: now.toISOString().slice(11, 19),
      end_time: '',
      start_time_local: local,
      end_time_local: '',
      phenomenon_duration: '',
      phenomenon_status: 'نشطة',
      general_notes: this.notes.trim(),
      created_at: now.toISOString()
    };
    this.phenomena = [this.activePhenomenon, ...this.phenomena];
    this.message = 'بدأت معاينة الظاهرة محلياً فقط؛ لم يتم إرسال أي بيانات إلى قاعدة البيانات.';
    this.showSuggestions = false;
    this.lastUpdateTime = this.currentTime;
    this.timer = setInterval(() => this.updateDuration(), 1000);
  }
  togglePause(): void {
    if (!this.activePhenomenon) return;
    if (this.isPaused) {
      this.isPaused = false;
    } else {
      this.isPaused = true;
    }
    this.message = this.isPaused ? 'تم إيقاف تسجيل الظاهرة مؤقتاً' : 'تم استئناف تسجيل الظاهرة';
    this.updateDuration();
  }
  stopPhenomenon(): void {
    if (!this.activePhenomenon) return;
    const now = new Date();
    const local = this.localTime();
    const elapsed = now.getTime() - this.startedAt;
    const ended: LocalPhenomenon = {
      ...this.activePhenomenon,
      end_time: now.toISOString().slice(11, 19),
      end_time_local: local,
      phenomenon_duration: this.formatDuration(elapsed),
      phenomenon_status: 'منتهية',
      general_notes: this.notes.trim()
    };
    this.phenomena = this.phenomena.map(p => p.id === ended.id ? ended : p);
    this.lastEnded = ended;
    this.activePhenomenon = null;
    this.isPaused = false;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.currentDuration = ended.phenomenon_duration;
    this.message = 'انتهت المعاينة المحلية. السجل غير محفوظ في قاعدة البيانات.';
    this.lastUpdateTime = this.currentTime;
  }
  private updateDuration(): void {
    if (!this.activePhenomenon) return;
    this.currentDuration = this.formatDuration(Date.now() - this.startedAt);
  }
  chooseSuggestion(value: string): void { this.phenomenonType = value; this.showSuggestions = false; }
  setFilter(value: string): void { this.activeFilter = value; }
  refreshLocalView(): void { this.lastUpdateTime = this.currentTime; this.message = 'تم تحديث عرض سجلات المعاينة المحلية. لم يتم الاتصال بقاعدة البيانات.'; }
  resetLocalSession(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.phenomena = [];
    this.activePhenomenon = null;
    this.lastEnded = null;
    this.isPaused = false;
    this.currentDuration = '00:00:00';
    this.startedAt = 0;
    this.message = 'تمت إعادة ضبط بيانات المعاينة المحلية.';
  }
  focusPhenomenonType(): void { document.getElementById('phenomenonType')?.focus(); }
  currentDurationFor(item: LocalPhenomenon): string {
    return item.id === this.activePhenomenon?.id ? this.currentDuration : item.phenomenon_duration || '00:00:00';
  }
}
