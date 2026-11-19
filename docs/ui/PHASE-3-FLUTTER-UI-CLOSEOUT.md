# PHASE 3 — إغلاق واجهات Flutter (تدقيق + إغلاق)

**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `feat/phenomenon-observation-submit-2026-11-16`  
**SHA البداية:** `feda19bb93d8f69f98eb3d90d8543a1128238597`  
**SHA النهاية:** يُحدَّث مع commit هذه الدفعة  

**منهجية النسبة:** لكل شاشة/وحدة وزن 1.  
- متصلة API أو مكتملة محلياً بسلوك محدد = 1  
- مواصفة واجهة بلا محرك لكن حالات واضحة وأزرار معرّفة (معطّلة صراحة) = 0.75  
- ناقصة/غير موجودة = 0  
النسبة = مجموع النقاط / عدد الوحدات × 100.

---

## 1. جرد الشاشات والحالة

| # | الوحدة / الشاشة | الملف الأساسي | الحالة |
|---|---|---|---|
| 1 | إعداد الاتصال | `metra_auth.dart` Configuration | مكتملة محلياً |
| 2 | تسجيل الدخول | `MetraLoginScreen` | متصلة (Supabase Auth) |
| 3 | استعادة كلمة المرور | نفس شاشة الدخول | متصلة (resetPasswordForEmail) |
| 4 | بوابة الجلسة | `MetraAuthGate` | متصلة |
| 5 | الرئيسية | `metra_home.dart` | متصلة جزئياً (Access Context) + محلي |
| 6 | دليل المحطات + تفاصيل | `station_directory_screen.dart` | متصلة API الدليل |
| 7 | رصد ساعي | `hourly_observation_screen.dart` | متصلة API |
| 8 | رصد يومي | `daily_observation_screen.dart` | متصلة API |
| 9 | ظواهر | `phenomenon_observation_screen.dart` | متصلة API |
| 10 | مراجعة أرصاد | `observation_review_screen.dart` | متصلة API (+ فلتر/تأكيد) |
| 11 | زراعي | كتالوج + workspace | مكتملة محلياً / تحتاج Backend |
| 12 | مناخي ساعي | كتالوج | مكتملة محلياً / تحتاج Backend |
| 13 | أمطار | كتالوج + قواعد محلية | مكتملة محلياً / **تحتاج موافقة M1** |
| 14 | تربة | كتالوج + قواعد محلية | مكتملة محلياً / **تحتاج موافقة M1** |
| 15–17 | أعطال أجهزة/اتصالات/IT | كتالوج | مكتملة محلياً / تحتاج قرار دورة أعطال |
| 18 | إدارة المحطة | `station_administration_screen.dart` | متصلة API (ضمن العقود) |
| 19 | مراكز تنبؤ (مقارنة جغرافية) | `forecast_centre_screen.dart` | متصلة جزئياً (دليل فقط) |
| 20 | CLIMATOL | `metra_workspaces.dart` | مكتملة محلياً كمواصفة / تحتاج Backend |
| 21 | أرشيف مصور | workspaces | مكتملة محلياً كمواصفة / تحتاج Backend |
| 22 | مختبر AI | workspaces | مكتملة محلياً كمواصفة / تحتاج Backend |
| 23 | مقارنة AI | workspaces | مكتملة محلياً كمواصفة / تحتاج Backend |
| 24 | عمليات أجهزة/شبكات/IT | workspaces | مكتملة محلياً كمواصفة / تحتاج Backend |
| 25 | تقارير وإحصائيات | workspaces | مكتملة محلياً كمواصفة / تحتاج Backend |
| 26 | إعدادات النظام | `system_settings_screen.dart` | مكتملة محلياً |
| 27 | الحساب / كلمة المرور | `account_hub_screen.dart` | متصلة (updateUser) + محلي |
| 28 | طلب تسجيل محطة | `registration_request_screen.dart` | متصلة API |
| 29 | حالة التسجيل | نفس الملف | متصلة API |
| 30 | مركز الإشعارات | `notifications_center_screen.dart` | مكتملة محلياً (بلا تغذية) / تحتاج Backend |

**وحدات غير موجودة كشاشات مستقلة (مغطاة جزئياً أو سياسة):**
- تسجيل مستخدم ذاتي عام (السياسة: تفعيل من النظام + طلب محطة بعد الجلسة)
- إدارة مستخدمين **نظامية** خارج نطاق المحطة — تحتاج عقداً أوسع إن لزم

---

## 2. ما أُنجز في هذه الدفعة (Phase 3)

- تدقيق الجرد مقابل الكود الفعلي
- تأكيد اعتماد المراجعة (حوار قبل approve)
- صقل هوية شاشة الدخول (`MetraColors`)
- وثيقة الإغلاق هذه + تحديث التقارير الثلاثة

(الدفعات السابقة غطّت Theme، إزالة Scaffold المتداخل، التسجيل، الفلاتر، الإشعارات، U0/U1 docs.)

---

## 3. التدقيق التقني (مختصر)

| الموضوع | النتيجة |
|---|---|
| Scaffold/AppBar مزدوج في وجهات shell | مُعالَج لمساحات العمل؛ مسارات push ثانوية قد تملك AppBar خاصاً (مقبول) |
| مسودات + تبديل محطة | موجود في hourly/daily/phenomenon |
| Idempotency + منع إرسال مزدوج | `_submitting` + مفتاح idempotency في النماذج المتصلة |
| صلاحيات | Access Context من الخادم؛ Mutations عبر JWT |
| أسرار / Service Role في Flutter | غير موجودة كمفاتيح؛ تحذيرات نصية فقط |
| بيانات وهمية علمية | غير معروضة؛ لوحات «غير متصل» |

