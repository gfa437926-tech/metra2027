import { Routes } from '@angular/router';
import { requireActiveMetraAccount, requireAuthenticatedUser } from './core/supabase/auth.guard';

export const routes: Routes = [
  { path: 'reports/observation-status', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/reports/station-observation-status.component').then(m => m.StationObservationStatusComponent) },
  { path: 'admin/registration-review', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/admin/registration-review.component').then(m => m.RegistrationReviewComponent) },
  { path: 'admin/station-assignments', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/admin/station-assignment.component').then(m => m.StationAssignmentComponent) },
  { path: 'admin/manual-archive', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/admin/manual-archive.component').then(m => m.ManualArchiveComponent) },
  { path: 'stations/:stationId', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/stations/station-detail.component').then(m => m.StationDetailComponent) },
  { path: 'stations', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/stations/station-directory.component').then(m => m.StationDirectoryComponent) },
  { path: 'equipment-faults', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/maintenance/equipment-fault-workflow.component').then(m => m.EquipmentFaultWorkflowComponent) },
  { path: 'support-incidents', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/support/support-incident-workflow.component').then(m => m.SupportIncidentWorkflowComponent) },
  { path: 'ai', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/ai/ai-workspace.component').then(m => m.AiWorkspaceComponent) },
  { path: 'climatol', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/climatol/climatol-workspace.component').then(m => m.ClimatolWorkspaceComponent) },
  { path: 'aftn', canActivate: [requireActiveMetraAccount], loadComponent: () => import('./features/aftn/aftn-console.component').then(m => m.AftnConsoleComponent) },
  { path: 'account', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/account/account-profile.component').then(m => m.AccountProfileComponent) },
  { path: 'forgot-password', loadComponent: () => import('./features/auth/forgot-password.component').then(m => m.ForgotPasswordComponent) },
  { path: 'auth/reset-password', loadComponent: () => import('./features/auth/reset-password.component').then(m => m.ResetPasswordComponent) },
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
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/dashboard/dashboard.component')
      .then((m) => m.DashboardComponent)
  },
  {
    path: 'forecasting',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/forecasting/forecasting-center.component').then(m => m.ForecastingCenterComponent)
  },
  {
    path: 'phenomena/input',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/phenomena/phenomena-input.component')
      .then((m) => m.PhenomenaInputComponent)
  },
  {
    path: 'phenomena',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/phenomena/phenomena.component')
      .then((m) => m.PhenomenaComponent)
  },
  {
    path: 'reports/hourly',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/hourly-reports.component')
      .then((m) => m.HourlyReportsComponent)
  },
  {
    path: 'reports/rainfall',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/rainfall-reports.component')
      .then((m) => m.RainfallReportsComponent)
  },
  {
    path: 'reports/daily',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/daily-reports.component')
      .then((m) => m.DailyReportsComponent)
  },
  {
    path: 'reports/climate',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/climate-reports.component')
      .then((m) => m.ClimateReportsComponent)
  },
  {
    path: 'agriculture',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/agriculture/agriculture.component')
      .then((m) => m.AgricultureComponent)
  },
  {
    path: 'soil-temperature',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/soil/soil-temperature.component')
      .then((m) => m.SoilTemperatureComponent)
  },
  {
    path: 'users',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/users/users.component')
      .then((m) => m.UsersComponent)
  },
  {
    path: 'reports/monthly',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/monthly-reports.component').then((m) => m.MonthlyReportsComponent)
  },
  {
    path: 'reports/annual',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/reports/annual-reports.component').then((m) => m.AnnualReportsComponent)
  },
  {
    path: 'observations/workflow',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () => import('./features/observations/observation-workflow.component')
      .then((m) => m.ObservationWorkflowComponent)
  },
  {
    path: 'electronic-auditor',
    canActivate: [requireActiveMetraAccount],
    loadComponent: () =>
      import('./features/electronic-auditor/electronic-auditor-workspace.component').then(
        (m) => m.ElectronicAuditorWorkspaceComponent
      )
  },
  { path: '**', redirectTo: '' }
];