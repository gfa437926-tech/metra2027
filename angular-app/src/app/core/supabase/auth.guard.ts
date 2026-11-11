import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { SupabaseAuthService } from './supabase-auth.service';
import { RegistrationSubmissionApiService } from '../api/registration-submission-api.service';

/**
 * Browser navigation guard only. The API and database policies remain the
 * authoritative authorization boundary for every protected operation.
 */
export const requireAuthenticatedUser: CanActivateFn = async (_route, state) => {
  const auth = inject(SupabaseAuthService);
  const router = inject(Router);

  try {
    const email = await auth.getCurrentUserEmail();
    return email
      ? true
      : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
  } catch {
    return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
  }
};


/**
 * Operational route gate. Authentication alone does not activate METRA access;
 * the server account-state read must explicitly return active. API authorization
 * remains the final authority for every operation.
 */
export const requireActiveMetraAccount: CanActivateFn = async (_route, state) => {
  const auth = inject(SupabaseAuthService);
  const registration = inject(RegistrationSubmissionApiService);
  const router = inject(Router);

  try {
    const email = await auth.getCurrentUserEmail();
    if (!email) {
      return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
    }
    const status = await registration.getMyStatus();
    if (status.account_state === 'active') return true;
    return router.createUrlTree(['/account'], {
      queryParams: { returnUrl: state.url, accountState: status.account_state ?? 'unknown' }
    });
  } catch {
    return router.createUrlTree(['/account'], {
      queryParams: { returnUrl: state.url, accountState: 'unavailable' }
    });
  }
};
