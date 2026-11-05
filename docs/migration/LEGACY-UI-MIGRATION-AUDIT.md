# Legacy UI Migration Audit — METRA 2027

**Branch:** `work/legacy-ui-migration-audit`  
**Baseline:** `main` at `8094da69ac5e9ee210ec08532e49eebc1ba4e3fb`  
**Purpose:** Track complete migration of legacy web screens into the Angular web app and the independent Flutter mobile app without modifying legacy source files or database schemas.

## Guardrails

- Preserve every legacy HTML file as a read-only reference until its replacement is reviewed.
- Keep one shared navigation shell per client; do not duplicate sidebars inside feature pages.
- Reuse the approved new station catalogue only. Do not import legacy station records.
- Keep privileged database access in ASP.NET Core. Never expose Supabase service-role credentials to clients.
- Do not apply or modify Supabase schema/migrations until the user reviews and approves the schema.
- A screen is not considered migrated merely because a route or placeholder exists: its layout, fields, validation, actions, permissions, responsive behavior, and API integration must be checked.

## Legacy source inventory and target mapping

| Legacy source | Existing Angular target | Current migration assessment | Flutter target |
|---|---|---|---|
| `main.html` | Dashboard component at `/` | Dashboard exists; visual/functional parity audit required | Home overview exists; parity incomplete |
| `index.html` | Login/dashboard entry flow | Entry behavior needs comparison with legacy | Auth gate exists; parity incomplete |
| `rec-main.html` | Observation workflow / dashboard | Exact purpose and links need inspection | Observation review exists; parity incomplete |
| `hourly_reports.html` | `/reports/hourly` | Component exists; field/action parity audit required | Not implemented as a full screen |
| `climate_hourly_reports.html`, `h_climate_send.html` | `/reports/climate` | Component exists; source variants must be reconciled | Not implemented |
| `daily.html`, `daily_reports.html` | `/reports/daily` | Component exists; compare both legacy variants | Not implemented |
| `rainfall_reports.html` | `/reports/rainfall` | Component exists; parity audit required | Not implemented |
| `phenomena.html`, `weather_phenomena.html` | `/phenomena`, `/phenomena/input` | View and input routes exist; compare both sources | Not implemented |
| `soil-send.html`, `soil_temperature.html` | `/soil-temperature` | Component exists; entry/report flows need comparison | Not implemented |
| `agricultural_reports.html` | `/agriculture` | Component exists; parity audit required | Not implemented |
| `weather_analytics.html` | No confirmed dedicated route | Missing/unclear; inspect source and define destination | Not implemented |
| `fix.html` | No confirmed dedicated route | Missing: observation equipment fault reporting/management | Not implemented |
| `fix-tel.html` | No confirmed dedicated route | Missing: telecom fault reporting/management | Not implemented |
| `it.html` | No confirmed dedicated route | Missing: IT/software fault reporting/management | Not implemented |
| `it-maneger.html` | Users/authority area only partially related | Missing: IT manager workspace; do not conflate with user admin | Not implemented |
| `manag-net.html` | No confirmed dedicated route | Missing: network management workspace | Not implemented |
| `telecom-manager.html` | No confirmed dedicated route | Missing: telecom manager workspace | Not implemented |
| `workshop-manager.html` | No confirmed dedicated route | Missing: workshop/maintenance manager workspace | Not implemented |
| `manager-dashboard.html` | Dashboard component only partially related | Missing/unclear: management dashboard and role-specific content | Not implemented |
| `sidebar.html` | Shared navigation in `app.component.ts` | One shell exists, but its entries do not yet cover every legacy module | Flutter NavigationBar exists; mobile navigation parity incomplete |

## Existing client implementation snapshot

### Angular web
The current route table contains login, registration, dashboard, phenomena input/view, hourly, rainfall, daily, climate, agriculture, soil temperature, users, monthly, annual, and observation workflow. Monthly/annual are additional current routes; their presence does not prove a corresponding legacy screen was migrated.

The shared Angular shell currently exposes only a subset of the legacy sidebar destinations. Dedicated destinations for fault reporting, IT/network/telecom/workshop management, and weather analytics are not confirmed.

### Flutter mobile
The current app has a home overview, station directory, and observation review. Reports/analytics currently use an informational placeholder. The mobile app therefore does not yet represent the complete legacy application and needs a planned feature-by-feature port with mobile-appropriate interaction patterns.

## Work plan and acceptance criteria

1. **Recover and inspect the full RAR archive.** Enumerate every HTML, JS, CSS, image, JSON, and supporting file, including nested folders. Compare that inventory with the root-level legacy HTML files listed above. Do not modify or delete the archive.
2. **Build a screen specification per source page.** Record title, purpose, user roles, fields, validation, calculations, tables/charts, buttons, exports, dependencies, and responsive behavior.
3. **Complete Angular parity.** Implement missing modules and reconcile duplicate/variant legacy pages. Use a single sidebar and shared design tokens/components. Connect actions only to documented ASP.NET API endpoints.
4. **Port all approved workflows to Flutter.** Provide mobile layouts for entry, review, reports, faults, and management features according to role permissions; do not simply embed web pages.
5. **Verify both clients.** Build, lint/analyze, test, inspect navigation, and run role-based end-to-end checks. Track every source screen as Not started / In progress / Implemented / Verified.
6. **Production integration.** Configure HTTPS API origin, CORS, runtime configuration, and secrets only after the target hosting environment is selected and verified.

## Current status

- Inventory from tracked root-level HTML files: **24 files identified**.
- Angular: core weather/report feature components exist, but legacy parity is not verified and several management/fault modules are absent or unclear.
- Flutter: foundational shell, station directory, and observation review exist; most legacy feature screens remain to be ported.
- RAR archive: present in repository root, but its nested contents have not yet been extracted and audited.
- Database: no schema changes made as part of this audit.

**Important:** This is an inventory and migration plan, not a claim that the legacy UI migration is complete.
