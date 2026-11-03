import { Injectable } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { isSupabaseConfigured, metraConfig } from './supabase.config';

/** Owns the browser-safe Supabase client. Only the public anon key is accepted. */
@Injectable({ providedIn: 'root' })
export class SupabaseAuthService {
  private readonly client: SupabaseClient | null = isSupabaseConfigured()
    ? createClient(metraConfig.supabaseUrl, metraConfig.supabaseAnonKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      })
    : null;

  get isConfigured(): boolean {
    return this.client !== null;
  }

  async signInWithPassword(email: string, password: string): Promise<void> {
    if (!this.client) throw new Error('إعدادات Supabase العامة غير مكتملة.');
    const { error } = await this.client.auth.signInWithPassword({ email, password });
    if (error) throw new Error('تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور وحالة الحساب.');
  }

  async getAccessToken(): Promise<string | null> {
    if (!this.client) return null;
    const { data, error } = await this.client.auth.getSession();
    if (error) throw new Error('تعذر قراءة جلسة الدخول الحالية.');
    return data.session?.access_token ?? null;
  }

  async signOut(): Promise<void> {
    if (!this.client) return;
    const { error } = await this.client.auth.signOut();
    if (error) throw new Error('تعذر إنهاء جلسة الدخول.');
  }
}
