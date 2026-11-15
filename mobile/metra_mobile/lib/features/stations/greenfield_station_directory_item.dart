/// Strict Flutter projection for the normalized greenfield station directory.
///
/// This parser deliberately accepts only the flat stations.directory.v1 contract.
/// It does not call an API or imply that the backend operation is enabled.
class GreenfieldStationDirectoryItem {
  const GreenfieldStationDirectoryItem({
    required this.id,
    required this.stationCode,
    required this.nameArabic,
    required this.nameEnglish,
    required this.stationTypeCode,
    required this.stationTypeNameArabic,
    required this.stationTypeNameEnglish,
    required this.approvalStatus,
    required this.operationalStatus,
    this.wmoIdentifier,
    this.latitude,
    this.longitude,
    this.elevationM,
    this.timezoneName,
    this.locationSource,
    this.horizontalAccuracyM,
  });

  final String id;
  final String stationCode;
  final String nameArabic;
  final String nameEnglish;
  final String stationTypeCode;
  final String stationTypeNameArabic;
  final String stationTypeNameEnglish;
  final String approvalStatus;
  final String operationalStatus;
  final String? wmoIdentifier;
  final double? latitude;
  final double? longitude;
  final double? elevationM;
  final String? timezoneName;
  final String? locationSource;
  final double? horizontalAccuracyM;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory GreenfieldStationDirectoryItem.fromJson(
      Map<String, dynamic> json) {
    String requiredText(String key, {int maxLength = 160}) {
      final value = json[key];
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > maxLength ||
          value.trim() != value) {
        throw FormatException('invalid_station_field:$key');
      }
      return value;
    }

    String? optionalText(String key, {int maxLength = 160}) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > maxLength ||
          value.trim() != value) {
        throw FormatException('invalid_station_field:$key');
      }
      return value;
    }

    double? optionalNumber(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num) throw FormatException('invalid_station_field:$key');
      final parsed = value.toDouble();
      if (!parsed.isFinite) throw FormatException('invalid_station_field:$key');
      return parsed;
    }

    final id = requiredText('id', maxLength: 36);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('invalid_station_id');
    }

    final approval = requiredText('approval_status', maxLength: 32);
    final operation = requiredText('operational_status', maxLength: 32);
    if (approval != 'approved' ||
        !const {'active', 'temporarily_closed'}.contains(operation)) {
      throw const FormatException('station_not_directory_visible');
    }

    final latitude = optionalNumber('latitude');
    final longitude = optionalNumber('longitude');
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw const FormatException('invalid_station_coordinates');
    }

    final accuracy = optionalNumber('horizontal_accuracy_m');
    if (accuracy != null && accuracy < 0) {
      throw const FormatException('invalid_station_accuracy');
    }

    return GreenfieldStationDirectoryItem(
      id: id,
      stationCode: requiredText('station_code', maxLength: 32),
      nameArabic: requiredText('name_ar'),
      nameEnglish: requiredText('name_en'),
      wmoIdentifier: optionalText('wmo_identifier', maxLength: 16),
      stationTypeCode: requiredText('station_type_code', maxLength: 32),
      stationTypeNameArabic: requiredText('station_type_name_ar'),
      stationTypeNameEnglish: requiredText('station_type_name_en'),
      approvalStatus: approval,
      operationalStatus: operation,
      latitude: latitude,
      longitude: longitude,
      elevationM: optionalNumber('elevation_m'),
      timezoneName: optionalText('timezone_name', maxLength: 64),
      locationSource: optionalText('location_source', maxLength: 64),
      horizontalAccuracyM: accuracy,
    );
  }

  static List<GreenfieldStationDirectoryItem> parseList(Object? value) {
    if (value is! List || value.length > 500) {
      throw const FormatException('invalid_station_directory_response');
    }
    final items = <GreenfieldStationDirectoryItem>[];
    final ids = <String>{};
    final codes = <String>{};
    for (final row in value) {
      if (row is! Map) {
        throw const FormatException('invalid_station_directory_response');
      }
      final item = GreenfieldStationDirectoryItem.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (!ids.add(item.id) || !codes.add(item.stationCode)) {
        throw const FormatException('duplicate_station_identity');
      }
      items.add(item);
    }
    return List.unmodifiable(items);
  }
}
