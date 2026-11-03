import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/metra_auth.dart';

const _blue = Color(0xFF087CF0);
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
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: _blue),
      scaffoldBackgroundColor: const Color(0xFFF3F6FC)),
    home: isMetraSupabaseConfigured ? const MetraAuthGate() : const MetraConfigurationScreen());
}
