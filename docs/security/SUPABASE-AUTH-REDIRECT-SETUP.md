# METRA 2027 — Supabase Auth redirect configuration

- **Status:** Client-side redirect is implemented; Supabase Dashboard allow-list and real-device email-link verification remain external release gates.
- **Flutter URI:** `metra2027://auth-callback`
- **Angular web callback:** `/auth/reset-password` on the exact deployed application origin; local development URI is `http://localhost:4200/auth/reset-password`.
- **Android:** `flutter-app/android/app/src/main/AndroidManifest.xml` registers the VIEW/BROWSABLE intent filter.
- **iOS:** `flutter-app/ios/Runner/Info.plist` registers the `metra2027` URL scheme.
- **Client flow:** password recovery requests this redirect; `AuthChangeEvent.passwordRecovery` opens the new-password form; `updateUser(UserAttributes(password: ...))` saves the password.
- **Security:** no password or recovery token is written to logs or app storage by this feature; provider error details are redacted.

## Required Supabase Dashboard action

In the approved new Supabase project Auth URL configuration, add the exact URI below to Additional Redirect URLs:

`metra2027://auth-callback`

For Angular, add the exact test/prod origin plus `/auth/reset-password`. The production origin must be taken from the approved deployment environment; it is intentionally not guessed in this document. For local testing only, add `http://localhost:4200/auth/reset-password` to the test project's Additional Redirect URLs.

Do not change Site URL or add broad wildcards. Confirm that the production app identifier and scheme are approved before adding production URLs.

## Acceptance procedure

1. Use a controlled test account in the approved test environment.
2. Request password recovery from the Flutter login screen and from Angular `/forgot-password`.
3. Open the Flutter link on a device with the installed METRA app; open the Angular link in the browser.
4. Confirm Flutter receives the `passwordRecovery` auth event and Angular detects the recovery session at `/auth/reset-password`.
5. Verify minimum client validation, confirmation match, provider policy rejection, success, expired link and replayed link in both clients.
6. Confirm the new password can sign in and the account-state gate still runs before opening the operational workspace.
7. Verify no recovery token/password appears in logs, analytics or crash reports.

**No database migration, RLS, policy or key change is required for the client-side deep-link registration.** The allow-list update is an external Auth configuration change and has not been performed from this branch.


## Angular implementation note

Angular now exposes `/forgot-password` and `/auth/reset-password`, and the login screen links to the recovery request. The callback uses Supabase `detectSessionInUrl`; `updatePassword` requires a current recovery session. The Dashboard allow-list and real email-link verification remain external and unverified.
