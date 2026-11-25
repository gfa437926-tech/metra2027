import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/metra_auth.dart';
import 'core/theme/metra_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isMetraSupabaseConfigured) {
    await Supabase.initialize(
      url: metraSupabaseUrl,
      publishableKey: metraSupabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: MetraSecureSessionStorage(),
      ),
    );
  }
  runApp(const MetraApp());
}
class MetraApp extends StatelessWidget {
  const MetraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'METRA 2027', debugShowCheckedModeBanner: false,
    theme: MetraTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    // Required temporarily because flutter_map still uses SDK Material types.
    // ignore: deprecated_member_use
    builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    home: isMetraSupabaseConfigured && isMetraApiConfigured
        ? const MetraAuthGate()
        : const MetraConfigurationScreen());
}
