import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  standalone: true,
  imports: [RouterLink],
  template: `
    <section class="welcome">
      <p class="eyebrow">منصة الأرصاد والبيانات الجوية</p>
      <h1>مرحباً بك في METRA 2027</h1>
      <p>هذه نقطة الانطلاق للواجهة الجديدة. ستُنقل وظائف النظام الحالي إلى وحدات Angular تدريجياً مع الحفاظ على التطبيق القديم.</p>
    </section>
    <section class="tiles" aria-label="وحدات النظام">
      @for (item of modules; track item.path) {
        <a class="tile" [routerLink]="item.path"><span>{{item.icon}}</span><div><strong>{{item.title}}</strong><small>{{item.description}}</small></div><b>←</b></a>
      }
    </section>
    <aside>تنبيه: هذه الواجهة تأسيسية؛ لم يتم بعد ربط النماذج بقاعدة البيانات أو نقل صلاحيات المستخدمين.</aside>
  `,
  styles: [`
    .welcome{background:linear-gradient(120deg,#123b52,#1e6170);color:#fff;padding:38px;border-radius:18px}
    .eyebrow{color:#f2c777;font-size:13px}.welcome h1{margin:10px 0;font-size:clamp(26px,4vw,38px)}.welcome p:last-child{max-width:720px;line-height:1.9;color:#e2edf0}
    .tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px;margin:24px 0}
    .tile{display:flex;align-items:center;gap:14px;background:white;border:1px solid #e1e9ed;border-radius:14px;padding:20px;text-decoration:none}
    .tile>span{font-size:25px}.tile div{flex:1}.tile strong,.tile small{display:block}.tile small{color:#71838d;margin-top:6px}.tile>b{color:#b27a26}
    aside{padding:15px;border-right:4px solid #d6a348;background:#fff8e9;color:#6d5428;border-radius:8px;font-size:13px}
  `]
})
export class DashboardComponent {
  readonly modules = [
    { title: 'التقارير الساعية', description: 'إدخال ومتابعة الرصد الساعي', path: '/reports/hourly', icon: '🕒' },
    { title: 'التقارير اليومية', description: 'بيانات الرصد اليومي', path: '/reports/daily', icon: '📋' },
    { title: 'التقارير المناخية', description: 'السجلات والتحليلات المناخية', path: '/reports/climate', icon: '🌦️' },
    { title: 'التقارير الزراعية', description: 'البيانات الزراعية', path: '/agriculture', icon: '🌱' },
    { title: 'حرارة التربة', description: 'قراءات درجات حرارة التربة', path: '/soil-temperature', icon: '🌡️' },
    { title: 'إدارة المستخدمين', description: 'واجهة إدارة الحسابات والصلاحيات', path: '/users', icon: '👥' }
  ];
}