---

## 4. الاختبارات

| أمر | النتيجة |
|---|---|
| Flutter SDK | **غير متوفر** في بيئة التنفيذ |
| `flutter pub get` / `analyze` / `test` / web release | **لم تُنفَّذ** |
| ادعاء نجاح | **مرفوض** |

---

## 5. ينتظر Backend

- تغذية إشعارات
- CLIMATOL / AI / أرشيف ملفات / تقارير رقمية / أصول
- حفظ agricultural / hourlyclimate
- دورة أعطال خادمية عند اعتمادها

## 6. ينتظر موافقة DB / قرار

- **M1** توسيع أنواع rainfall/soil  
- **M2** event_type في `metra_decide_observation`  
- **M3/M4** بعد M1  

---

## 7. حساب نسبة اكتمال الواجهات

| فئة | عدد | وزن النقطة | المجموع |
|---|---:|---:|---:|
| متصلة API أو مكتملة محلياً كاملة السلوك | 18 | 1.0 | 18.0 |
| مواصفة واجهة صريحة بلا محرك | 12 | 0.75 | 9.0 |
| **المجموع** | **30** | | **27.0** |

**نسبة اكتمال الواجهات (هيكلي + تفاعلي محلي) ≈ 27/30 = 90%.**

| بُعد منفصل | تقدير |
|---|---:|
| وظائف محلية (تحقق، حالات، تنقل) | ~88–92% |
| ربط Backend | ~42–48% |
| جاهزية نشر | غير جاهز |

**لا يُعلن 100%** — وحدات المواصفة والخدمات غير المتصلة تمنع ذلك بصدق.

---

## 8. قيود محترمة

لا SQL/M1/M2/push/merge/force، PR 54/55 Draft، لا endpoints مخترعة، لا E2E/Staging.

---

## تحقق بيئة 2026-11-19 — تثبيت commits + اختبارات

### Git push
- الأمر: `git push origin feat/phenomenon-observation-submit-2026-11-16` (بدون force)
- **النتيجة: فشل** — `could not read Username for 'https://github.com': No such device or address`
- لا يوجد `GITHUB_TOKEN` / credentials في بيئة الوكيل
- **الحالة المحلية:** 19 commits عند `07120ffd4d852867e186dfd054ff749bfb91ec8e` ما زالت محفوظة وغير مرفوعة

### Flutter SDK (مؤقت في البيئة)
- ثُبّت Flutter 3.50.0 / Dart 3.14.0
- `flutter pub get` → **نجح**
- `flutter analyze` → **انهار** (analysis server exit -9 / OOM؛ الذاكرة ≈ 1.2 GiB)
- `flutter test test/metra_access_context_test.dart` → **All tests passed! (8/8)** تنفيذ فعلي
- بقية الحزمة / `flutter build web --release` → **لم تكتمل** بسبب قيود الذاكرة/زوال ملفات SDK المؤقتة

### لا يُدّعى نجاح analyze أو full test أو web release.

---

## تحقق إعادة التثبيت — 2026-11-19 (جلسة لاحقة)

### Git (مُتحقَّق بأوامر فعلية)
| بند | القيمة |
|---|---|
| الفرع | `feat/phenomenon-observation-submit-2026-11-16` |
| HEAD المحلي | `423a433abaf4b89354f5795a664ca44395ea8419` |
| SHA مرحلة 3 المطلوب | `07120ffd4d852867e186dfd054ff749bfb91ec8e` — موجود وهو والد HEAD مباشرة |
| commits غير مرفوعة | **20** (`git rev-list --count origin/...HEAD`) |
| working tree | نظيفة عدا `?? .flutter-plugins-dependencies` (مولَّد محلياً) |

### Push
```
fatal: could not read Username for 'https://github.com': No such device or address
```
**لم يُرفع أي commit.** لا Force Push. لا token في البيئة.

أوامر الدفع للمالك (من جهاز مصادق):
```bash
cd metra2027
git fetch origin
git checkout feat/phenomenon-observation-submit-2026-11-16
git log --oneline origin/feat/phenomenon-observation-submit-2026-11-16..HEAD
git push origin feat/phenomenon-observation-submit-2026-11-16
git rev-parse HEAD
git ls-remote origin refs/heads/feat/phenomenon-observation-submit-2026-11-16
```

### Flutter
| بند | نتيجة فعلية |
|---|---|
| SDK | Flutter **3.50.0** / Dart **3.14.0** |
| ذاكرة البيئة | ~**1.2 GiB** بدون swap |
| `flutter pub get` | **نجح** |
| `flutter test test/metra_access_context_test.dart` | **All tests passed (8/8)** — أكثر من مرة |
| `flutter test` (دفعة أكبر) | **تعطل المترجم** (`TestCompiler` / `Dart compiler exited unexpectedly`) — ضغط ذاكرة |
| `flutter analyze` | **غير ناجح** سابقاً (analysis server -9) |
| `flutter build web --release` | **لم يُنجز بنجاح** في هذه البيئة |

**لا يُعلن نجاح analyze أو full test أو web release.**

### خلاصة إغلاق المرحلة 3
- كود الواجهات + وثائق Phase 3 محلياً عند SHA أعلاه.
- الإغلاق «المختبري الكامل» (analyze + full test + web) يحتاج آلة ≥4–8 GiB ودفع المالك للفرع.
