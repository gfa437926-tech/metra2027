/// Local-only validation semantics for rainfall / soil catalogue forms.
///
/// Does not call the network. Does not invent API fields.
/// Server persistence remains blocked until DB allow-list includes these types.
class RainfallSoilLocalRules {
  RainfallSoilLocalRules._();

  /// Interprets an optional decimal catalogue value.
  ///
  /// - null / blank → measurement not provided (must not be treated as zero)
  /// - finite 0 → recorded zero
  /// - finite > 0 or < 0 → recorded numeric value (sign checked by caller if needed)
  /// - non-numeric → invalid
  static DecimalFieldParse parseOptionalDecimal(Object? raw) {
    if (raw == null) {
      return const DecimalFieldParse.absent();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return const DecimalFieldParse.absent();
    }
    final value = num.tryParse(text);
    if (value == null || !value.isFinite) {
      return const DecimalFieldParse.invalid();
    }
    return DecimalFieldParse.present(value);
  }

  /// Rainfall: observationDate + agreement required; amounts optional.
  /// Missing rainAmount/snowDepth means unavailable, not zero rainfall.
  static Map<String, String> validateRainfall(Map<String, Object?> values) {
    final errors = <String, String>{};
    final date = values['observationDate']?.toString().trim() ?? '';
    if (date.isEmpty) {
      errors['observationDate'] = 'تاريخ الرصد مطلوب';
    }
    if (values['responsibilityAgreement'] != true) {
      errors['responsibilityAgreement'] = 'يجب الموافقة على الإقرار قبل المتابعة';
    }
    for (final id in ['rainAmount', 'snowDepth']) {
      final parsed = parseOptionalDecimal(values[id]);
      if (parsed.isInvalid) {
        errors[id] =
            'أدخل رقماً منتهياً وصالحاً، أو اترك الحقل فارغاً إن لم يتوفر القياس';
      } else if (parsed.isPresent && parsed.value! < 0) {
        errors[id] = 'لا تُقبل قيمة سالبة. اترك الحقل فارغاً إن لم يتوفر القياس';
      }
    }
    return errors;
  }

  /// Soil: observationDate + agreement required; depths optional decimals (°C).
  static Map<String, String> validateSoil(Map<String, Object?> values) {
    final errors = <String, String>{};
    final date = values['observationDate']?.toString().trim() ?? '';
    if (date.isEmpty) {
      errors['observationDate'] = 'تاريخ الرصد مطلوب';
    }
    if (values['responsibilityAgreement'] != true) {
      errors['responsibilityAgreement'] = 'يجب الموافقة على الإقرار قبل المتابعة';
    }
    for (final id in ['depth5', 'depth10', 'depth20', 'depth50']) {
      final parsed = parseOptionalDecimal(values[id]);
      if (parsed.isInvalid) {
        errors[id] =
            'أدخل رقماً منتهياً وصالحاً، أو اترك الحقل فارغاً إن لم يتوفر القياس';
      }
    }
    return errors;
  }
}

class DecimalFieldParse {
  const DecimalFieldParse._(this.kind, this.value);

  const DecimalFieldParse.absent() : this._(DecimalFieldParseKind.absent, null);
  const DecimalFieldParse.invalid() : this._(DecimalFieldParseKind.invalid, null);
  const DecimalFieldParse.present(num value) : this._(DecimalFieldParseKind.present, value);

  final DecimalFieldParseKind kind;
  final num? value;

  bool get isAbsent => kind == DecimalFieldParseKind.absent;
  bool get isInvalid => kind == DecimalFieldParseKind.invalid;
  bool get isPresent => kind == DecimalFieldParseKind.present;
  bool get isRecordedZero => isPresent && value == 0;
}

enum DecimalFieldParseKind { absent, invalid, present }
