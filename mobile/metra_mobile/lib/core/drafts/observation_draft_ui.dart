import 'package:material_ui/material_ui.dart';

import 'observation_draft_store.dart';

/// Shared draft presentation and confirmations for observation entry screens.
///
/// Keeps hourly / daily / phenomenon / catalogue forms consistent without
/// inventing server persistence. Drafts remain session-local and station-scoped.
class ObservationDraftUi {
  ObservationDraftUi._();

  static const discardActionLabel = 'تجاهل المسودة المحلية';
  static const discardedSnackMessage = 'تم تجاهل المسودة المحلية';
  static const bannerPrefix = 'مسودة محلية فقط — لم تُرسل إلى الخادم';

  static String formatSavedAtLocal(DateTime savedAtUtc) {
    final local = savedAtUtc.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Blue info strip shown above the form when a non-empty draft is restored.
  static Widget? banner(ObservationDraft? draft) {
    if (draft == null || draft.isEmpty) return null;
    final stamp = formatSavedAtLocal(draft.savedAt);
    final count = draft.values.length;
    return Material(
      color: const Color(0xFFE8F4FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.edit_note, color: Color(0xFF087CF0)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$bannerPrefix · $count حقلاً · حُفظت $stamp',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks the operator before discarding local values. Returns true only on confirm.
  static Future<bool> confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تجاهل المسودة المحلية؟'),
          content: const Text(
            'ستُفقد القيم المحفوظة محلياً لهذه المحطة وهذا النموذج. '
            'لن يُرسل أي شيء إلى الخادم.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إبقاء المسودة'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تجاهل المسودة'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  static void showDiscardedSnack(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(discardedSnackMessage)),
    );
  }
}
