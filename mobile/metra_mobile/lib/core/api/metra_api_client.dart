import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../auth/metra_access_context.dart';

const metraApiBaseUrl = ApiConfig.baseUrl;

class MetraApiException implements Exception {
  const MetraApiException(this.statusCode, this.code, {this.userMessage});
  final int statusCode;
  final String code;
  final String? userMessage;

  String get displayMessage {
    if (userMessage != null && userMessage!.trim().isNotEmpty) {
      return userMessage!.trim();
    }
    return switch (code) {
      'api_not_configured' =>
        'عنوان خدمة METRA غير مضبوط. راجع إعدادات الاتصال.',
      'authentication_required' => 'انتهت الجلسة أو يلزم تسجيل الدخول مجدداً.',
      'invalid_pagination' => 'معاملات التصفح غير صالحة.',
      'invalid_station_type' => 'نوع المحطة غير مدعوم.',
      'invalid_station_id' => 'معرف المحطة غير صالح.',
      'invalid_observation_id' => 'معرف الرصدة غير صالح.',
      'invalid_limit' => 'حد النتائج غير صالح.',
      'invalid_observation_decision' => 'قرار المراجعة غير مدعوم.',
      'decision_note_required' => 'يجب إدخال سبب الإرجاع للتصحيح.',
      'invalid_decision_note' => 'نص الملاحظة غير صالح.',
      'invalid_registration_decision' => 'قرار التسجيل غير مدعوم.',
      'registration_rejection_reason_required' =>
        'يجب إدخال سبب رفض طلب التسجيل.',
      'invalid_registration_note' => 'نص ملاحظة التسجيل غير صالح.',
      'unsupported_observation_validation' =>
        'نوع الرصد غير مدعوم للتحقق حالياً.',
      'unsupported_observation_type' => 'نوع الرصد غير مدعوم للإرسال حالياً.',
      'invalid_idempotency_key' => 'مفتاح منع التكرار غير صالح.',
      'station_directory_limit_exceeded' =>
        'تجاوز دليل المحطات الحد الأقصى المسموح.',
      'network_unavailable' =>
        'تعذر الاتصال بالخادم. تحقق من الشبكة ثم أعد المحاولة.',
      'timeout' => 'انتهت مهلة الاتصال بالخادم. أعد المحاولة لاحقاً.',
      'request_failed' when statusCode == 401 || statusCode == 403 =>
        'انتهت صلاحية الجلسة أو لا تملك صلاحية تنفيذ هذه العملية.',
      'request_failed' when statusCode == 404 => 'المورد المطلوب غير موجود.',
      'request_failed' when statusCode == 409 =>
        'تعارض في الطلب. قد تكون الرصدة مُرسلة مسبقاً.',
      'request_failed' when statusCode >= 500 =>
        'حدث خطأ في الخادم. حاول لاحقاً أو أبلغ الدعم.',
      'request_failed' => 'تعذر إتمام الطلب. تحقق من الاتصال وأعد المحاولة.',
      _ => 'تعذر إتمام العملية. أعد المحاولة أو تواصل مع الدعم.',
    };
  }

  @override
  String toString() => 'MetraApiException($statusCode, $code)';
}

class MetraValidationIssue {
  const MetraValidationIssue({required this.field, required this.message});
  final String field;
  final String message;
}

class MetraObservationValidation {
  const MetraObservationValidation({
    required this.isValid,
    required this.issues,
  });
  final bool isValid;
  final List<MetraValidationIssue> issues;
}
