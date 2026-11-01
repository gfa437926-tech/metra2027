import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';

interface DashboardCard {
  title: string;
  icon: string;
  description: string;
  colorClass: string;
  iconColor: string;
  buttonClass: string;
  actionLabel: string;
  path?: string;
}

@Component({
  standalone: true,
  imports: [RouterLink, CommonModule],
  template: `
    <div class="dashboard-page">
      <section class="logo-header fade-in">
        <i class="fa-solid fa-cloud-sun logo-icon"></i>
        <h1 class="logo-title">نظام إدارة البيانات الجوية</h1>
        <p class="logo-subtitle">المراقبة • التحليل • التنبؤ</p>
      </section>

      <section class="user-welcome fade-in">
        <div class="welcome-copy">
          <h2>
            <i class="fa-solid fa-user-circle"></i>
            طاب يومك بالخير.. <strong>{{ userName }}</strong>
          </h2>
          <p><i class="fa-regular fa-clock"></i> {{ userRole || 'الراصد الجوي' }} · {{ greetingTime }}</p>
          @if (stationName) {
            <span class="user-station"><i class="fa-solid fa-location-dot"></i>{{ stationName }}</span>
          }
        </div>
        <div class="welcome-actions">
          <button class="btn btn-outline-light" type="button" (click)="refreshDashboard()">
            <i class="fa-solid fa-rotate"></i> تحديث اللوحة
          </button>
          <button class="btn btn-light" type="button" (click)="logout()">
            <i class="fa-solid fa-right-from-bracket"></i> خروج
          </button>
        </div>
      </section>

      <h2 class="section-title fade-in"><i class="fa-solid fa-gauge-high"></i> لوحة التحكم الرئيسية</h2>

      <section class="weather-phenomena-card dashboard-card fade-in">
        <div class="phenomena-icon"><i class="fa-solid fa-bolt-lightning"></i></div>
        <div class="phenomena-copy">
          <h3>نشرة الظواهر الجوية الخطرة</h3>
          <p>قم بإرسال تقارير الظواهر الجوية الخطرة والاستثنائية مثل العواصف الرعدية، الأمطار الغزيرة، العواصف الترابية، والصقيع. هذه النشرة مهمة للتحذير المبكر وإدارة الطوارئ لحماية الأرواح والممتلكات.</p>
        </div>
        <button class="btn phenomena-button" type="button" (click)="showPending('نشرة الظواهر الجوية')">
          <i class="fa-solid fa-paper-plane"></i> إرسال النشرة
        </button>
      </section>

      <section class="card-section">
        <h3><i class="fa-solid fa-file-lines"></i> التقارير الأساسية</h3>
        <div class="cards-grid">
          @for (card of basicReports; track card.title; let i = $index) {
            <ng-container *ngTemplateOutlet="cardTemplate; context: { $implicit: card, index: i }"></ng-container>
          }
        </div>
      </section>

      <section class="card-section">
        <h3><i class="fa-solid fa-leaf"></i> المناخ والزراعة</h3>
        <div class="cards-grid">
          @for (card of climateCards; track card.title; let i = $index) {
            <ng-container *ngTemplateOutlet="cardTemplate; context: { $implicit: card, index: i + 3 }"></ng-container>
          }
        </div>
      </section>

      <section class="card-section">
        <h3><i class="fa-solid fa-screwdriver-wrench"></i> الصيانة والإصلاح</h3>
        <div class="cards-grid">
          @for (card of maintenanceCards; track card.title; let i = $index) {
            <ng-container *ngTemplateOutlet="cardTemplate; context: { $implicit: card, index: i + 6 }"></ng-container>
          }
        </div>
      </section>

      <section class="card-section">
        <h3><i class="fa-solid fa-circle-info"></i> حول النظام</h3>
        <div class="cards-grid">
          @for (card of aboutCards; track card.title; let i = $index) {
            <ng-container *ngTemplateOutlet="cardTemplate; context: { $implicit: card, index: i + 9 }"></ng-container>
          }
        </div>
      </section>

      @if (managementCards.length > 0) {
        <section class="card-section">
          <h3><i class="fa-solid fa-user-tie"></i> لوحات الإدارة</h3>
          <div class="cards-grid">
            @for (card of managementCards; track card.title; let i = $index) {
              <ng-container *ngTemplateOutlet="cardTemplate; context: { $implicit: card, index: i + 12 }"></ng-container>
            }
          </div>
        </section>
      }

      <footer class="main-footer">
        <div class="developer-name"><i class="fa-solid fa-code"></i> مطور النظام</div>
        <p>إبراهيم أحمد زينب</p>
        <a class="whatsapp-link" href="https://wa.me/0934884157" target="_blank" rel="noopener noreferrer">
          <i class="fa-brands fa-whatsapp"></i> تواصل عبر واتساب
        </a>
        <div class="copyright">© 2026 نظام إدارة البيانات الجوية. جميع الحقوق محفوظة</div>
      </footer>
    </div>

    <ng-template #cardTemplate let-card let-index="index">
      <article class="dashboard-card" [class]="card.colorClass" [style.animation-delay]="(index * 0.1) + 's'">
        <div class="card-icon" [style.color]="card.iconColor"><i [class]="card.icon"></i></div>
        <h4 class="card-title">{{ card.title }}</h4>
        <p class="card-description">{{ card.description }}</p>
        @if (card.path) {
          <a class="card-btn" [class]="card.buttonClass" [routerLink]="card.path">
            <i class="fa-solid fa-chart-line"></i> {{ card.actionLabel }}
          </a>
        } @else {
          <button class="card-btn" [class]="card.buttonClass" type="button" (click)="showPending(card.title)">
            <i class="fa-solid fa-arrow-up-right-from-square"></i> {{ card.actionLabel }}
          </button>
        }
      </article>
    </ng-template>

    @if (toastMessage) {
      <div class="toast-message" role="status"><i class="fa-solid fa-circle-info"></i>{{ toastMessage }}</div>
    }
  `,
  styles: [`
    :host{display:block;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif;color:#2c3e50}
    .dashboard-page{width:100%;max-width:1600px;margin:0 auto}
    .logo-header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:25px;border-radius:20px;margin-bottom:30px;box-shadow:0 10px 30px rgba(102,126,234,.3);text-align:center;position:relative;overflow:hidden}
    .logo-header:before{content:"";position:absolute;inset:-50%;background:radial-gradient(circle,rgba(255,255,255,.1),transparent 70%);pointer-events:none}
    .logo-icon{font-size:4rem;margin-bottom:15px;display:block;animation:float 3s ease-in-out infinite}
    .logo-title{font-size:clamp(1.5rem,3vw,2.2rem);font-weight:800;margin:0 0 5px;text-shadow:2px 2px 4px rgba(0,0,0,.2)}
    .logo-subtitle{font-size:1.1rem;opacity:.9;font-weight:300;margin:0}
    @keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-10px)}}
    .user-welcome{background:linear-gradient(135deg,#3498db 0%,#2980b9 100%);color:white;border-radius:20px;padding:28px 30px;margin-bottom:36px;box-shadow:0 10px 30px rgba(52,152,219,.3);display:flex;align-items:center;justify-content:space-between;gap:22px;flex-wrap:wrap;position:relative;overflow:hidden}
    .welcome-copy h2{font-size:1.35rem;font-weight:500;margin:0 0 9px}.welcome-copy h2 strong{font-weight:800}.welcome-copy p{margin:0 0 8px;opacity:.95}
    .welcome-copy i{margin-left:7px}.user-station{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.15);padding:7px 17px;border-radius:25px;border:1px solid rgba(255,255,255,.2);font-size:.92rem}
    .welcome-actions{display:flex;gap:9px;flex-wrap:wrap}.btn{border:1px solid transparent;border-radius:10px;padding:10px 16px;font-weight:600;cursor:pointer;display:inline-flex;align-items:center;gap:8px;text-decoration:none}.btn-outline-light{background:transparent;border-color:#fff;color:#fff}.btn-light{background:#fff;color:#2980b9}
    .section-title{color:#2c3e50;border-bottom:3px solid #3498db;padding:0 0 14px;margin:0 0 25px;position:relative;font-weight:800;font-size:1.65rem}.section-title:after{content:"";position:absolute;bottom:-3px;right:0;width:100px;height:3px;background:#e74c3c;border-radius:3px}.section-title i{margin-left:12px}
    .weather-phenomena-card{background:linear-gradient(135deg,#ff6b6b 0%,#ee5a52 100%);color:white;border:0!important;display:grid;grid-template-columns:130px 1fr 180px;align-items:center;gap:22px;margin-bottom:38px}
    .phenomena-icon{text-align:center;font-size:4rem;animation:pulse 2s infinite}.phenomena-copy h3{font-size:1.4rem;font-weight:800;margin:0 0 12px}.phenomena-copy p{line-height:1.8;color:rgba(255,255,255,.92);margin:0}
    .phenomena-button{background:rgba(255,255,255,.15);border:2px solid #fff;color:#fff;justify-content:center;padding:13px 15px;border-radius:10px;font-weight:700;cursor:pointer}.phenomena-button:hover{background:#fff;color:#e74c3c}
    @keyframes pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.1)}}
    .card-section{margin:0 0 38px}.card-section>h3{font-size:1.25rem;color:#65737e;font-weight:700;margin:0 0 20px}.card-section>h3 i{margin-left:9px}
    .cards-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}
    .dashboard-card{background:#fff;border-radius:20px;box-shadow:0 10px 30px rgba(0,0,0,.08);padding:26px 24px;text-align:center;transition:transform .3s,box-shadow .3s;border:1px solid rgba(0,0,0,.05);overflow:hidden;position:relative;display:flex;flex-direction:column;align-items:center;min-height:320px}
    .dashboard-card:not(.weather-phenomena-card):before{content:"";position:absolute;top:0;right:0;width:100%;height:5px;background:linear-gradient(135deg,#3498db,#2980b9)}
    .dashboard-card:not(.weather-phenomena-card):hover{transform:translateY(-8px);box-shadow:0 20px 40px rgba(0,0,0,.14)}
    .card-report{border-top:5px solid #3498db}.card-climate{border-top:5px solid #2ecc71}.card-agriculture{border-top:5px solid #e67e22}.card-maintenance{border-top:5px solid #e74c3c}.card-about{border-top:5px solid #00cec9}.card-management{border-top:5px solid #9b59b6}
    .card-icon{font-size:3.2rem;margin:12px 0 19px;position:relative}.card-icon:after{content:"";position:absolute;width:74px;height:74px;background:rgba(52,152,219,.09);border-radius:50%;top:50%;left:50%;transform:translate(-50%,-50%);z-index:0}.card-icon i{position:relative;z-index:1}
    .card-title{font-size:1.25rem;font-weight:800;color:#2c3e50;margin:0 0 12px;padding-bottom:10px;position:relative}.card-title:after{content:"";position:absolute;bottom:0;right:50%;transform:translateX(50%);width:50px;height:3px;background:linear-gradient(135deg,#3498db,#2980b9);border-radius:2px}
    .card-description{color:#666;font-size:.94rem;line-height:1.75;margin:0 0 20px;flex:1}
    .card-btn{width:100%;padding:12px;border:0;border-radius:10px;color:#fff;text-decoration:none;font-weight:700;display:flex;justify-content:center;align-items:center;gap:8px;cursor:pointer;transition:transform .2s,filter .2s}.card-btn:hover{transform:translateY(-2px);filter:brightness(.95)}
    .btn-primary{background:linear-gradient(135deg,#3498db,#2980b9)}.btn-success{background:linear-gradient(135deg,#2ecc71,#27ae60)}.btn-warning{background:linear-gradient(135deg,#e67e22,#d35400)}.btn-danger{background:linear-gradient(135deg,#e74c3c,#c0392b)}.btn-info{background:linear-gradient(135deg,#00cec9,#0984e3)}.btn-purple{background:linear-gradient(135deg,#9b59b6,#8e44ad)}
    .main-footer{background:linear-gradient(135deg,#2c3e50,#34495e);color:white;padding:28px 20px;margin-top:50px;border-top:5px solid #3498db;border-radius:12px;text-align:center}.developer-name{font-size:1.2rem;font-weight:700;color:#3498db}.main-footer p{margin:7px 0 15px}
    .whatsapp-link{display:inline-flex;align-items:center;gap:9px;background:linear-gradient(135deg,#25d366,#128c7e);color:white;padding:11px 23px;border-radius:25px;text-decoration:none;font-weight:600}.copyright{color:rgba(255,255,255,.7);font-size:.85rem;margin-top:20px}
    .toast-message{position:fixed;left:22px;bottom:22px;z-index:2000;background:#2c3e50;color:#fff;padding:14px 20px;border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.2);display:flex;gap:10px;align-items:center}
    .fade-in{animation:fadeInUp .6s ease-out both}@keyframes fadeInUp{from{opacity:0;transform:translateY(18px)}to{opacity:1;transform:translateY(0)}}
    @media(max-width:1150px){.cards-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.weather-phenomena-card{grid-template-columns:90px 1fr 160px}}
    @media(max-width:700px){.cards-grid{grid-template-columns:1fr}.logo-header{padding:22px 14px}.logo-icon{font-size:3.2rem}.user-welcome{padding:22px 18px}.welcome-actions{width:100%}.welcome-actions button{flex:1;justify-content:center}.weather-phenomena-card{grid-template-columns:1fr;text-align:center;padding:24px}.phenomena-icon{font-size:3.2rem}.phenomena-button{width:100%}.section-title{font-size:1.35rem}.dashboard-card{min-height:285px}}
  `]
})
export class DashboardComponent implements OnInit {
  userName = 'مستخدم النظام';
  userRole = '';
  stationName = '';
  greetingTime = this.getGreetingTime();
  toastMessage = '';

