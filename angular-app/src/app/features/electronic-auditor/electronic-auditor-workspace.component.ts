import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

/**
 * Scaffold only — Electronic Auditor workstation.
 * Design: docs/features/ELECTRONIC-AUDITOR-DESIGN-V1.md
 * No chart OCR, no API binding, no accuracy claims in this revision.
 */
@Component({
  standalone: true,
  selector: 'metra-electronic-auditor-workspace',
  imports: [CommonModule, RouterLink],
  template: `
    <div class="ea-page" dir="rtl">
      <header class="ea-header">
        <h1><i class="fa-solid fa-ruler-combined"></i> المدقق الإلكتروني</h1>
        <p class="ea-sub">
          منظومة التدقيق الذكي للسجلات الورقية ومخططات المسجلات الميكانيكية ومقارنتها بالرصد الإلكتروني —
          <strong>واجهة هيكلية فقط</strong> حتى اعتماد التصميم وتوفير مخططات مرجعية.
        </p>
      </header>

      <section class="ea-banner metra-state-warn" role="status">
        <p>
          لم تُربط هذه الشاشة بأي خدمة رفع أو استخراج أو اعتماد بعد.
          لن تُعرض نتائج مطابقة ولن تُعدَّل النشرات الأصلية من هنا.
        </p>
        <p>
          المواصفات الرسمية:
          <code>docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md</code>
        </p>
      </section>

      <section class="ea-grid">
        <article class="ea-card">
          <h2>0) السجلات الورقية الرسمية</h2>
          <p>رفع صفحات السجل، التعرف على الخانات، استخراج القيم، المقارنة بالإرسال الإلكتروني.</p>
          <p class="muted">غير متاح — مواصفات IA فقط</p>
        </article>
        <article class="ea-card">
          <h2>1) سجل التدقيق</h2>
          <p>إنشاء حالة مرتبطة بمحطة وجهاز وفترة مخطط (UTC).</p>
          <p class="muted">غير متاح — بانتظار API وصلاحيات <code>electronic_auditor.*</code></p>
        </article>
        <article class="ea-card">
          <h2>2) رفع المخطط الأصلي</h2>
          <p>حفظ الصورة الأصلية وبصمة رقمية دون حذف أو استبدال صامت.</p>
          <p class="muted">غير متاح</p>
        </article>
        <article class="ea-card">
          <h2>3) المعايرة والاستخراج</h2>
          <p>محاور، نقاط معايرة، منحنى، قراءات زمنية.</p>
          <p class="muted">لا ادّعاء لدقة القراءة الآلية دون مجموعة مرجعية معتمدة</p>
        </article>
        <article class="ea-card">
          <h2>4) المقارنة والمحركات</h2>
          <p>قيم METRA الإلكترونية، فروق، تدقيق فيزيائي ورياضي بإصدارات قواعد موثّقة.</p>
          <p class="muted">غير متاح</p>
        </article>
        <article class="ea-card">
          <h2>5) القرار والتقرير</h2>
          <p>قرار المدقق لا يغيّر حمولة الرصد الأصلية تلقائياً.</p>
          <p class="muted">غير متاح</p>
        </article>
      </section>

      <footer class="ea-footer">
        <a routerLink="/">العودة للوحة التحكم</a>
        ·
        <a routerLink="/stations">دليل المحطات</a>
        ·
        <a routerLink="/observations/workflow">مراجعة النشرات</a>
      </footer>
    </div>
  `,
  styles: [
    `
      .ea-page {
        max-width: 1100px;
        margin: 0 auto;
        padding: 1.25rem;
        font-family: inherit;
      }
      .ea-header h1 {
        margin: 0 0 0.35rem;
        font-size: 1.5rem;
      }
      .ea-sub {
        color: #475569;
        margin: 0 0 1rem;
      }
      .ea-banner {
        border: 1px solid #f59e0b;
        background: #fffbeb;
        border-radius: 10px;
        padding: 0.85rem 1rem;
        margin-bottom: 1.25rem;
      }
      .ea-banner p {
        margin: 0.35rem 0;
      }
      .ea-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
        gap: 0.85rem;
      }
      .ea-card {
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        padding: 0.9rem;
        background: #fff;
      }
      .ea-card h2 {
        margin: 0 0 0.4rem;
        font-size: 1.05rem;
      }
      .muted {
        color: #64748b;
        font-size: 0.9rem;
      }
      .ea-footer {
        margin-top: 1.5rem;
        font-size: 0.95rem;
      }
      .ea-footer a {
        margin-inline: 0.25rem;
      }
    `,
  ],
})
export class ElectronicAuditorWorkspaceComponent {}
