import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/metra_api_client.dart';
import '../../api_config.dart';
import '../../features/home/metra_home.dart';

const metraSupabaseUrl = String.fromEnvironment('METRA_SUPABASE_URL');
const metraSupabasePublishableKey = String.fromEnvironment('METRA_SUPABASE_PUBLISHABLE_KEY');

class MetraSecureSessionStorage extends LocalStorage {
  MetraSecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'metra2027_supabase_auth_session';
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.read(key: _sessionKey) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}

bool get isMetraSupabaseConfigured => metraSupabaseUrl.startsWith('https://') && metraSupabasePublishableKey.isNotEmpty;
bool get isMetraApiConfigured => ApiConfig.isConfigured;

class MetraAuthGate extends StatefulWidget {
  const MetraAuthGate({super.key});
  @override
  State<MetraAuthGate> createState() => _MetraAuthGateState();
}
class _MetraAuthGateState extends State<MetraAuthGate> {
  late final SupabaseClient _supabase;
  late final MetraApiClient _api;
  StreamSubscription<AuthState>? _subscription;
  bool _signedIn = false;
  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _signedIn = _supabase.auth.currentSession != null;
    _api = MetraApiClient(accessTokenProvider: () async => _supabase.auth.currentSession?.accessToken);
    _subscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() => _signedIn = state.session != null);
    }, onError: (Object error, StackTrace stackTrace) {});
  }
  @override
  void dispose() { _subscription?.cancel(); _api.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _signedIn
      ? MetraHome(api: _api, userEmail: _supabase.auth.currentUser?.email,
          onSignOut: () => _supabase.auth.signOut())
      : const MetraLoginScreen();
}

class MetraLoginScreen extends StatefulWidget {
  const MetraLoginScreen({super.key});
  @override
  State<MetraLoginScreen> createState() => _MetraLoginScreenState();
}
class _MetraLoginScreenState extends State<MetraLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _requestPasswordReset() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || email.length > 254) {
      setState(() => _error = 'أدخل البريد الإلكتروني أولاً لاستلام رابط الاستعادة.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('إذا كان البريد مسجلاً، فسيصلك رابط استعادة كلمة المرور. تحقق من صندوق الوارد والبريد غير المرغوب فيه.'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on AuthException {
      if (mounted) setState(() => _error = 'تعذر إرسال طلب الاستعادة حالياً. تحقق من البريد وحاول لاحقاً.');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بخدمة استعادة كلمة المرور.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text);
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      final safe = message.contains('invalid login credentials') ? 'بيانات الدخول غير صحيحة.' :
        message.contains('email not confirmed') ? 'يجب تأكيد البريد الإلكتروني قبل الدخول.' :
        message.contains('too many requests') ? 'محاولات كثيرة. انتظر قليلاً.' :
        'تعذر تسجيل الدخول. تحقق من البيانات أو إعدادات الحساب.';
      if (mounted) setState(() => _error = safe);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بخدمة تسجيل الدخول.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.cloud_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'METRA 2027',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'سجّل الدخول بحسابك المعتمد للوصول إلى المحطات والرصد.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value?.trim().contains('@') ?? false)
                                  ? null
                                  : 'أدخل بريداً إلكترونياً صحيحاً',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            ),
                          ),
                          validator: (value) =>
                              (value?.isNotEmpty ?? false) ? null : 'أدخل كلمة المرور',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _signIn,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('تسجيل الدخول'),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: _busy ? null : _requestPasswordReset,
                            child: const Text('نسيت كلمة المرور؟'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'لا يتم إنشاء حسابات من التطبيق. اطلب تفعيل حسابك من مسؤول النظام.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MetraConfigurationScreen extends StatelessWidget {
  const MetraConfigurationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final missing = <String>[];
    if (!isMetraSupabaseConfigured) {
      missing.add('METRA_SUPABASE_URL و METRA_SUPABASE_PUBLISHABLE_KEY');
    }
    if (!isMetraApiConfigured) {
      missing.add('METRA_API_BASE_URL (عنوان API منشور يعمل عبر HTTPS)');
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings_suggest_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text('إعداد تطبيق METRA 2027',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('لا يمكن تشغيل التطبيق تشغيلياً قبل ضبط إعدادات الاتصال المطلوبة.',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text('الإعدادات الناقصة أو غير الصالحة:\n• ${missing.join('\n• ')}',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Text('استخدم عنوان API الحقيقي المنشور عبر HTTPS. لا تستخدم عنوان المحاكي الافتراضي، ولا تضع مفتاح service_role داخل تطبيق الهاتف.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