  readonly basicReports: DashboardCard[] = [
    { title: 'النشرات الساعية', icon: 'fa-regular fa-clock', description: 'إرسال وعرض التقارير الساعية لبيانات الطقس مثل الحرارة والرطوبة والرياح', path: '/reports/hourly', colorClass: 'card-report', iconColor: '#3498db', buttonClass: 'btn-primary', actionLabel: 'فتح التقرير' },
    { title: 'النشرات اليومية', icon: 'fa-regular fa-calendar-days', description: 'التقارير اليومية الشاملة لبيانات الطقس والإحصائيات اليومية', path: '/reports/daily', colorClass: 'card-report', iconColor: '#2980b9', buttonClass: 'btn-primary', actionLabel: 'فتح التقرير' },
    { title: 'النشرات المطرية', icon: 'fa-solid fa-cloud-rain', description: 'تقرير كميات الأمطار والهطول المطري والتحليل المطري الشامل', colorClass: 'card-report', iconColor: '#3498db', buttonClass: 'btn-primary', actionLabel: 'فتح التقرير' }
  ];

  readonly climateCards: DashboardCard[] = [
    { title: 'المناخ الساعي', icon: 'fa-solid fa-wind', description: 'بيانات المناخ الساعية ودرجات الحرارة والرطوبة النسبية', path: '/reports/climate', colorClass: 'card-climate', iconColor: '#2ecc71', buttonClass: 'btn-success', actionLabel: 'عرض البيانات' },
    { title: 'حرارة التربة', icon: 'fa-solid fa-temperature-low', description: 'قياسات حرارة التربة على أعماق مختلفة للاستخدام الزراعي', path: '/soil-temperature', colorClass: 'card-climate', iconColor: '#27ae60', buttonClass: 'btn-success', actionLabel: 'عرض البيانات' },
    { title: 'النشرات الزراعية', icon: 'fa-solid fa-seedling', description: 'تقارير خاصة بالبيانات الزراعية والمناخية لدعم القطاع الزراعي', path: '/agriculture', colorClass: 'card-agriculture', iconColor: '#e67e22', buttonClass: 'btn-warning', actionLabel: 'عرض البيانات' }
  ];

