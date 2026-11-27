import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/notifications/local_notification_item.dart';
import 'package:metra_mobile/core/notifications/local_notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
