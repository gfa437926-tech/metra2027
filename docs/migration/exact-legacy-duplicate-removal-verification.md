# Verification: exact legacy duplicate removal (PR #12)

Branch: `chore/remove-exact-legacy-duplicates`  
Base: `work/legacy-ui-migration-audit` @ `21f6795`  
Tip: `ab2bcff`  

## Scope

Removed **79** root-level files whose **Git blob SHA** matched a file in
[`metra-old`](https://github.com/gfa437926-tech/metra-old) (path may differ;
content identical). No Angular, Flutter, Backend, database, or test trees were
deleted.

## Method

1. Diff `work/legacy-ui-migration-audit...chore/remove-exact-legacy-duplicates`
2. For each deleted path, take blob SHA from the base tree
3. Match against all blobs in `metra-old` HEAD
4. Result: **79 / 79 exact matches**, **0 mismatches**

## Dependency scan

Searched `angular-app/`, `backend/`, `mobile/`, `database/`, `docs/`, `.github/`,
`supabase/` for imports or path references to deleted basenames.

Findings:
- **No runtime imports** of deleted legacy HTML/JS/CSS from modern apps
- Mentions in **documentation / comments only** (migration audits, validator
  comments referencing historical `hourly-send.js`, footnote on daily report
  form alignment)
- `deploy-pages.yml` references Angular `dist/.../index.html` (SPA shell), not
  the deleted root `index.html`

## Intentionally retained root files (not exact duplicates)

| File | Reason |
|---|---|
| `soil-send.js` | Blob differs from metra-old counterparts |
| `soil-validation.js` | Blob differs |
| `user-data.js` | Blob differs |
| `weather_phenomena.html` | Blob differs |
| `supabase-config.js` | Blob differs from all metra-old copies |

These must **not** be deleted under the exact-match policy without a separate
review.

## Safety constraints respected

- `metra-old` not modified
- No Supabase schema changes
- No merge to `main`
- Modern app entrypoints remain Angular / Flutter / .NET

## Follow-up

- Removed root `.rar` archive from the cleanup branch (not required by Angular/Flutter/.NET).