  readonly maintenanceCards: DashboardCard[] = [
    { title: 'أعطال الرصد', icon: 'fa-solid fa-satellite-dish', description: 'تسجيل ومتابعة أعطال أجهزة الرصد الجوي والمحطات', colorClass: 'card-maintenance', iconColor: '#e74c3c', buttonClass: 'btn-danger', actionLabel: 'إدارة الأعطال' },
    { title: 'أعطال الاتصالات', icon: 'fa-solid fa-network-wired', description: 'مشاكل الاتصالات والشبكات في المحطة ونقل البيانات', colorClass: 'card-maintenance', iconColor: '#c0392b', buttonClass: 'btn-danger', actionLabel: 'إدارة الأعطال' },
    { title: 'أعطال البرامج (IT)', icon: 'fa-solid fa-laptop-code', description: 'مشاكل البرامج والنظم التقنية ودعم المستخدمين', colorClass: 'card-maintenance', iconColor: '#d35400', buttonClass: 'btn-danger', actionLabel: 'إدارة الأعطال' }
  ];

  readonly aboutCards: DashboardCard[] = [
    { title: 'من نحن', icon: 'fa-solid fa-circle-info', description: 'تعرف على فريق العمل، رؤيتنا، رسالتنا، وأهداف نظام إدارة البيانات الجوية', colorClass: 'card-about', iconColor: '#00cec9', buttonClass: 'btn-info', actionLabel: 'فتح' },
    { title: 'دليل المستخدم', icon: 'fa-solid fa-book-open', description: 'تعليمات الاستخدام، الأسئلة الشائعة، ودليل تفصيلي لجميع ميزات النظام', colorClass: 'card-about', iconColor: '#0984e3', buttonClass: 'btn-info', actionLabel: 'فتح' },
    { title: 'اتصل بنا', icon: 'fa-solid fa-headset', description: 'معلومات الاتصال، الدعم الفني، اقتراحاتكم، وشكاويكم', colorClass: 'card-about', iconColor: '#6c5ce7', buttonClass: 'btn-info', actionLabel: 'فتح' }
  ];

