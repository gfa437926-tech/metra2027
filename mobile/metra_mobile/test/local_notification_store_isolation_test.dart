import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/notifications/local_notification_item.dart';
import 'package:metra_mobile/core/notifications/local_notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed persisted notification fields are rejected without coercion', () {
    final valid = <String, Object?>{
      'id': 'valid-id',
      'titleAr': 'عنوان',
      'bodyAr': 'محتوى',
      'createdAt': '2026-11-27T12:00:00.000Z',
      'category': 'system',
      'read': false,
      'sourceKey': null,
      'accountKey': 'account-a',
    };

    expect(LocalNotificationItem.tryParse(valid), isNotNull);
    for (final malformed in <Map<String, Object?>>[
      {...valid, 'id': 42},
      {...valid, 'titleAr': false},
      {...valid, 'bodyAr': 9},
      {...valid, 'createdAt': 1764244800},
      {...valid, 'category': <String>[]},
      {...valid, 'read': 'true'},
      {...valid, 'sourceKey': 12},
      {...valid, 'accountKey': <String, String>{}},
      {...valid, 'id': '   '},
    ]) {
      expect(LocalNotificationItem.tryParse(malformed), isNull);
    }
  });

  test('legacy notification without optional fields keeps safe defaults', () {
    final parsed = LocalNotificationItem.tryParse({
      'id': 'legacy-id',
      'titleAr': 'عنوان قديم',
      'bodyAr': 'محتوى قديم',
      'createdAt': '2026-11-27T12:00:00.000Z',
    });

    expect(parsed, isNotNull);
    expect(parsed!.category, 'system');
    expect(parsed.read, isFalse);
    expect(parsed.sourceKey, isNull);
    expect(parsed.accountKey, isNull);
  });

  test('early writes preserve disk records and account clear is isolated', () async {
    final accountA = LocalNotificationItem(
      id: 'notification-a',
      titleAr: 'إشعار أ',
      bodyAr: 'محتوى أ',
      createdAt: DateTime.utc(2026, 11, 20),
      category: 'system',
      accountKey: 'account-a',
    );
    final accountB = LocalNotificationItem(
      id: 'notification-b',
      titleAr: 'إشعار ب',
      bodyAr: 'محتوى ب',
      createdAt: DateTime.utc(2026, 11, 21),
      category: 'system',
      accountKey: 'account-b',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1':
          jsonEncode([accountA.toJson(), accountB.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    final loading = store.ensureLoaded();
    store.add(
      titleAr: 'إشعار جديد',
      bodyAr: 'تم إنشاؤه قبل اكتمال التحميل',
      category: 'system',
    );
    await loading;
    await store.flushForTesting();

    expect(store.items.every((item) => item.accountKey == 'account-a'), isTrue);
    store.setActiveAccountKey('account-b');
    expect(store.items.map((item) => item.id), contains('notification-b'));
    expect(store.items, hasLength(1));

    store.clearAll();
    await store.flushForTesting();

    final prefs = await SharedPreferences.getInstance();
    final rows = jsonDecode(
      prefs.getString('metra2027.local_notifications.v1')!,
    ) as List;
    final ids = rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'])
        .toSet();
    expect(ids, containsAll(['notification-a']));
    expect(ids, isNot(contains('notification-b')));
    expect(ids.length, 2); // account A's old and newly-created notifications.
  });

  test('concurrent callers share the same initial notification load', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalNotificationStore.forTesting();

    await Future.wait([store.ensureLoaded(), store.ensureLoaded()]);

    expect(store.isLoaded, isTrue);
    expect(store.isLoading, isFalse);
  });

  test('same source event is deduplicated only within its account', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalNotificationStore.forTesting();
    await store.ensureLoaded();

    store.setActiveAccountKey('account-a');
    store.add(
      titleAr: 'حدث أ',
      bodyAr: 'المصدر نفسه',
      category: 'observation',
      sourceKey: 'observation-123',
    );
    store.setActiveAccountKey('account-b');
    store.add(
      titleAr: 'حدث ب',
      bodyAr: 'المصدر نفسه',
      category: 'observation',
      sourceKey: 'observation-123',
    );

    expect(store.items, hasLength(1));
    expect(store.items.single.accountKey, 'account-b');
    store.setActiveAccountKey('account-a');
    expect(store.items, hasLength(1));
    expect(store.items.single.accountKey, 'account-a');
  });
  test('future-dated source event outside deduplication window does not block new event', () async {
    final futureEvent = LocalNotificationItem(
      id: 'future-source-event',
      titleAr: 'حدث مستقبلي',
      bodyAr: 'توقيت مستقبلي',
      createdAt: DateTime.now().toUtc().add(const Duration(minutes: 2)),
      category: 'observation',
      sourceKey: 'observation-future-clock',
      accountKey: 'account-a',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1': jsonEncode([futureEvent.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    await store.ensureLoaded();
    store.add(
      titleAr: 'حدث جديد',
      bodyAr: 'يجب ألا يمنع توقيت مستقبلي بعيد الإضافة',
      category: 'observation',
      sourceKey: 'observation-future-clock',
    );

    expect(store.items, hasLength(2));
    expect(store.items.first.id, isNot('future-source-event'));
  });

  test('clear before initial load removes persisted items for the active account', () async {
    final accountA = LocalNotificationItem(
      id: 'early-clear-a',
      titleAr: 'إشعار أ',
      bodyAr: 'محتوى أ',
      createdAt: DateTime.utc(2026, 11, 20),
      category: 'system',
      accountKey: 'account-a',
    );
    final accountB = LocalNotificationItem(
      id: 'early-clear-b',
      titleAr: 'إشعار ب',
      bodyAr: 'محتوى ب',
      createdAt: DateTime.utc(2026, 11, 21),
      category: 'system',
      accountKey: 'account-b',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1':
          jsonEncode([accountA.toJson(), accountB.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    store.clearAll();
    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.items, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final rows = jsonDecode(
      prefs.getString('metra2027.local_notifications.v1')!,
    ) as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map<String, dynamic>)['id'], 'early-clear-b');
  });

  test('notification added before initial load deduplicates persisted source', () async {
    final existing = LocalNotificationItem(
      id: 'persisted-source-event',
      titleAr: 'حدث محفوظ',
      bodyAr: 'إشعار سابق',
      createdAt: DateTime.now().toUtc().subtract(const Duration(seconds: 20)),
      category: 'observation',
      sourceKey: 'observation-duplicate-1',
      accountKey: 'account-a',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1': jsonEncode([existing.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    store.add(
      titleAr: 'حدث جديد',
      bodyAr: 'نفس مصدر الحدث',
      category: 'observation',
      sourceKey: 'observation-duplicate-1',
    );
    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.items, hasLength(1));
    expect(store.items.single.id, isNot('persisted-source-event'));
    expect(store.items.single.titleAr, 'حدث جديد');
  });

  test('mark all read before initial load updates only the active account', () async {
    final accountA = LocalNotificationItem(
      id: 'unread-a',
      titleAr: 'إشعار أ',
      bodyAr: 'محتوى أ',
      createdAt: DateTime.utc(2026, 11, 26),
      category: 'system',
      accountKey: 'account-a',
    );
    final accountB = LocalNotificationItem(
      id: 'unread-b',
      titleAr: 'إشعار ب',
      bodyAr: 'محتوى ب',
      createdAt: DateTime.utc(2026, 11, 26),
      category: 'system',
      accountKey: 'account-b',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1':
          jsonEncode([accountA.toJson(), accountB.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    store.markAllRead();
    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.items, hasLength(1));
    expect(store.items.single.id, 'unread-a');
    expect(store.items.single.read, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final rows = (jsonDecode(
      prefs.getString('metra2027.local_notifications.v1')!,
    ) as List).cast<Map<String, dynamic>>();
    expect(rows.singleWhere((row) => row['id'] == 'unread-a')['read'], isTrue);
    expect(rows.singleWhere((row) => row['id'] == 'unread-b')['read'], isFalse);
  });

  test('clear before initial load preserves notifications added after the clear request', () async {
    final existing = LocalNotificationItem(
      id: 'clear-before-load-existing',
      titleAr: 'إشعار سابق',
      bodyAr: 'يجب حذفه',
      createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      category: 'system',
      accountKey: 'account-a',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1': jsonEncode([existing.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    store.clearAll();
    store.add(
      titleAr: 'إشعار جديد',
      bodyAr: 'أُضيف بعد طلب المسح',
      category: 'system',
    );

    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.items, hasLength(1));
    expect(store.items.single.titleAr, 'إشعار جديد');
    expect(store.items.single.read, isFalse);
    final prefs = await SharedPreferences.getInstance();
    final rows = (jsonDecode(
      prefs.getString('metra2027.local_notifications.v1')!,
    ) as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(1));
    expect(rows.single['titleAr'], 'إشعار جديد');
  });


  test('mark all read before initial load leaves later notifications unread', () async {
    final existing = LocalNotificationItem(
      id: 'mark-before-load-existing',
      titleAr: 'إشعار سابق',
      bodyAr: 'يجب تعليمه كمقروء',
      createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      category: 'system',
      accountKey: 'account-a',
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_notifications.v1': jsonEncode([existing.toJson()]),
    });

    final store = LocalNotificationStore.forTesting();
    store.setActiveAccountKey('account-a');
    store.markAllRead();
    store.add(
      titleAr: 'إشعار جديد',
      bodyAr: 'أُضيف بعد طلب التعليم',
      category: 'system',
    );

    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.items, hasLength(2));
    final oldItem = store.items.singleWhere((item) => item.id == existing.id);
    final newItem = store.items.singleWhere((item) => item.id != existing.id);
    expect(oldItem.read, isTrue);
    expect(newItem.read, isFalse);

    final prefs = await SharedPreferences.getInstance();
    final rows = (jsonDecode(
      prefs.getString('metra2027.local_notifications.v1')!,
    ) as List).cast<Map<String, dynamic>>();
    expect(rows.singleWhere((row) => row['id'] == existing.id)['read'], isTrue);
    expect(rows.singleWhere((row) => row['id'] == newItem.id)['read'], isFalse);
  });

}