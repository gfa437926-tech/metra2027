// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/metra_auth.dart';
import 'core/widgets/metra_ui.dart';

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
        title: 'METRA 2027',
        debugShowCheckedModeBanner: false,
        theme: buildMetraTheme(),
        home: isMetraSupabaseConfigured && isMetraApiConfigured
            ? const MetraAuthGate()
            : const MetraConfigurationScreen(),
      );
}
