/**
 * Supabase public client configuration.
 * Provide values through your deployment environment/build configuration.
 * Never place a service_role key in browser code.
 */
export const supabaseConfig = {
  url: '',
  anonKey: ''
} as const;

export function isSupabaseConfigured(): boolean {
  return Boolean(supabaseConfig.url && supabaseConfig.anonKey);
}