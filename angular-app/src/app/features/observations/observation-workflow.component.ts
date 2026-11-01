import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

type ReportStatus = 'draft' | 'submitted' | 'returned' | 'approved';
type ReportAction = 'submit' | 'return' | 'approve' | 'resubmit';

interface ReportRow {
  id: number;
  type: string;
  station: string;
  observationDate: string;
  createdBy: string;
  status: ReportStatus;
  note: string;
}

@Component({
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="workflow-page" dir="rtl">
      <header class="page-heading">
        <div>
          <div class="eyebrow"><i class="fa-solid fa-list-check"></i> إدارة ومتابعة السجلات</div>
          <h1>دورة النشرات الجوية</h1>
          <p>معاينة مرئية لمسار إدخال النشرات ومراجعتها واعتمادها.</p>
        </div>
        <span class="demo-label"><i class="fa-solid fa-flask"></i> معاينة تجريبية</span>
      </header>

      <div class="notice" role="note">
        <i class="fa-solid fa-circle-info"></i>
        <div><strong>هذه بيانات تجريبية للعرض فقط.</strong><span>التغييرات هنا مؤقتة داخل الصفحة، ولا يتم حفظها في قاعدة البيانات أو إرسالها إلى الخادم.</span></div>
      </div>

      <section class="summary-grid" aria-label="ملخص النشرات">
        <article class="summary-card"><span>كل النشرات</span><strong>{{ reports.length }}</strong><i class="fa-solid fa-layer-group"></i></article>
        <article class="summary-card submitted"><span>بانتظار المراجعة</span><strong>{{ count('submitted') }}</strong><i class="fa-solid fa-hourglass-half"></i></article>
        <article class="summary-card returned"><span>معادة للتصحيح</span><strong>{{ count('returned') }}</strong><i class="fa-solid fa-rotate-left"></i></article>
        <article class="summary-card approved"><span>معتمدة</span><strong>{{ count('approved') }}</strong><i class="fa-solid fa-circle-check"></i></article>
      </section>

      <section class="workflow-card">
        <div class="section-heading"><div><h2>مسار العمل</h2><p>انتقالات الحالات المتاحة في نموذج المعاينة</p></div></div>
        <div class="steps">
          <div class="step"><span>1</span><strong>مسودة</strong><small>إدخال وتعديل</small></div><i class="fa-solid fa-arrow-left"></i>
          <div class="step"><span>2</span><strong>قيد المراجعة</strong><small>فحص البيانات</small></div><i class="fa-solid fa-arrow-left"></i>
          <div class="step"><span>3</span><strong>إرجاع أو اعتماد</strong><small>قرار المراجع</small></div><i class="fa-solid fa-arrow-left"></i>
          <div class="step"><span>4</span><strong>معتمدة</strong><small>مرحلة نهائية</small></div>
        </div>
      </section>

      <section class="workflow-card">
        <div class="toolbar">
          <div><h2>سجل النشرات</h2><p>اختر نشرة لعرض الإجراءات الممكنة</p></div>
          <label class="filter">تصفية الحالة
            <select [value]="filter" (change)="setFilter($any($event.target).value)">
              <option value="all">جميع الحالات</option>
              <option value="draft">مسودة</option>
              <option value="submitted">بانتظار المراجعة</option>
              <option value="returned">معادة للتصحيح</option>
              <option value="approved">معتمدة</option>
            </select>
          </label>
        </div>

        <div class="table-wrap">
          <table>
            <thead><tr><th>رقم النشرة</th><th>النوع</th><th>المحطة</th><th>التاريخ</th><th>المدخل</th><th>الحالة</th><th>الإجراءات</th></tr></thead>
            <tbody>
              <tr *ngFor="let report of visibleReports" [class.selected]="selectedId === report.id">
                <td data-label="رقم النشرة">MET-{{ report.id }}</td>
                <td data-label="النوع">{{ report.type }}</td>
                <td data-label="المحطة">{{ report.station }}</td>
                <td data-label="التاريخ">{{ report.observationDate }}</td>
                <td data-label="المدخل">{{ report.createdBy }}</td>
                <td data-label="الحالة"><span class="status" [ngClass]="report.status">{{ statusLabel(report.status) }}</span></td>
                <td data-label="الإجراءات"><button class="view-btn" type="button" (click)="select(report.id)">عرض الإجراءات</button></td>
              </tr>
              <tr *ngIf="visibleReports.length === 0"><td colspan="7" class="empty">لا توجد نشرات بهذه الحالة.</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="workflow-card action-panel" *ngIf="selectedReport as report">
        <div class="toolbar">
          <div><h2>إجراءات النشرة MET-{{ report.id }}</h2><p>{{ report.type }} · {{ report.station }} · {{ report.observationDate }}</p></div>
          <span class="status" [ngClass]="report.status">{{ statusLabel(report.status) }}</span>
        </div>
        <p class="report-note" *ngIf="report.note"><i class="fa-regular fa-comment-dots"></i> {{ report.note }}</p>
        <div class="actions">
          <button *ngIf="report.status === 'draft'" class="primary" (click)="apply(report, 'submit')"><i class="fa-solid fa-paper-plane"></i> إرسال للمراجعة</button>
          <button *ngIf="report.status === 'submitted'" class="warning" (click)="apply(report, 'return')"><i class="fa-solid fa-rotate-left"></i> إرجاع للتصحيح</button>
          <button *ngIf="report.status === 'submitted'" class="success" (click)="apply(report, 'approve')"><i class="fa-solid fa-check"></i> اعتماد النشرة</button>
          <button *ngIf="report.status === 'returned'" class="primary" (click)="apply(report, 'resubmit')"><i class="fa-solid fa-paper-plane"></i> إعادة الإرسال</button>
          <span *ngIf="report.status === 'approved'" class="terminal"><i class="fa-solid fa-lock"></i> النشرة معتمدة ولا توجد إجراءات أخرى في هذا المسار.</span>
        </div>
        <div class="feedback" *ngIf="feedback" role="status">{{ feedback }}</div>
      </section>
    </div>
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#2c3e50}
    .workflow-page{max-width:1500px;margin:0 auto}.page-heading{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:22px}.eyebrow{color:#2980b9;font-weight:700;font-size:13px}.eyebrow i{margin-left:7px}h1{font-size:clamp(24px,3vw,32px);margin:7px 0;font-weight:800}h2{font-size:19px;margin:0 0 5px}p{margin:0;color:#7b8790;font-size:13px}.demo-label{background:#fff3cd;color:#856404;border:1px solid #ffe69c;padding:9px 13px;border-radius:9px;font-size:12px;font-weight:700;white-space:nowrap}.demo-label i{margin-left:6px}
    .notice{display:flex;gap:12px;align-items:flex-start;background:#eaf4fb;border:1px solid #c9e2f3;border-right:4px solid #3498db;border-radius:10px;padding:14px 16px;margin-bottom:20px;color:#245575}.notice>i{font-size:20px;margin-top:2px}.notice div{display:grid;gap:4px}.notice span{font-size:12px}
    .summary-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:15px;margin-bottom:20px}.summary-card{background:white;border-radius:12px;padding:18px;box-shadow:0 5px 18px #2233440c;position:relative;display:grid;gap:8px;border-bottom:3px solid #3498db}.summary-card span{font-size:13px;color:#71808b}.summary-card strong{font-size:27px}.summary-card>i{position:absolute;left:18px;top:20px;color:#3498db;font-size:22px;opacity:.7}.summary-card.submitted{border-color:#e6a23c}.summary-card.submitted>i{color:#e6a23c}.summary-card.returned{border-color:#e67e22}.summary-card.returned>i{color:#e67e22}.summary-card.approved{border-color:#27ae60}.summary-card.approved>i{color:#27ae60}
    .workflow-card{background:#fff;border-radius:13px;padding:22px;margin-bottom:20px;box-shadow:0 5px 18px #2233440c}.section-heading,.toolbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}.steps{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 2px}.steps>i{color:#aab5bd;font-size:15px}.step{display:grid;justify-items:center;gap:5px;min-width:90px;text-align:center}.step>span{width:35px;height:35px;border-radius:50%;display:grid;place-items:center;background:#eaf4fb;color:#2980b9;font-weight:800}.step strong{font-size:13px}.step small{font-size:11px;color:#89949c}
    .filter{display:grid;gap:5px;font-size:12px;color:#697781}.filter select{font:inherit;min-width:170px;padding:9px 12px;border:1px solid #dce3e8;border-radius:8px;background:#fff;color:#34495e}.table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;white-space:nowrap}th{text-align:right;background:#f5f7f9;color:#697781;font-size:12px;font-weight:700;padding:13px 12px}td{padding:14px 12px;border-bottom:1px solid #edf0f2;font-size:13px}tbody tr:hover,tbody tr.selected{background:#f5faff}.status{display:inline-flex;padding:5px 10px;border-radius:20px;font-size:11px;font-weight:700}.status.draft{background:#edf0f2;color:#59636b}.status.submitted{background:#fff3cd;color:#946200}.status.returned{background:#fff0e2;color:#b85c00}.status.approved{background:#e4f6eb;color:#218348}.view-btn{border:1px solid #cbd8e2;background:#fff;color:#2876a8;padding:7px 11px;border-radius:7px;cursor:pointer;font:inherit;font-size:12px}.empty{text-align:center;color:#89949c;padding:30px}
    .action-panel{border-top:3px solid #3498db}.report-note{background:#fff8e9;padding:10px 12px;border-radius:8px;color:#855b18;margin:12px 0}.report-note i{margin-left:6px}.actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px}.actions button{border:0;border-radius:8px;padding:11px 16px;color:white;font:inherit;font-weight:700;cursor:pointer}.actions button i{margin-left:7px}.primary{background:#2980b9}.warning{background:#e67e22}.success{background:#27ae60}.terminal{color:#218348;font-size:13px}.terminal i{margin-left:6px}.feedback{margin-top:14px;padding:10px 12px;background:#eaf7ef;color:#218348;border-radius:8px;font-size:13px}
    @media(max-width:900px){.summary-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.steps{flex-wrap:wrap;justify-content:center}.steps>i{transform:rotate(180deg)}}
    @media(max-width:650px){.page-heading{align-items:flex-start;flex-direction:column}.summary-grid{gap:9px}.summary-card{padding:14px}.summary-card strong{font-size:23px}.summary-card>i{left:12px;top:16px;font-size:17px}.workflow-card{padding:15px}.toolbar{align-items:flex-start;flex-direction:column}.filter,.filter select{width:100%}table,thead,tbody,tr,td{display:block}thead{display:none}tbody tr{border:1px solid #e8edf0;border-radius:9px;margin-bottom:12px;padding:8px}td{display:flex;justify-content:space-between;gap:10px;padding:8px 5px;white-space:normal;border-bottom:1px solid #f0f2f4}td:before{content:attr(data-label);font-weight:700;color:#77838c}.empty{display:block}.empty:before{display:none}}
  `]
})
export class ObservationWorkflowComponent {
  filter = 'all';
  selectedId = 1002;
  feedback = '';
  reports: ReportRow[] = [
    { id: 1001, type: 'نشرة ساعية', station: 'محطة تجريبية - 01', observationDate: '2026-11-01 06:00', createdBy: 'راصد تجريبي', status: 'draft', note: '' },
    { id: 1002, type: 'نشرة يومية', station: 'محطة تجريبية - 01', observationDate: '2026-10-31', createdBy: 'راصد تجريبي', status: 'submitted', note: 'بانتظار مراجعة مسؤول المحطة.' },
    { id: 1003, type: 'نشرة ساعية', station: 'محطة تجريبية - 02', observationDate: '2026-10-31 12:00', createdBy: 'راصد تجريبي', status: 'returned', note: 'يرجى مراجعة قيمة الرؤية وإعادة إرسال النشرة.' },
    { id: 1004, type: 'نشرة يومية', station: 'محطة تجريبية - 02', observationDate: '2026-10-30', createdBy: 'راصد تجريبي', status: 'approved', note: 'اعتماد تجريبي للعرض.' }
  ];

  get visibleReports(): ReportRow[] {
    return this.filter === 'all' ? this.reports : this.reports.filter(report => report.status === this.filter);
  }

  get selectedReport(): ReportRow | undefined {
    return this.reports.find(report => report.id === this.selectedId);
  }

  count(status: ReportStatus): number {
    return this.reports.filter(report => report.status === status).length;
  }

  setFilter(value: string): void {
    this.filter = value;
    if (!this.visibleReports.some(report => report.id === this.selectedId)) {
      this.selectedId = this.visibleReports[0]?.id ?? 0;
    }
    this.feedback = '';
  }

  select(id: number): void {
    this.selectedId = id;
    this.feedback = '';
  }

  statusLabel(status: ReportStatus): string {
    return ({ draft: 'مسودة', submitted: 'بانتظار المراجعة', returned: 'معادة للتصحيح', approved: 'معتمدة' })[status];
  }

  apply(report: ReportRow, action: ReportAction): void {
    const transitions: Record<ReportAction, Partial<Record<ReportStatus, ReportStatus>>> = {
      submit: { draft: 'submitted' },
      return: { submitted: 'returned' },
      approve: { submitted: 'approved' },
      resubmit: { returned: 'submitted' }
    };
    const next = transitions[action][report.status];
    if (!next) {
      this.feedback = 'العملية غير مسموحة في حالة النشرة الحالية.';
      return;
    }
    report.status = next;
    report.note = action === 'return' ? 'ملاحظة تجريبية: يرجى تصحيح البيانات ثم إعادة الإرسال.' : '';
    this.feedback = 'تم تغيير الحالة في المعاينة فقط؛ لم يتم حفظ أي بيانات على الخادم.';
  }
}