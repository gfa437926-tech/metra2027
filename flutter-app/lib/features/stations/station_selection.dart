import '../../core/api/metra_api_client.dart';

/// Formats the selected-station banner for home/ops (no invented names).
String formatSelectedStationLabel(StationDirectoryItem station) {
  final name = station.nameArabic.trim();
  final code = station.localCode.trim();
  if (name.isEmpty && code.isEmpty) return station.id;
  if (code.isEmpty) return name;
  if (name.isEmpty) return code;
  return '$name ($code)';
}
