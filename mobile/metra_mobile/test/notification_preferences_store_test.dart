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
    expect(prefs.anyEnabled, isFalse);
    expect(prefs.enabledCount, 0);
  });

  test('updates are independent per preference flag', () {
    final store = NotificationPreferencesStore.instance;
    store.setObservationAlerts(true);
    expect(store.current.observationAlerts, isTrue);
    expect(store.current.reviewAlerts, isFalse);
    expect(store.current.faultAlerts, isFalse);
    expect(store.current.enabledCount, 1);

    store.setReviewAlerts(true);
    store.setFaultAlerts(true);
    expect(store.current.observationAlerts, isTrue);
    expect(store.current.reviewAlerts, isTrue);
    expect(store.current.faultAlerts, isTrue);
    expect(store.current.anyEnabled, isTrue);
    expect(store.current.enabledCount, 3);

    store.setObservationAlerts(false);
    expect(store.current.observationAlerts, isFalse);
    expect(store.current.reviewAlerts, isTrue);
    expect(store.current.enabledCount, 2);
  });

  test('reset clears session preferences', () {
    final store = NotificationPreferencesStore.instance;
    store.setFaultAlerts(true);
    store.reset();
    expect(store.current.faultAlerts, isFalse);
    expect(store.current.anyEnabled, isFalse);
  });

  test('notifyListeners fires on real changes only', () {
    final store = NotificationPreferencesStore.instance;
    var count = 0;
    void listener() => count++;
    store.addListener(listener);
    store.setObservationAlerts(true);
    store.setObservationAlerts(true); // no-op
    store.setReviewAlerts(true);
    store.removeListener(listener);
    expect(count, 2);
  });
}
