/**
 * Public runtime configuration. Values are injected by the deployment host.
 * Never place a Supabase service_role key in this file or browser configuration.
 */
declare global {
  interface Window {
    __METRA_CONFIG__?: {
      apiBaseUrl?: string;
      supabaseUrl?: string;
      supabaseAnonKey?: string;
    };
  }
}

const runtime = typeof window === 'undefined' ? undefined : window.__METRA_CONFIG__;

export const metraConfig = {
  apiBaseUrl: (runtime?.apiBaseUrl ?? '').replace(/\/$/, ''),
  supabaseUrl: runtime?.supabaseUrl ?? '',
  supabaseAnonKey: runtime?.supabaseAnonKey ?? ''
} as const;

export function isApiConfigured(): boolean {
  return /^https:\/\//i.test(metraConfig.apiBaseUrl);
}

export function isSupabaseConfigured(): boolean {
  return /^https:\/\//i.test(metraConfig.supabaseUrl) && Boolean(metraConfig.supabaseAnonKey);
}
