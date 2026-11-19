import 'package:material_ui/material_ui.dart';

import '../auth/metra_access_context.dart';

/// Operator-facing full-page message when a screen is blocked.
class MetraPermissionDeniedPage extends StatelessWidget {
  const MetraPermissionDeniedPage({
    super.key,
    this.title = 'غير مصرح',
    this.message = MetraPermissionDeniedMessages.general,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFFB45309)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}
