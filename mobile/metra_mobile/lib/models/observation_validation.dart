class ObservationValidationIssue {
  const ObservationValidationIssue({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;

  factory ObservationValidationIssue.fromJson(Map<String, dynamic> json) {
    final field = json['field'];
    final message = json['message'];
    if (field is! String || field.trim().isEmpty || message is! String || message.trim().isEmpty) {
      throw const FormatException('Invalid validation issue: field and message are required.');
    }
    return ObservationValidationIssue(
      field: field,
      message: message,
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
    final valid = json['isValid'];
    final rawIssues = json['issues'];
    if (valid is! bool || rawIssues is! List) {
      throw const FormatException('Invalid validation response: isValid and issues are required.');
    }
    final issues = <ObservationValidationIssue>[];
    for (final rawIssue in rawIssues) {
      if (rawIssue is! Map<String, dynamic>) {
        throw const FormatException('Invalid validation response: each issue must be an object.');
      }
      issues.add(ObservationValidationIssue.fromJson(rawIssue));
    }
    if (valid && issues.isNotEmpty) {
      throw const FormatException('Invalid validation response: a valid result cannot contain issues.');
    }
    if (!valid && issues.isEmpty) {
      throw const FormatException('Invalid validation response: an invalid result must contain issues.');
    }
    return ObservationValidationResult(
      isValid: valid,
      issues: List.unmodifiable(issues),
    );
  }
}
