
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_item.dart';

/// Local notification feed — never invents server push traffic.
class LocalNotificationStore extends ChangeNotifier {
  LocalNotificationStore._();

  @visibleForTesting
  LocalNotificationStore.forTesting();

  static final LocalNotificationStore instance = LocalNotificationStore._();

  static const _prefsKey = 'metra2027.local_notifications.v1';
  static const _maxItems = 100;

  final List<LocalNotificationItem> _items = [];
  bool _loaded = false;
  bool _loading = false;
  Future<void>? _loadFuture;
  Future<void> _persistTail = Future<void>.value();
  final Set<String> _dirtyIds = <String>{};
  final List<String?> _pendingClearAccountKeys = <String?>[];
  int _writeGeneration = 0;
  bool _diskTrusted = true;
  String? _activeAccountKey;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  String? get activeAccountKey => _activeAccountKey;

  void setActiveAccountKey(String? key) {
    final next = key?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_activeAccountKey == normalized) return;
    _activeAccountKey = normalized;
    notifyListeners();
  }
  int get unreadCount => _visible.where((i) => !i.read).length;
  List<LocalNotificationItem> get items =>
      List.unmodifiable(_visible.toList(growable: false));

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          var payloadTrusted = true;
          if (decoded is List) {
            for (final item in decoded) {
              final parsed = LocalNotificationItem.tryParse(item);
              if (parsed == null) {
                payloadTrusted = false;
                continue;
              }
              if (_dirtyIds.contains(parsed.id)) continue;
              final existingIndex = _items.indexWhere((e) => e.id == parsed.id);
              if (existingIndex < 0) {
                _items.add(parsed);
              } else if (parsed.createdAt.isAfter(_items[existingIndex].createdAt)) {
                _items[existingIndex] = parsed;
              }
            }
          } else {
            payloadTrusted = false;
          }
          _diskTrusted = payloadTrusted;
          _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } catch (_) {
          _diskTrusted = false;
        }
      }
    } catch (_) {
      _diskTrusted = false;
    } finally {
      _loaded = true;
      _loading = false;
      var clearedAny = false;
      for (final accountKey in _pendingClearAccountKeys) {
        final removed = _items
            .where((item) => _isVisibleForAccount(item, accountKey))
            .toList(growable: false);
        if (removed.isEmpty) continue;
        _dirtyIds.addAll(removed.map((item) => item.id));
        _items.removeWhere((item) => _isVisibleForAccount(item, accountKey));
        clearedAny = true;
      }
      _pendingClearAccountKeys.clear();
      notifyListeners();
      if (clearedAny && _diskTrusted) {
        // ignore: unawaited_futures
        _persist();
      }
    }
  }

  Future<void> _persist() {
    final generation = ++_writeGeneration;
    final write = _persistTail.then((_) async {
      await ensureLoaded();
      if (!_diskTrusted || generation != _writeGeneration) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload = _items.map((e) => e.toJson()).toList(growable: false);
        if (generation != _writeGeneration) return;
        await prefs.setString(_prefsKey, jsonEncode(payload));
        if (generation != _writeGeneration) return;
        _dirtyIds.clear();
        _diskTrusted = true;
      } catch (_) {
        // Keep the in-memory feed available; never claim disk persistence.
      }
    });
    _persistTail = write.catchError((_) {});
    return write;
  }

  @visibleForTesting
  Future<void> flushForTesting() => _persist();

  bool _isVisibleForAccount(LocalNotificationItem item, String? accountKey) {
    if (accountKey != null) return item.accountKey == accountKey;
    return item.accountKey == null || item.accountKey!.isEmpty;
  }

  bool _isVisible(LocalNotificationItem item) =>
      _isVisibleForAccount(item, _activeAccountKey);

  void add({
    required String titleAr,
    required String bodyAr,
    required String category,
    String? sourceKey,
  }) {
    // Avoid flooding identical events for the same local source in one minute.
    if (sourceKey != null && sourceKey.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final dup = _items.any(
        (e) =>
            e.accountKey == _activeAccountKey &&
            e.sourceKey == sourceKey &&
            now.difference(e.createdAt).inSeconds < 60,
      );
      if (dup) return;
    }
    final item = LocalNotificationItem(
      id: 'n-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      titleAr: titleAr,
      bodyAr: bodyAr,
      createdAt: DateTime.now().toUtc(),
      category: category,
      sourceKey: sourceKey,
      accountKey: _activeAccountKey,
    );
    _items.insert(0, item);
    _dirtyIds.add(item.id);
    while (_items.length > _maxItems) {
      _items.removeLast();
    }
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void markRead(String id) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0 || _items[index].read || !_isVisible(_items[index])) return;
    _items[index] = _items[index].copyWith(read: true);
    _dirtyIds.add(id);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void markAllRead() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_isVisible(_items[i]) && !_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        _dirtyIds.add(_items[i].id);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void clearAll() {
    if (!_loaded) {
      // Preserve the intent across the initial disk read; otherwise old
      // notifications can reappear after an early clear action.
      _pendingClearAccountKeys.add(_activeAccountKey);
      // ignore: unawaited_futures
      ensureLoaded();
      return;
    }
    final removed = _items.where(_isVisible).toList(growable: false);
    if (removed.isEmpty) return;
    _dirtyIds.addAll(removed.map((item) => item.id));
    _items.removeWhere(_isVisible);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  Iterable<LocalNotificationItem> get _visible sync* {
    for (final item in _items) {
      if (_isVisible(item)) yield item;
    }
  }

  List<LocalNotificationItem> filtered(String filter) {
    final visible = _visible.toList(growable: false);
    switch (filter) {
      case 'unread':
        return visible.where((e) => !e.read).toList(growable: false);
      case 'read':
        return visible.where((e) => e.read).toList(growable: false);
      default:
        return List.unmodifiable(visible);
    }
  }
}
