/// Supported paper/mechanical recorder families in the METRA domain contract.
enum MetraRecorderKind {
  thermograph,
  hygrograph,
  barograph,
  pluviograph,
}

/// Typed capture metadata. Actor, authority, storage keys and upload URLs are
/// deliberately absent: the API derives trust-sensitive values server-side.
class RecordCaptureRequest {
  const RecordCaptureRequest({
    required this.stationId,
    required this.instrumentId,
    required this.recorderKind,
    required this.captureStart,
    required this.captureEnd,
    required this.paperTimeZoneId,
    required this.chartType,
    this.chartScale,
  });

  final String stationId;
  final String instrumentId;
  final MetraRecorderKind recorderKind;
  final DateTime captureStart;
  final DateTime captureEnd;
  final String paperTimeZoneId;
  final String chartType;
  final Map<String, Object?>? chartScale;

  bool get hasValidInterval => captureEnd.isAfter(captureStart);

  Map<String, Object?> toJson() => {
        'stationId': stationId,
        'instrumentId': instrumentId,
        'recorderKind': recorderKind.name,
        'captureStart': captureStart.toUtc().toIso8601String(),
        'captureEnd': captureEnd.toUtc().toIso8601String(),
        'paperTimeZoneId': paperTimeZoneId,
        'chartType': chartType,
        if (chartScale != null) 'chartScale': chartScale,
      };
}
