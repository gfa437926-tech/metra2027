import { Routes } from '@angular/router';
import { requireAuthenticatedUser } from './core/supabase/auth.guard';

export const routes: Routes = [
  { path: 'equipment-faults', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/maintenance/equipment-fault-workflow.component').then(m => m.EquipmentFaultWorkflowComponent) },
  {
    path: 'login',
    loadComponent: () => import('./features/auth/login.component').then((m) => m.LoginComponent)
  },
  {
    path: 'register',
    loadComponent: () => import('./features/auth/registration.component').then((m) => m.RegistrationComponent)
  },
  {
    path: '',
    loadComponent: () => import('./features/dashboard/dashboard.component')
      .then((m) => m.DashboardComponent)
  },
  {
    path: 'phenomena/input',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/phenomena/phenomena-input.component')
      .then((m) => m.PhenomenaInputComponent)
  },
  {
    path: 'phenomena',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/phenomena/phenomena.component')
      .then((m) => m.PhenomenaComponent)
  },
  {
    path: 'reports/hourly',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/hourly-reports.component')
      .then((m) => m.HourlyReportsComponent)
  },
  {
    path: 'reports/rainfall',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/rainfall-reports.component')
      .then((m) => m.RainfallReportsComponent)
  },
  {
    path: 'reports/daily',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/daily-reports.component')
      .then((m) => m.DailyReportsComponent)
  },
  {
    path: 'reports/climate',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/climate-reports.component')
      .then((m) => m.ClimateReportsComponent)
  },
  {
    path: 'agriculture',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/agriculture/agriculture.component')
      .then((m) => m.AgricultureComponent)
  },
  {
    path: 'soil-temperature',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/soil/soil-temperature.component')
      .then((m) => m.SoilTemperatureComponent)
  },
  {
    path: 'users',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/users/users.component')
      .then((m) => m.UsersComponent)
  },
  {
    path: 'reports/monthly',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/monthly-reports.component').then((m) => m.MonthlyReportsComponent)
  },
  {
    path: 'reports/annual',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/reports/annual-reports.component').then((m) => m.AnnualReportsComponent)
  },
  {
    path: 'observations/workflow',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/observations/observation-workflow.component')
      .then((m) => m.ObservationWorkflowComponent)
  },
  { path: '**', redirectTo: '' }
];