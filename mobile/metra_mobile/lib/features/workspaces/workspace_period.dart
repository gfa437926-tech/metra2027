/// Calendar-day check for local workspace filters.
/// Returns an Arabic message when the end day is before the start day.
/// A missing bound is not an error: the user has not finished the range.
String? workspacePeriodError(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  if (endDay.isBefore(startDay)) {
    return 'نهاية الفترة أسبق من بدايتها. صحّح التاريخين. لن يُشغَّل أي تحليل أو تقرير.';
  }
  return null;
}
