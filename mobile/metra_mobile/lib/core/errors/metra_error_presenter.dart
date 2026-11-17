import '../api/metra_api_client.dart';

/// Central Arabic error mapping for connected screens.
///
/// Never surfaces stack traces, tokens, or internal exception details to operators.
class MetraErrorPresenter {
  const MetraErrorPresenter._();

  /// Maps any thrown object to a short Arabic operator message.
  static String messageFor(Object error) {
    if (error is MetraApiException) {
      return forApiException(error);
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection')) {
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة ثم أعد المحاولة.';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'انتهت مهلة الاتصال بالخادم. أعد المحاولة لاحقاً.';
    }
    return 'تعذر إتمام العملية. أعد المحاولة أو تواصل مع الدعم.';
  }

  /// Status-aware mapping for [MetraApiException].
  static String forApiException(MetraApiException error) {
    if (error.userMessage != null && error.userMessage!.trim().isNotEmpty) {
      return error.userMessage!.trim();
    }
    // Prefer specialized code messages when not the generic request_failed bucket.
    if (error.code != 'request_failed' && error.code.isNotEmpty) {
      return error.displayMessage;
    }

    return switch (error.statusCode) {
      400 || 422 => 'البيانات المرسلة غير صالحة. راجع الحقول وأعد المحاولة.',
      401 => 'انتهت الجلسة أو يلزم تسجيل الدخول مجدداً.',
      403 => 'لا تملك صلاحية تنفيذ هذه العملية.',
      404 => 'المورد المطلوب غير موجود أو لم يعد متاحاً.',
      409 => 'تعارض في الطلب. قد تكون العملية نُفذت مسبقاً.',
      429 => 'تم تجاوز حد الطلبات. انتظر قليلاً ثم أعد المحاولة.',
      >= 500 => 'حدث خطأ في الخادم. حاول لاحقاً أو أبلغ الدعم.',
      _ => error.displayMessage,
    };
  }

  /// Observation submit (hourly / daily / phenomenon).
  static String submitMessage(MetraApiException error) {
    if (error.statusCode == 409) {
      return 'تعارض في الإرسال. قد تكون الرصدة مُرسلة مسبقاً.';
    }
    if (error.statusCode == 403) {
      return 'لا تملك صلاحية إرسال أرصاد لهذه المحطة.';
    }
    if (error.statusCode == 401) {
      return 'انتهت الجلسة. سجّل الدخول مجدداً ثم أعد الإرسال.';
    }
    return forApiException(error);
  }

  /// Review decisions (approve / return).
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
    return forApiException(error);
  }

  /// Queue / list load (review screen, station admin observations tab).
  static String queueLoadMessage(Object error) {
    if (error is MetraApiException) {
      if (error.statusCode == 401) {
        return 'يرجى تسجيل الدخول أولاً';
      }
      if (error.statusCode == 403) {
        return 'ليس لديك صلاحية مراجعة نشرات هذه المحطة';
      }
      if (error.statusCode == 404) {
        return 'طابور المراجعة غير متاح لهذه المحطة.';
      }
      return forApiException(error);
    }
    return messageFor(error);
  }

  /// Station registration review (admin).
  static String registrationDecisionMessage(MetraApiException error) {
    return switch (error.statusCode) {
      401 => 'انتهت الجلسة. سجّل الدخول مجدداً.',
      403 => 'لا تملك صلاحية مراجعة طلبات هذه المحطة.',
      404 => 'طلب التسجيل غير موجود.',
      409 => 'تم اتخاذ قرار مسبقاً على هذا الطلب.',
      503 => 'خدمة مراجعة التسجيل غير متاحة حالياً.',
      _ => forApiException(error),
    };
  }
}
