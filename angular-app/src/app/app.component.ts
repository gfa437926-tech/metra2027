import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

@Component({
  selector: 'metra-root',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, RouterOutlet],
  template: `
    <header class="topbar">
      <div class="brand"><span class="mark">M</span><div><strong>METRA 2027</strong><small>نظام إدارة البيانات الجوية</small></div></div>
      <nav aria-label="التنقل الرئيسي">
        <a routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}">الرئيسية</a>
        <a routerLink="/reports/hourly" routerLinkActive="active">التقارير الساعية</a>
        <a routerLink="/reports/daily" routerLinkActive="active">التقارير اليومية</a>
        <a routerLink="/reports/climate" routerLinkActive="active">المناخ</a>
        <a routerLink="/agriculture" routerLinkActive="active">الزراعة</a>
        <a routerLink="/soil-temperature" routerLinkActive="active">حرارة التربة</a>
        <a routerLink="/users" routerLinkActive="active">المستخدمون</a>
      </nav>
    </header>
    <main><router-outlet /></main>
    <footer>METRA 2027 · واجهة Angular الجديدة — مرحلة التأسيس</footer>
  `,
  styles: [`
    .topbar{background:#123b52;color:#fff;padding:18px max(5vw,20px);display:flex;align-items:center;justify-content:space-between;gap:24px;flex-wrap:wrap}
    .brand{display:flex;align-items:center;gap:12px}.brand strong,.brand small{display:block}.brand small{opacity:.75;margin-top:4px;font-size:12px}
    .mark{display:grid;place-items:center;width:42px;height:42px;border-radius:12px;background:#e2a94b;color:#123b52;font-weight:800;font-size:22px}
    nav{display:flex;gap:8px;flex-wrap:wrap}nav a{padding:9px 11px;text-decoration:none;border-radius:8px;font-size:13px;color:#eaf1f4}nav a.active,nav a:hover{background:#ffffff20}
    main{max-width:1180px;margin:32px auto;padding:0 20px;min-height:70vh}
    footer{text-align:center;padding:22px;color:#71838d;font-size:12px;border-top:1px solid #e0e7eb}
    @media(max-width:700px){.topbar{align-items:flex-start}nav{width:100%}}
  `]
})
export class AppComponent {}