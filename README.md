## Verification status

Latest backend CI run: [Backend build #766](https://github.com/gfa437926-tech/metra2027/actions/runs/41778894826) passed on commit `0f0cc07e037d9828ade09ed0ab3c887abf73396d`. It verified the authority access lifecycle contract (including scheduled approved access), built the API, passed domain/API tests, and built the production container image. Client CI and GitHub Pages deployment have also passed on a prior main commit; rerun them after relevant client changes.

A successful CI run or container publish is not the same as a live API deployment. Production readiness requires a deployed HTTPS API, configured secrets and CORS, successful `/health` and `/ready` checks, and authenticated end-to-end tests. Real identity and authority-access tests, administrator onboarding, and verified missing station coordinates remain outstanding.
