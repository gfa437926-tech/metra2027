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

  /// Strict calendar-date validation; rejects normalized invalid dates.
  static bool isValidObservationDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return parsed.year.toString().padLeft(4, '0') == value.substring(0, 4) &&
        parsed.month.toString().padLeft(2, '0') == value.substring(5, 7) &&
        parsed.day.toString().padLeft(2, '0') == value.substring(8, 10);
  }

  /// True when the calendar day is after today (local).
  static bool isFutureObservationDate(String value) {
    if (!isValidObservationDate(value)) return false;
    final parsed = DateTime.parse(value);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return day.isAfter(today);
  }

  static void _requireObservationDate(
    Map<String, Object?> values,
    Map<String, String> errors,
  ) {
    final date = values['observationDate']?.toString().trim() ?? '';
    if (date.isEmpty) {
      errors['observationDate'] = 'تاريخ الرصد مطلوب';
    } else if (!isValidObservationDate(date)) {
      errors['observationDate'] = 'أدخل تاريخاً صالحاً بصيغة YYYY-MM-DD';
    } else if (isFutureObservationDate(date)) {
      errors['observationDate'] = 'لا يُقبل تاريخ رصد في المستقبل';
    }
  }

  /// Rainfall: observationDate + agreement required; amounts optional.
  /// Missing rainAmount/snowDepth means unavailable, not zero rainfall.
  static Map<String, String> validateRainfall(Map<String, Object?> values) {
    final errors = <String, String>{};
    _requireObservationDate(values, errors);
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
    _requireObservationDate(values, errors);
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
  const DecimalFieldParse.invalid()
      : this._(DecimalFieldParseKind.invalid, null);
  const DecimalFieldParse.present(num value)
      : this._(DecimalFieldParseKind.present, value);

  final DecimalFieldParseKind kind;
  final num? value;

  bool get isAbsent => kind == DecimalFieldParseKind.absent;
  bool get isInvalid => kind == DecimalFieldParseKind.invalid;
  bool get isPresent => kind == DecimalFieldParseKind.present;
  bool get isRecordedZero => isPresent && value == 0;
}

enum DecimalFieldParseKind { absent, invalid, present }
