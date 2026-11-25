/// Local calendar-day helpers for workspace period filters.
///
/// Pure functions only. No network. Used to gate local UI actions and
/// surface honest Arabic messages when a range cannot be used for analysis
/// or reports even in offline/local mode.

/// Returns an Arabic error when the selected period is invalid.
///
/// A missing bound is not an error: the user has not finished the range.
/// Rejects inverted ranges, future end days, and spans longer than 5 years
/// so local tooling never pretends to run unbounded historical jobs.
String? workspacePeriodError(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  if (endDay.isBefore(startDay)) {
    return 'نهاية الفترة أسبق من بدايتها. صحّح التاريخين. لن يُشغَّل أي تحليل أو تقرير.';
  }
  final today = DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  if (endDay.isAfter(todayDay)) {
    return 'نهاية الفترة في المستقبل. اختر يوماً حتى اليوم الحالي فقط.';
  }
  final days = endDay.difference(startDay).inDays;
  if (days > 1825) {
    // ~5 years inclusive span limit for local-only analysis UI.
    return 'الفترة أطول من خمس سنوات. قلّص النطاق قبل أي تحليل محلي.';
  }
  return null;
}

/// Inclusive calendar-day count, or null when the range is incomplete/invalid.
int? workspacePeriodDayCount(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  if (workspacePeriodError(start, end) != null) return null;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  return endDay.difference(startDay).inDays + 1;
}

/// True when both bounds are set and the period passes [workspacePeriodError].
bool workspacePeriodIsReady(DateTime? start, DateTime? end) {
  if (start == null || end == null) return false;
  return workspacePeriodError(start, end) == null;
}
