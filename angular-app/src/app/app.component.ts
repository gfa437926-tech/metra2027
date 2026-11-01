import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

@Component({
  selector: 'metra-root',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, RouterOutlet],
  template: `
    <button class="mobile-menu" type="button" (click)="sidebarOpen = !sidebarOpen" aria-label="فتح القائمة">
      <i class="fa-solid fa-bars"></i><span>القائمة</span>
    </button>
    <div class="sidebar-backdrop" [class.visible]="sidebarOpen" (click)="closeSidebar()"></div>
    <aside class="sidebar" [class.open]="sidebarOpen" aria-label="القائمة الرئيسية">
      <div class="sidebar-scroll">
        <header class="sidebar-header">
          <div class="logo-container"><i class="fa-solid fa-cloud-sun"></i></div>
          <h1>نظام إدارة البيانات الجوية</h1><p>METRA 2027</p>
        </header>
        <section class="user-card">
          <div class="user-avatar"><i class="fa-solid fa-user"></i></div>
          <div class="user-name">مستخدم النظام</div>
          <div class="user-details">الراصد الجوي · المحطة الرئيسية</div>
        </section>
        <div class="section-title">الإدارة</div>
        <nav>
          <a class="nav-link" routerLink="/" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}" (click)="closeSidebar()"><i class="fa-solid fa-gauge-high"></i><span>لوحة التحكم</span></a>
        </nav>
        <div class="section-title">النشرات الجوية</div>
        <nav>
          <a class="nav-link" routerLink="/reports/hourly" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-regular fa-clock hourly"></i><span>النشرات الساعية</span></a>
          <a class="nav-link" routerLink="/reports/climate" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-solid fa-wind climate"></i><span>المناخ الساعي</span></a>
          <a class="nav-link" routerLink="/reports/daily" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-regular fa-calendar-days daily"></i><span>النشرات اليومية</span></a>
          <a class="nav-link" routerLink="/soil-temperature" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-solid fa-temperature-half soil"></i><span>حرارة التربة</span></a>
          <a class="nav-link" routerLink="/agriculture" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-solid fa-seedling agriculture"></i><span>النشرات الزراعية</span></a>
        </nav>
        <div class="section-title">إدارة النظام</div>
        <nav>
          <a class="nav-link" routerLink="/users" routerLinkActive="active" (click)="closeSidebar()"><i class="fa-solid fa-users users"></i><span>المستخدمون والصلاحيات</span></a>
        </nav>
      </div>
    </aside>
    <main class="content-area">
      <router-outlet />
      <footer>METRA 2027 · نظام إدارة السجلات المناخية</footer>
    </main>
  `,
  styles: [`
    :host{display:block;min-height:100vh;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#2c3e50}
    .sidebar{position:fixed;inset:0 0 0 auto;width:300px;height:100vh;z-index:1000;background:linear-gradient(180deg,#2c3e50 0%,#34495e 100%);border-left:5px solid #3498db;box-shadow:-5px 0 25px rgba(0,0,0,.1);color:#ecf0f1}
    .sidebar-scroll{height:100%;overflow-y:auto;padding:20px 0}
    .sidebar-header{text-align:center;padding:8px 18px 22px;border-bottom:1px solid rgba(255,255,255,.1);margin-bottom:18px}
    .logo-container{width:66px;height:66px;border-radius:50%;margin:0 auto 12px;background:#fff;color:#3498db;display:grid;place-items:center;font-size:32px;box-shadow:0 4px 15px rgba(0,0,0,.2)}
    .sidebar-header h1{font-size:17px;font-weight:800;margin:0;color:#fff}.sidebar-header p{font-size:12px;color:rgba(255,255,255,.7);margin:6px 0 0;letter-spacing:1px}
    .user-card{background:rgba(255,255,255,.05);border-radius:10px;padding:14px 10px;margin:0 15px 18px;border-right:4px solid #2980b9;text-align:center}
    .user-avatar{width:42px;height:42px;background:#2980b9;border-radius:50%;display:grid;place-items:center;margin:0 auto 8px;font-size:18px}
    .user-name{font-weight:700;font-size:14px}.user-details{font-size:11px;opacity:.78;margin-top:4px}
    .section-title{color:rgba(255,255,255,.62);font-size:12px;font-weight:700;padding:13px 20px 7px;margin:8px 15px 4px;border-bottom:1px solid rgba(255,255,255,.1)}
    nav{display:flex;flex-direction:column}
    .nav-link{color:#ecf0f1;text-decoration:none;display:flex;align-items:center;gap:12px;padding:11px 16px;margin:3px 15px;border-radius:8px;font-size:13px;transition:background .2s,transform .2s}
    .nav-link i{width:20px;text-align:center;font-size:15px;color:#27ae60}.nav-link i.hourly{color:#bb8fce}.nav-link i.climate{color:#1abc9c}.nav-link i.daily{color:#f39c12}.nav-link i.soil{color:#af7ac5}.nav-link i.agriculture{color:#2ecc71}.nav-link i.users{color:#d7bde2}
    .nav-link:hover{background:rgba(255,255,255,.1);transform:translateX(-3px);color:#fff}.nav-link.active{background:#2980b9;color:#fff;box-shadow:0 4px 12px rgba(41,128,185,.3)}.nav-link.active i{color:#fff}
    .content-area{margin-right:300px;padding:30px;min-height:100vh;display:flex;flex-direction:column;background:linear-gradient(135deg,#f8f9fa 0%,#e9ecef 100%)}
    footer{margin-top:auto;text-align:center;padding:24px 8px 0;color:#83929b;font-size:11px}
    .mobile-menu,.sidebar-backdrop{display:none}
    @media(max-width:992px){.sidebar{transform:translateX(105%);transition:transform .25s ease;width:min(300px,85vw)}.sidebar.open{transform:translateX(0)}.content-area{margin-right:0;padding:76px 18px 24px}.mobile-menu{display:flex;align-items:center;gap:9px;position:fixed;top:14px;right:14px;z-index:1002;border:0;border-radius:9px;padding:10px 15px;background:#2980b9;color:white;box-shadow:0 4px 14px rgba(41,128,185,.25)}.sidebar-backdrop.visible{display:block;position:fixed;inset:0;background:rgba(0,0,0,.4);z-index:999}}
  `]
})
export class AppComponent {
  sidebarOpen = false;
  closeSidebar(): void { this.sidebarOpen = false; }
}
