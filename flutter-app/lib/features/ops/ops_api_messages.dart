/// Arabic messages for station-scoped equipment fault and support incident APIs.
String opsSubmitErrorMessage(int statusCode, {required String resourceAr}) {
  return switch (statusCode) {
    400 => 'بيانات $resourceAr غير صالحة. راجع الحقول وأعد المحاولة.',
    401 => 'انتهت الجلسة أو يلزم تسجيل الدخول.',
    403 => 'ليست لديك صلاحية تسجيل $resourceAr لهذه المحطة.',
    409 => 'تعارض حالة أو تكرار غير مسموح.',
    503 => 'الخدمة غير متاحة حالياً لهذه المحطة.',
    _ => 'تعذر إرسال $resourceAr ($statusCode).',
  };
}

String opsTransitionErrorMessage(int statusCode, {required String resourceAr}) {
  return switch (statusCode) {
    400 => 'انتقال الحالة غير صالح لـ$resourceAr.',
    401 => 'انتهت الجلسة أو يلزم تسجيل الدخول.',
    403 => 'ليست لديك صلاحية تحديث حالة $resourceAr لهذه المحطة.',
    404 => '$resourceAr غير موجود ضمن نطاق هذه المحطة.',
    409 => 'لا يمكن تطبيق هذا الانتقال على الحالة الحالية.',
    503 => 'الخدمة غير متاحة حالياً.',
    _ => 'تعذر تحديث حالة $resourceAr ($statusCode).',
  };
}

String opsDetailErrorMessage(int statusCode, {required String resourceAr}) {
  return switch (statusCode) {
    401 => 'انتهت الجلسة أو يلزم تسجيل الدخول.',
    403 => 'ليست لديك صلاحية عرض تفاصيل $resourceAr.',
    404 => '$resourceAr غير موجود ضمن نطاق هذه المحطة.',
    503 => 'الخدمة غير متاحة حالياً.',
    _ => 'تعذر جلب التفاصيل ($statusCode).',
  };
}
