class ObservationValidationIssue {
  const ObservationValidationIssue({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;

  factory ObservationValidationIssue.fromJson(Map<String, dynamic> json) {
    return ObservationValidationIssue(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? 'قيمة غير صالحة.',
    );
  }
}

class ObservationValidationResult {
  const ObservationValidationResult({
    required this.isValid,
    required this.issues,
  });

  final bool isValid;
  final List<ObservationValidationIssue> issues;

  factory ObservationValidationResult.fromJson(Map<String, dynamic> json) {
    final rawIssues = json['issues'];
    if (rawIssues is! List) {
      throw const FormatException('Invalid validation response: issues must be a list.');
    }
    return ObservationValidationResult(
      isValid: json['isValid'] as bool? ?? false,
      issues: rawIssues
          .whereType<Map<String, dynamic>>()
          .map(ObservationValidationIssue.fromJson)
          .toList(growable: false),
    );
  }
}
