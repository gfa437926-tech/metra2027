
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_item.dart';

/// Local notification feed — never invents server push traffic.
class LocalNotificationStore extends ChangeNotifier {
  LocalNotificationStore._();

  static final LocalNotificationStore instance = LocalNotificationStore._();

  static const _prefsKey = 'metra2027.local_notifications.v1';
  static const _maxItems = 100;

  final List<LocalNotificationItem> _items = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get unreadCount => _items.where((i) => !i.read).length;
  List<LocalNotificationItem> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final parsed = LocalNotificationItem.tryParse(item);
            if (parsed != null) _items.add(parsed);
          }
          _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      }
    } catch (_) {
      _items.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_items.map((e) => e.toJson()).toList(growable: false)),
      );
    } catch (_) {}
  }

  void add({
    required String titleAr,
    required String bodyAr,
    required String category,
    String? sourceKey,
  }) {
    final item = LocalNotificationItem(
      id: 'n-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      titleAr: titleAr,
      bodyAr: bodyAr,
      createdAt: DateTime.now().toUtc(),
      category: category,
      sourceKey: sourceKey,
    );
    _items.insert(0, item);
    while (_items.length > _maxItems) {
      _items.removeLast();
    }
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void markRead(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0 || _items[index].read) return;
    _items[index] = _items[index].copyWith(read: true);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void markAllRead() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void clearAll() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  List<LocalNotificationItem> filtered(String filter) {
    switch (filter) {
      case 'unread':
        return _items.where((e) => !e.read).toList(growable: false);
      case 'read':
        return _items.where((e) => e.read).toList(growable: false);
      default:
        return items;
    }
  }
}
