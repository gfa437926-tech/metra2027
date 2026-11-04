import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { SupabaseAuthService } from './supabase-auth.service';

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
