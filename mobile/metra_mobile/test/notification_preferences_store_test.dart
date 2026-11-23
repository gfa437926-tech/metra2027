import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/preferences/notification_preferences_store.dart';

void main() {
  setUp(() {
    NotificationPreferencesStore.instance.reset();
  });

  test('defaults are all false (no silent opt-in)', () {
    final prefs = NotificationPreferencesStore.instance.current;
    expect(prefs.observationAlerts, isFalse);
    expect(prefs.reviewAlerts, isFalse);
    expect(prefs.faultAlerts, isFalse);
  });

  test('updates are independent per preference flag', () {
    final store = NotificationPreferencesStore.instance;
    store.setObservationAlerts(true);
    expect(store.current.observationAlerts, isTrue);
    expect(store.current.reviewAlerts, isFalse);
    expect(store.current.faultAlerts, isFalse);

    store.setReviewAlerts(true);
    store.setFaultAlerts(true);
    expect(store.current.observationAlerts, isTrue);
    expect(store.current.reviewAlerts, isTrue);
    expect(store.current.faultAlerts, isTrue);

    store.setObservationAlerts(false);
    expect(store.current.observationAlerts, isFalse);
    expect(store.current.reviewAlerts, isTrue);
  });

  test('reset clears session preferences', () {
    final store = NotificationPreferencesStore.instance;
    store.setFaultAlerts(true);
    store.reset();
    expect(store.current.faultAlerts, isFalse);
  });
}
