enum StationSourceKind { classic, automatic }

class StationCatalogueItem {
  const StationCatalogueItem({
    required this.sourceKind,
    required this.sourceRecordId,
    required this.displayName,
    required this.sourceStationType,
    required this.sourceCode,
    required this.latitude,
    required this.longitude,
    required this.elevationMetres,
  });

  final StationSourceKind sourceKind;
  final String sourceRecordId;
  final String displayName;
  final String? sourceStationType;
  final String? sourceCode;
  final double? latitude;
  final double? longitude;
  final double? elevationMetres;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory StationCatalogueItem.fromJson(Map<String, dynamic> json) {
    final sourceKind = _parseSourceKind(json['sourceKind']);
    final id = json['sourceRecordId'];
    final name = json['displayName'];
    final latitude = _optionalNumber(json['latitude'], 'latitude');
    final longitude = _optionalNumber(json['longitude'], 'longitude');
    final elevation = _optionalNumber(json['elevationMetres'], 'elevationMetres');
    final sourceType = _optionalText(json['sourceStationType'], 'sourceStationType', 128);
    final sourceCode = _optionalText(json['sourceCode'], 'sourceCode', 128);

    if (id is! String || !RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(id) ||
        name is! String || name.trim().isEmpty || name.length > 256 ||
        _hasControl(name) ||
        (latitude == null) != (longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180)) ||
        (elevation != null && (elevation < -500 || elevation > 10000))) {
      throw const FormatException('Invalid station catalogue item.');
    }

    return StationCatalogueItem(
      sourceKind: sourceKind,
      sourceRecordId: id,
      displayName: name,
      sourceStationType: sourceType,
      sourceCode: sourceCode,
      latitude: latitude,
      longitude: longitude,
      elevationMetres: elevation,
    );
  }

  static StationSourceKind _parseSourceKind(Object? value) {
    if (value == 0 || value == 'Classic' || value == 'classic') {
      return StationSourceKind.classic;
    }
    if (value == 1 || value == 'Automatic' || value == 'automatic') {
      return StationSourceKind.automatic;
    }
    throw const FormatException('Unknown station source kind.');
  }

  static double? _optionalNumber(Object? value, String field) {
    if (value == null) return null;
    if (value is num && value.toDouble().isFinite) return value.toDouble();
    throw FormatException('Invalid $field.');
  }

  static String? _optionalText(Object? value, String field, int maxLength) {
    if (value == null) return null;
    if (value is String && value.length <= maxLength && !_hasControl(value)) {
      return value;
    }
    throw FormatException('Invalid $field.');
  }

  static bool _hasControl(String value) =>
      value.codeUnits.any((unit) => unit < 32 || (unit >= 127 && unit <= 159));
}

class StationCataloguePage {
  const StationCataloguePage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<StationCatalogueItem> items;
  final bool hasMore;
  final String? nextCursor;

  factory StationCataloguePage.fromJson(
    Map<String, dynamic> json, {
    required int requestedPageSize,
    String? requestedCursor,
  }) {
    final rawItems = json['items'];
    final hasMore = json['hasMore'];
    final rawCursor = json['nextCursor'];
    if (rawItems is! List || rawItems.length > requestedPageSize ||
        hasMore is! bool ||
        (hasMore && (rawItems.isEmpty || rawCursor is! String || rawCursor.trim().isEmpty)) ||
        (!hasMore && rawCursor != null) ||
        (rawCursor != null &&
          (rawCursor is! String || rawCursor.isEmpty || rawCursor.length > 2048 ||
           rawCursor.trim() != rawCursor || rawCursor == requestedCursor ||
           rawCursor.codeUnits.any((unit) => unit < 32 || (unit >= 127 && unit <= 159))))) {
      throw const FormatException('Invalid station catalogue page.');
    }

    final items = rawItems.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid station catalogue item.');
      }
      return StationCatalogueItem.fromJson(item);
    }).toList(growable: false);

    final identities = <String>{};
    for (final item in items) {
      if (!identities.add('${item.sourceKind.name}:${item.sourceRecordId}')) {
        throw const FormatException('Duplicate station source identity.');
      }
    }

    return StationCataloguePage(
      items: List.unmodifiable(items),
      hasMore: hasMore,
      nextCursor: rawCursor as String?,
    );
  }
}
