/// Local-only notification preference flags.
///
/// Does not claim push delivery. Values stay on-device until a real notification
/// service is contracted. Never stores tokens or secrets.
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
}

/// Session-scoped store for local notification preferences.
class NotificationPreferencesStore {
  NotificationPreferencesStore._();

  static final NotificationPreferencesStore instance =
      NotificationPreferencesStore._();

  NotificationPreferences _current = const NotificationPreferences();

  NotificationPreferences get current => _current;

  void update(NotificationPreferences next) {
    _current = next;
  }

  void setObservationAlerts(bool value) {
    _current = _current.copyWith(observationAlerts: value);
  }

  void setReviewAlerts(bool value) {
    _current = _current.copyWith(reviewAlerts: value);
  }

  void setFaultAlerts(bool value) {
    _current = _current.copyWith(faultAlerts: value);
  }

  /// Test helper.
  void reset() {
    _current = const NotificationPreferences();
  }
}
