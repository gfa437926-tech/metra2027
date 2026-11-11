import { Routes } from '@angular/router';
import { requireAuthenticatedUser } from './core/supabase/auth.guard';

export const routes: Routes = [
  { path: 'reports/observation-status', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/reports/station-observation-status.component').then(m => m.StationObservationStatusComponent) },
  { path: 'admin/registration-review', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/admin/registration-review.component').then(m => m.RegistrationReviewComponent) },
  { path: 'admin/station-assignments', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/admin/station-assignment.component').then(m => m.StationAssignmentComponent) },
  { path: 'admin/manual-archive', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/admin/manual-archive.component').then(m => m.ManualArchiveComponent) },
  { path: 'stations/:stationId', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/stations/station-detail.component').then(m => m.StationDetailComponent) },
  { path: 'stations', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/stations/station-directory.component').then(m => m.StationDirectoryComponent) },
  { path: 'equipment-faults', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/maintenance/equipment-fault-workflow.component').then(m => m.EquipmentFaultWorkflowComponent) },
  { path: 'support-incidents', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/support/support-incident-workflow.component').then(m => m.SupportIncidentWorkflowComponent) },
  { path: 'ai', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/ai/ai-workspace.component').then(m => m.AiWorkspaceComponent) },
  { path: 'climatol', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/climatol/climatol-workspace.component').then(m => m.ClimatolWorkspaceComponent) },
  { path: 'aftn', canActivate: [requireAuthenticatedUser], loadComponent: () => import('./features/aftn/aftn-console.component').then(m => m.AftnConsoleComponent) },
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
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/dashboard/dashboard.component')
      .then((m) => m.DashboardComponent)
  },
  {
    path: 'forecasting',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () => import('./features/forecasting/forecasting-center.component').then(m => m.ForecastingCenterComponent)
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
  {
    path: 'electronic-auditor',
    canActivate: [requireAuthenticatedUser],
    loadComponent: () =>
      import('./features/electronic-auditor/electronic-auditor-workspace.component').then(
        (m) => m.ElectronicAuditorWorkspaceComponent
      )
  },
  { path: '**', redirectTo: '' }
];