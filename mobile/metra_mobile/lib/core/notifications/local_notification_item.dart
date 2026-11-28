
/// On-device notification item produced by local application events only.
class LocalNotificationItem {
  const LocalNotificationItem({
    required this.id,
    required this.titleAr,
    required this.bodyAr,
    required this.createdAt,
    required this.category,
    this.read = false,
    this.sourceKey,
    this.accountKey,
  });

  final String id;
  final String titleAr;
  final String bodyAr;
  final DateTime createdAt;
  final String category; // observation | review | fault | system
  final bool read;
  final String? sourceKey;
  final String? accountKey;

  LocalNotificationItem copyWith({bool? read}) => LocalNotificationItem(
        id: id,
        titleAr: titleAr,
        bodyAr: bodyAr,
        createdAt: createdAt,
        category: category,
        read: read ?? this.read,
        sourceKey: sourceKey,
        accountKey: accountKey,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'bodyAr': bodyAr,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'category': category,
        'read': read,
        'sourceKey': sourceKey,
        if (accountKey != null && accountKey!.isNotEmpty) 'accountKey': accountKey,
      };

  static LocalNotificationItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    if (raw.keys.any((key) => key is! String)) return null;

    final map = Map<String, Object?>.from(raw);
    final id = map['id'];
    final title = map['titleAr'];
    final body = map['bodyAr'];
    final createdAtRaw = map['createdAt'];
    final categoryRaw = map['category'];
    final readRaw = map['read'];
    final sourceKeyRaw = map['sourceKey'];
    final accountKeyRaw = map['accountKey'];

    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        body is! String ||
        body.trim().isEmpty ||
        createdAtRaw is! String ||
        (categoryRaw != null && categoryRaw is! String) ||
        (readRaw != null && readRaw is! bool) ||
        (sourceKeyRaw != null && sourceKeyRaw is! String) ||
        (accountKeyRaw != null && accountKeyRaw is! String)) {
      return null;
    }

    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;
    final category = categoryRaw as String? ?? 'system';
    final accountKey = (accountKeyRaw as String?)?.trim();

    return LocalNotificationItem(
      id: id,
      titleAr: title,
      bodyAr: body,
      createdAt: createdAt.toUtc(),
      category: category,
      read: readRaw as bool? ?? false,
      sourceKey: sourceKeyRaw as String?,
      accountKey: (accountKey == null || accountKey.isEmpty) ? null : accountKey,
    );
  }
}
