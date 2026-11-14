# C9 — Git Delivery and Sync Plan

## Current tips
| Side | SHA |
|------|-----|
| Local | `5cf17288455ea9a795283e72809766394d24a5e3` |
| Remote `work/backend-db-integration-phase` | `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12` |

Local contains Backend C2–C8, DB baseline/proposals, delivery docs.  
Remote is `main` + Flutter C7 workflow + widget_test fixes.

## Safe transfer (NO force push) — **requires explicit approval before any remote write**

1. **Backup:** tag local tip `pre-sync-c9-local` and note remote tip SHA.
2. **Fetch:** `git fetch origin work/backend-db-integration-phase`.
3. **Integrate without rewrite:**
   - Preferred: `git merge origin/work/backend-db-integration-phase` on local branch (may produce merge commit for workflow/widget_test).
   - Alternative: rebase local onto remote only if conflicts are trivial and history remains linear; still no force.
4. **Resolve expected conflicts:**
   - `.github/workflows/flutter-c7-ci.yml` (keep analyze `--no-fatal-infos` + concurrency=1).
   - `mobile/metra_mobile/test/widget_test.dart` (keep Navigator.pop + CheckboxListTile fixes).
5. **Verify locally:** `dotnet test` (264), Path N, then optional CI trigger.
6. **Push:** `git push origin work/backend-db-integration-phase` (non-force only).
7. **Post-check:** remote SHA == local tip; Actions Flutter C7 still green; list commits include Backend series.

## Restore point
- Local: `5cf1728…`
- Remote: `c6d9a9f…`

## Explicitly NOT performed in C9
Push, PR, merge to main, force push, branch delete.
