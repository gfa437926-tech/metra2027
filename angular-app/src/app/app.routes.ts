import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./features/dashboard/dashboard.component')
      .then((m) => m.DashboardComponent)
  },
  {
    path: 'reports/hourly',
    loadComponent: () => import('./features/reports/hourly-reports.component')
      .then((m) => m.HourlyReportsComponent)
  },
  {
    path: 'reports/daily',
    loadComponent: () => import('./features/reports/daily-reports.component')
      .then((m) => m.DailyReportsComponent)
  },
  {
    path: 'reports/climate',
    loadComponent: () => import('./features/reports/climate-reports.component')
      .then((m) => m.ClimateReportsComponent)
  },
  {
    path: 'agriculture',
    loadComponent: () => import('./features/agriculture/agriculture.component')
      .then((m) => m.AgricultureComponent)
  },
  {
    path: 'soil-temperature',
    loadComponent: () => import('./features/soil/soil-temperature.component')
      .then((m) => m.SoilTemperatureComponent)
  },
  {
    path: 'users',
    loadComponent: () => import('./features/users/users.component')
      .then((m) => m.UsersComponent)
  },
  { path: '**', redirectTo: '' }
];