  managementCards: DashboardCard[] = [];

  constructor(private readonly router: Router) {}

  ngOnInit(): void {
    if (typeof localStorage === 'undefined') return;
    try {
      const raw = localStorage.getItem('currentUser');
      if (!raw) return;
      const user = JSON.parse(raw) as Record<string, string>;
      this.userName = [user['first_name'], user['last_name']].filter(Boolean).join(' ') || this.userName;
      this.userRole = user['role'] || user['jobTitle'] || '';
      this.stationName = user['station'] || '';
      this.setManagementCards();
    } catch {
      this.showPending('بيانات المستخدم');
    }
  }

  refreshDashboard(): void {
    this.greetingTime = this.getGreetingTime();
    this.showPending('تم تحديث لوحة التحكم');
  }

  logout(): void {
    if (typeof localStorage !== 'undefined' && window.confirm('هل أنت متأكد من رغبتك في تسجيل الخروج؟')) {
      localStorage.removeItem('currentUser');
      this.userName = 'مستخدم النظام';
      this.userRole = '';
      this.stationName = '';
      this.managementCards = [];
      this.showPending('تم تسجيل الخروج من هذه الجلسة المحلية');
    }
  }

  showPending(name: string): void {
    this.toastMessage = name.includes('تحديث') || name.includes('تسجيل الخروج') ? name : `${name} قيد النقل إلى النسخة الجديدة`;
    window.setTimeout(() => this.toastMessage = '', 3500);
  }

