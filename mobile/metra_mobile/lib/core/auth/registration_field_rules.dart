/// Client-side field rules for registration request forms.
///
/// Does not call the network. Server remains authoritative for acceptance.
class RegistrationFieldRules {
  RegistrationFieldRules._();

  static final RegExp uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
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
    if (value.length > 80) return 'الاسم أطول من الحد المسموح';
    return null;
  }
}
