import 'package:flutter/foundation.dart';

/// Local-only notification preference flags.
///
/// Does not claim push delivery. Values stay on-device for the session until a
/// real notification service is contracted. Never stores tokens or secrets.
class NotificationPreferences {
  const NotificationPreferences({
    this.observationAlerts = false,
    this.reviewAlerts = false,
    this.faultAlerts = false,
  });

  final bool observationAlerts;
  final bool reviewAlerts;
  final bool faultAlerts;

  NotificationPreferences copyWith({
    bool? observationAlerts,
    bool? reviewAlerts,
    bool? faultAlerts,
  }) =>
      NotificationPreferences(
        observationAlerts: observationAlerts ?? this.observationAlerts,
        reviewAlerts: reviewAlerts ?? this.reviewAlerts,
        faultAlerts: faultAlerts ?? this.faultAlerts,
      );

  bool get anyEnabled =>
      observationAlerts || reviewAlerts || faultAlerts;

  int get enabledCount =>
      (observationAlerts ? 1 : 0) +
      (reviewAlerts ? 1 : 0) +
      (faultAlerts ? 1 : 0);
}

/// Session-scoped store for local notification preferences.
///
/// Extends [ChangeNotifier] so screens can react without polling.
class NotificationPreferencesStore extends ChangeNotifier {
  NotificationPreferencesStore._();

  static final NotificationPreferencesStore instance =
      NotificationPreferencesStore._();

  NotificationPreferences _current = const NotificationPreferences();

  NotificationPreferences get current => _current;

  void update(NotificationPreferences next) {
    if (_current.observationAlerts == next.observationAlerts &&
        _current.reviewAlerts == next.reviewAlerts &&
        _current.faultAlerts == next.faultAlerts) {
      return;
    }
    _current = next;
    notifyListeners();
  }

  void setObservationAlerts(bool value) {
    if (_current.observationAlerts == value) return;
    _current = _current.copyWith(observationAlerts: value);
    notifyListeners();
  }

  void setReviewAlerts(bool value) {
    if (_current.reviewAlerts == value) return;
    _current = _current.copyWith(reviewAlerts: value);
    notifyListeners();
  }

  void setFaultAlerts(bool value) {
    if (_current.faultAlerts == value) return;
    _current = _current.copyWith(faultAlerts: value);
    notifyListeners();
  }

  /// Test helper.
  void reset() {
    if (!_current.anyEnabled &&
        !_current.observationAlerts &&
        !_current.reviewAlerts &&
        !_current.faultAlerts) {
      return;
    }
    _current = const NotificationPreferences();
    notifyListeners();
  }
}
