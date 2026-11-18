import 'package:material_ui/material_ui.dart';

/// Shared loading / empty / error panels for METRA screens (RTL-friendly).
///
/// Does not invent network behavior — callers pass messages and optional retry.
class MetraAsyncStatePanel extends StatelessWidget {
  const MetraAsyncStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool compact;

  factory MetraAsyncStatePanel.loading({String? message}) {
    return MetraAsyncStatePanel(
      icon: Icons.hourglass_empty,
      title: message ?? 'جاري التحميل…',
      subtitle: null,
      action: const Padding(
        padding: EdgeInsets.only(top: 16),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  factory MetraAsyncStatePanel.error({
    required String title,
    String? subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'إعادة المحاولة',
  }) {
    return MetraAsyncStatePanel(
      icon: Icons.cloud_off_outlined,
      title: title,
      subtitle: subtitle,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
    );
  }

  factory MetraAsyncStatePanel.empty({
    required String title,
    String? subtitle,
    IconData icon = Icons.inbox_outlined,
    Widget? action,
  }) {
    return MetraAsyncStatePanel(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 16.0 : 24.0;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 36 : 44, color: const Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
