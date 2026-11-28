# FLT-003 — Shared adaptive Flutter navigation

- **UTC timestamp:** 2026-11-11T15:15:55.715Z
- **Task:** FLT-003
- **Status:** In progress — implementation committed; automated execution and visual acceptance remain pending.
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `main`

## Objective

Establish one reusable navigation surface for the Flutter app that adapts to narrow mobile layouts and wider desktop/tablet layouts without duplicating the application shell.

## Changes committed

1. Added `mobile/metra_mobile/lib/core/widgets/metra_adaptive_navigation.dart`.
   - Uses a bottom `NavigationBar` below the 760 logical-pixel breakpoint.
   - Uses a labelled `NavigationRail` at and above the breakpoint.
   - Keeps page content in one shared child slot and forwards destination selection.
   - Explicitly does not infer authorization or roles.
2. Updated `mobile/metra_mobile/lib/features/home/metra_home.dart` to use the shared adaptive navigation component while retaining the existing five destinations and indexed page state.
3. Added a widget test source case that checks the compact and wide navigation variants.

## Commits

- Navigation component: `907b1b599d346b43fd41f55c7453af100f62c181`
- Home shell integration: `d7dee25c4e751b335b8bbd5553d999569e9eb011`
- Widget test source: `908e442a88dc022e48e562635e3d4f8884410710`

## Verification

- GitHub source files were fetched again after the changes to inspect the committed contents.
- **Not run:** `flutter analyze`, `flutter test`, Android/iOS builds, runtime visual checks, accessibility checks.
- The new widget test is committed as source only; it is not reported as passing.
- No .NET or database tests were run.

## Authorization and API finding

The reviewed ASP.NET Core API exposes authority catalogue, membership/permission queues and audit endpoints, but the reviewed routes do not expose a consolidated current-user access-context endpoint suitable for constructing role/permission-filtered navigation. Therefore this round deliberately retains the current five destinations and does not invent client-side role rules. A server-authoritative access-context contract and its permission tests are still required before hiding/showing operational destinations by role or individual grant.

## Remaining work

1. Run Flutter analyzer and widget tests in a Flutter-enabled environment; repair any compile/test failures.
2. Verify RTL behavior and the breakpoint on actual mobile/tablet/desktop viewports.
3. Define and test a least-privilege current-user access-context API contract before role-aware destination visibility.
4. Replace placeholder destinations only after their requirements, API contracts and domain validations are traced.
5. Continue the complete Flutter screen inventory and requirements archive inspection (FLT-001 remains blocked).

## Data and security statement

- New Supabase database: unchanged.
- Legacy database: untouched.
- No migration, RLS, policy, RPC or secret changes.
- No direct operational database writes were added to Flutter.
