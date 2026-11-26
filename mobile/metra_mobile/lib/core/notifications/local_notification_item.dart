
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
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final title = map['titleAr']?.toString();
    final body = map['bodyAr']?.toString();
    final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}');
    final category = map['category']?.toString() ?? 'system';
    if (id == null ||
        id.isEmpty ||
        title == null ||
        title.isEmpty ||
        body == null ||
        body.isEmpty ||
        createdAt == null) {
      return null;
    }
    final accountKey = map['accountKey']?.toString().trim();
    return LocalNotificationItem(
      id: id,
      titleAr: title,
      bodyAr: body,
      createdAt: createdAt.toUtc(),
      category: category,
      read: map['read'] == true,
      sourceKey: map['sourceKey']?.toString(),
      accountKey: (accountKey == null || accountKey.isEmpty) ? null : accountKey,
    );
  }
}
