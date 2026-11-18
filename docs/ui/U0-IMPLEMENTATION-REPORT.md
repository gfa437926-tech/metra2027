# تقرير تنفيذ المرحلة U0 — صقل واجهات Flutter

**التاريخ:** 2026-11-18  
**الفرع:** `feat/phenomenon-observation-submit-2026-11-16`  
**HEAD عند الإغلاق الجزئي:** يُحدَّث مع commit التنفيذ  
**origin:** ما زال متأخراً عن المحلي (commits غير مرفوعة)

## النطاق المنفَّذ

تحسينات عرض وحالات async وتأكيدات حساسة **دون** API / Schema / RPC / صلاحيات إنتاج.

## الشاشات المحسّنة فعلياً

| الشاشة | التحسين |
|---|---|
| دليل المحطات | Loading/Error/Empty موحّدة عبر `MetraAsyncStatePanel` + إعادة محاولة |
| مراجعة الأرصاد | Loading/Error/Empty أوضح + زر تحديث في الفراغ |
| إدارة المحطة (تبويبات) | نفس نمط الحالات لمستخدمي المحطة والسجلات وطابور الأرصاد |
| الإعدادات | RTL صريح، تأكيد حوار قبل تسجيل الخروج، منع النقر أثناء الخروج |
| نماذج الكتالوج السبعة | `Directionality` RTL على `CatalogObservationScreen` |
| الرئيسية | منع overflow لاسم/معرّف المحطة في AppBar |

## الملفات المتغيرة

- `lib/core/widgets/metra_async_state.dart` (**جديد**)
- `lib/features/stations/station_directory_screen.dart`
- `lib/features/observations/observation_review_screen.dart`
- `lib/features/observations/catalog_observation_screen.dart`
- `lib/features/admin/station_administration_screen.dart`
- `lib/features/settings/system_settings_screen.dart`
- `lib/features/home/metra_home.dart`
- `test/metra_async_state_test.dart` (**جديد**)
- `test/system_settings_screen_test.dart`

## النواقص التي أُغلقت (U0)

- توحيد لوحات التحميل/الفراغ/الخطأ في المسارات ذات الأولوية أعلاه.
- رسائل عربية أوضح مع إجراء إعادة محاولة حيث ينطبق.
- تأكيد تسجيل الخروج (عملية حساسة).
- RTL أصرح للكتالوج والإعدادات.
- حماية عرض AppBar من overflow على الشاشات الضيقة.

## النواقص التي بقيت (خارج U0 أو تتطلب عقوداً)

- Placeholders: CLIMATOL / AI / تقارير / عمليات — **لم تُحوَّل** إلى وظائف وهمية.
- ربط rainfall/soil خادمي — يحتاج موافقة DB/API مستقلة.
- تسجيل مستخدم / حالة حساب غنية / إشعارات — غير موجودة.
- تشغيل الاختبارات في هذه البيئة — **Flutter غير متوفر**؛ لا ادعاء نجاح.
- مطابقة بصرية 100% مع أرشيف التصميم المرجعي — غير مؤكدة.

## الاختبارات

| اختبار | الحالة |
|---|---|
| `metra_async_state_test.dart` | مُضاف — **لم يُشغَّل** هنا |
| `system_settings_screen_test.dart` (تأكيد الخروج) | مُحدَّث — **لم يُشغَّل** هنا |
| `flutter analyze` / `flutter test` | غير متاحين في بيئة التنفيذ |

## نسبة تقدم U0

| بند | تقدير |
|---|---:|
| أولويات U0 المذكورة في المهمة | **~75–80%** |
| كل شاشات التطبيق بما فيها Placeholder | U0 لا يغلقها — بقيت صريحة |

## الخطوة التنفيذية التالية

1. تشغيل `flutter test` و`flutter analyze` محلياً/CI بعد push.  
2. عند موافقة DB مستقلة: بدء ربط **rainfall + soil** (U1) دون المساس بالأعطال.  
3. اختيارياً: تعميم `MetraAsyncStatePanel` على `forecast_centre_screen` إن لزم توحيد إضافي.
