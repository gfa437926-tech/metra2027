import 'package:flutter/material.dart';

class MetraAccountAccessStateScreen extends StatelessWidget {
  const MetraAccountAccessStateScreen({
    super.key,
    required this.title,
    required this.message,
    this.reason,
    this.onRetry,
    this.onSignOut,
  });

  final String title;
  final String message;
  final String? reason;
  final VoidCallback? onRetry;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.gpp_bad_outlined, size: 52),
                      const SizedBox(height: 16),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                      if (reason != null && reason!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('ملاحظة الحالة: ${reason!.trim()}',
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      if (onRetry != null)
                        OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة التحقق'),
                        ),
                      if (onSignOut != null)
                        FilledButton.icon(
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('تسجيل الخروج'),
                        ),
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
