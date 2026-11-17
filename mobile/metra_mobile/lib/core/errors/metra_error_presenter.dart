import '../api/metra_api_client.dart';

/// Central Arabic error mapping for connected screens.
///
/// Never surfaces stack traces, tokens, or internal exception details to operators.
class MetraErrorPresenter {
  const MetraErrorPresenter._();

  /// Maps any thrown object to a short Arabic operator message.
  static String messageFor(Object error) {
    if (error is MetraApiException) {
      return error.displayMessage;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة ثم أعد المحاولة.';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم. أعد المحاولة لاحقاً.';
    }
    return 'تعذر إتمام العملية. أعد المحاولة أو تواصل مع الدعم.';
  }

  /// Specialized copy for review decisions (approve / return).
  static String reviewDecisionMessage(MetraApiException error) {
    if (error.statusCode == 401) {
      return 'انتهت الجلسة. سجّل الدخول مجدداً ثم أعد المحاولة.';
    }
    if (error.statusCode == 403) {
      return 'ليست لديك صلاحية تنفيذ هذا القرار';
    }
    if (error.statusCode == 404) {
      return 'النشرة غير موجودة أو لم تعد متاحة.';
    }
    if (error.statusCode == 409) {
      return 'تمت معالجة النشرة مسبقاً أو تغيرت حالتها';
    }
    return error.displayMessage;
  }
}
