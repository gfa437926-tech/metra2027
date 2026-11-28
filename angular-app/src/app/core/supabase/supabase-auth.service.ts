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

  async signUpWithPassword(email: string, password: string): Promise<boolean> {
    if (!this.client) throw new Error('إعدادات Supabase العامة غير مكتملة.');
    const { data, error } = await this.client.auth.signUp({ email, password });
    if (error) throw new Error('تعذر إنشاء الحساب. تحقق من البريد الإلكتروني وسياسة كلمة المرور.');
    if (!data.user) throw new Error('لم يؤكد مزود الهوية إنشاء الحساب.');
    return Boolean(data.session?.access_token);
  }

  async signInWithPassword(email: string, password: string): Promise<void> {
    if (!this.client) throw new Error('إعدادات Supabase العامة غير مكتملة.');
    const { error } = await this.client.auth.signInWithPassword({ email, password });
    if (error) throw new Error('تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور وحالة الحساب.');
  }

  async getCurrentUserEmail(): Promise<string | null> {
    if (!this.client) return null;
    const { data, error } = await this.client.auth.getUser();
    if (error) throw new Error('تعذر التحقق من المستخدم الحالي.');
    return data.user?.email ?? null;
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
