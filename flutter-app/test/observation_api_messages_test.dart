import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/observation_api_messages.dart';

void main() {
  test('submit maps 403 and 409', () {
    expect(observationSubmitErrorMessage(403), contains('صلاحية'));
    expect(observationSubmitErrorMessage(409), contains('تعارض'));
  });

  test('decision maps self-approval style 403', () {
    expect(observationDecisionErrorMessage(403), contains('اعتماد'));
  });

  test('resubmit maps returned-state 409', () {
    expect(observationResubmitErrorMessage(409), contains('مُرجَعة'));
  });
}
