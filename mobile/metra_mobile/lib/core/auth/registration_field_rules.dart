/// Client-side field rules for registration request forms.
///
/// Does not call the network. Server remains authoritative for acceptance.
class RegistrationFieldRules {
  RegistrationFieldRules._();

  static final RegExp uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final RegExp _email = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  /// Returns Arabic error message or null when valid.
  static String? stationId(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'مطلوب';
    if (!uuid.hasMatch(value)) {
      return 'أدخل معرّف محطة بصيغة UUID صحيحة';
    }
    return null;
  }

  static String? phone(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'مطلوب';
    final digits = value.replaceAll(RegExp(r'[\s\-+()]'), '');
    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) {
      return 'أدخل رقم هاتف صالحاً (8–15 رقماً)';
    }
    return null;
  }

  static String? requiredName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'مطلوب';
    if (value.length < 2) return 'الاسم قصير جداً';
    if (value.length > 80) return 'الاسم أطول من الحد المسموح';
    return null;
  }

  /// Optional email: empty is allowed; non-empty must be a plausible address.
  static String? optionalEmail(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.length > 254) return 'البريد أطول من الحد المسموح';
    if (!_email.hasMatch(value)) {
      return 'أدخل بريداً إلكترونياً صالحاً';
    }
    return null;
  }

  /// Login / account password length and whitespace rules (client-side only).
  static String? password(String? raw) {
    final value = raw ?? '';
    if (value.isEmpty) return 'مطلوب';
    if (value.trim().isEmpty) return 'كلمة المرور لا يمكن أن تكون مسافات فقط';
    if (value.length < 8) return 'كلمة المرور أقصر من 8 أحرف';
    if (value.length > 128) return 'كلمة المرور أطول من الحد المسموح';
    return null;
  }

  /// Confirm password must match the primary password when both are provided.
  static String? confirmPassword(String? password, String? confirmation) {
    final primary = password ?? '';
    final confirm = confirmation ?? '';
    if (confirm.isEmpty) return 'مطلوب';
    if (primary != confirm) return 'كلمتا المرور غير متطابقتين';
    return null;
  }
}