  private setManagementCards(): void {
    if (this.userRole === 'رئيس محطة') {
      this.managementCards = [{ title: 'إدارة المحطة', icon: 'fa-solid fa-user-tie', description: 'لوحة تحكم رئيس المحطة لإدارة المستخدمين والتقارير والعمليات', colorClass: 'card-management', iconColor: '#9b59b6', buttonClass: 'btn-purple', actionLabel: 'فتح اللوحة' }];
    } else if (this.userRole === 'مدير مركز') {
      this.managementCards = [{ title: 'إدارة المركز', icon: 'fa-solid fa-user-gear', description: 'لوحة تحكم مدير المركز للمتابعة والإشراف والتقارير الشاملة', colorClass: 'card-management', iconColor: '#8e44ad', buttonClass: 'btn-purple', actionLabel: 'فتح اللوحة' }];
    } else if (this.userRole === 'مدير النظام') {
      this.managementCards = [{ title: 'لوحة المدير العام', icon: 'fa-solid fa-crown', description: 'لوحة التحكم الشاملة لمدير النظام والإحصائيات والتقارير الإدارية', colorClass: 'card-management', iconColor: '#f1c40f', buttonClass: 'btn-warning', actionLabel: 'فتح اللوحة' }];
    }
  }

  private getGreetingTime(): string {
    const hour = new Date().getHours();
    if (hour < 5) return 'ليلة سعيدة';
    if (hour < 12) return 'صباح الخير';
    return 'مساء الخير';
  }
}
