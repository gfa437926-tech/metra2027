# METRA 2027 — Work log

## 2026-11-11 — REQ-002 + Flutter specialist scaffolds

**Branch:** `work/legacy-ui-migration-audit`  
**Tasks:** REQ-002, FLT-001 update, FLT-010–017 scaffolds, nav wiring  

### Done
- Listed RAR archive (171 files); documented page modules.
- Confirmed canonical Flutter path is `flutter-app/` (CI + README).
- Added honest specialist shells (no fake observation totals).
- Added Electronic Auditor Flutter scaffold linked from More menu.
- Wired daily entry and specialist entry points from home More menu.
- Updated requirements traceability and progress docs.

### Tests
- Not run in this environment if Flutter SDK absent — record actual CI after push.

### Constraints honored
- No legacy DB touch; no Supabase migration apply; no main merge.

## 2026-11-11 — FLT-006 station directory search

**Tasks:** FLT-006  
**Done:**
- Client-side search on station directory (name, code, WMO, type/status text).
- Empty search-result state; selected-station hint.
- Unit tests for `filterStationDirectory`.
**CI note:** Prior Client CI on `5da9d38` — Flutter job success; Angular Chromium install failed (env), unrelated to Flutter change.
**Constraints:** No DB apply; no main merge.

## 2026-11-11 — FLT review type filter

**Done:** Client-side FilterChip on observation review (hourly/daily/phenomenon) without changing server contracts.

## 2026-11-11 — CI on work branch + reports navigation

**Done:**
1. Client CI and Backend CI now trigger on `work/legacy-ui-migration-audit` (previously main-only; explains missing runs).
2. Chromium install step: one automatic retry (still fails the job if both attempts fail; no skip).
3. More menu: «حالة نشرات المحطة» and «تقارير المحطة» require selected station then open live API-backed screens.
4. ObservationStatusScreen: lists review/returned items in UTC, 403/401 messages, open review action, phenomenon counts.
5. StationReportsHubScreen: Scaffold for standalone navigation.

**Constraints:** No SQL, no main merge, no old DB.

### CI workflow update blocked
Attempted to add `work/legacy-ui-migration-audit` to Client/Backend CI `on.push.branches`.
Push rejected: PAT lacks `workflow` scope.
**Owner action required:** either grant the token `workflow` scope, or edit
`.github/workflows/client-ci.yml` and `backend-ci.yml` in the GitHub UI to include:
`branches: [main, work/legacy-ui-migration-audit]`

## 2026-11-11 — deferred to end of workstream
- Automatic CI path filters for work branch (needs `workflow` scope).
- Angular Chromium install / offline browser e2e flakiness in Client CI.
- Live forecasting meteorological snapshot (pending contract + owner approval).
- Specialist unit APIs (rainfall/climate/agriculture/soil/AI/Climatol).
- Supabase SQL apply, main merge, staging publish.


## FLT-OPS-TEST-01 — إصلاح اختبار مركز عمليات المحطة — 2026-11-11T16:00:00Z

- **الحالة:** الإصلاح أُرسل؛ التحقق على commit الإصلاح بانتظار CI.
- **الفرع:** `work/legacy-ui-migration-audit`.
- **المصدر السابق:** `361968aafcb7d483a93e2356f3a4d05dc6804676`.
- **دليل الفشل:** Client CI run `43053464016` — `flutter analyze` نجح، لكن `flutter test` فشل في اختبار واحد من 65.
- **السبب الجذري:** اختبار `station_ops_hub_screen_test.dart` بحث عن عنصر «بلاغات الدعم» قبل تمرير قائمة `ListView` إلى موضع العنصر؛ الشاشة نفسها تحتوي بطاقة الدعم، لكن العنصر يقع أسفل مجال العرض الأول.
- **التصحيح:** أضيف `tester.scrollUntilVisible(...)` قبل التحقق من ظهور بطاقة الدعم. لم يُحذف الاختبار ولم تُخفّض شروطه، ولم يتغير سلوك الشاشة.
- **Commit الإصلاح:** `e381a6790330830075cad2a69eecb6e79033c718`.
- **التحقق المطلوب:** تشغيل Client CI على هذا الـcommit والتأكد من نجاح `flutter analyze` و`flutter test`. لا يُعد الإصلاح مغلقاً قبل النتيجة الخضراء.
- **CI السابق:** Angular npm tests وbuild نجحا في run `43053464016`؛ تثبيت Chromium كان جارياً عند آخر فحص، لذلك اختبار المتصفح غير محسوم.
- **القيود:** لا SQL أو migrations أو تغييرات RLS، لا دمج إلى `main`، لا نشر، ولا تعديل لقاعدة البيانات القديمة.


## FE-BASELINE-01 — إنشاء مصفوفة إكمال Flutter والتحقق من مسار المصدر — 2026-11-11T16:07:38.652Z

- **الحالة:** منجزة (إنشاء خط أساس توثيقي)؛ فحص المصدر التفصيلي واختبارات CI ما زالا قيد التنفيذ.
- **الفرع:** `work/legacy-ui-migration-audit`.
- **الملف الجديد:** `docs/progress/FRONTEND-COMPLETION-MATRIX.md`.
- **ما تم:** إنشاء مصفوفة أولية تشمل الأساس والتنقل والهوية والصلاحيات والمحطات والرصد الساعي/اليومي/الظواهر والوحدات المتخصصة والعمليات والتقارير والتنبؤ والتدقيق والذكاء الاصطناعي وClimatol.
- **تمييز الحالة:** لم تُصنّف الشاشات ذات القوالب أو الهياكل الأولية على أنها مكتملة؛ ربط API والاختبارات والأدلة شروط قبول صريحة.
- **نتيجة التحقق:** Client CI workflow يثبت أن مجلد Flutter المستخدم في CI هو `flutter-app/`، بينما README الحالي يوجّه المطور إلى `mobile/metra_mobile/`. تم التحقق من وجود `pubspec.yaml` و`lib/main.dart` في كلا المسارين؛ لا يجوز حذف أو دمج أي منهما قبل جرد الاختلافات الوظيفية.
- **CI:** ملف Client CI يحدد `push.branches: [main]` فقط، مع وجود `workflow_dispatch`. حالة Combined Status للـcommit `e381a6790330830075cad2a69eecb6e79033c718` أعادت قائمة statuses فارغة؛ لذلك لا يوجد دليل أخضر متاح لإغلاق إصلاح الاختبار بعد.
- **الخطوة التالية:** مقارنة شجرة ملفات Dart والاختبارات والأصول بين `flutter-app/` و`mobile/metra_mobile/`، ثم تشغيل Client CI على الفرع الحالي عبر dispatch إن كانت صلاحيات GitHub تسمح.
- **القيود:** لا تعديل لقاعدة البيانات أو migrations أو RLS، لا استخدام لقاعدة البيانات القديمة، لا دمج إلى `main`، ولا نشر.


## DOC-FE-PATH-01 — توحيد تعليمات README مع مسار Flutter في CI — 2026-11-11T16:07:58.184Z

- **الحالة:** منجزة.
- **الفرع:** `work/legacy-ui-migration-audit`.
- **التغيير:** تحديث جدول التطبيقات وأوامر تشغيل Flutter في `README.md` لاستخدام `flutter-app/`، وهو المسار الذي يستخدمه Client CI.
- **حماية من فقدان وظائف:** توثيق `mobile/metra_mobile/` كنسخة مرجعية قديمة لا تُحذف قبل مقارنة الشاشات والأصول والاختبارات والإعدادات ونقل أي وظيفة فريدة عمداً.
- **الاختبارات:** تغيير توثيقي فقط؛ لم تُنفذ اختبارات تطبيق بسبب عدم تغيير كود Flutter.
- **القيود:** لا تغييرات DB أو migrations أو RLS، لا قاعدة قديمة، لا دمج إلى `main`، ولا نشر.

## 2026-11-11T16:10Z — Frontend closure plan start

**Canonical:** `flutter-app/` only; `mobile/metra_mobile/` reference.
**Done:**
- Updated `FRONTEND-COMPLETION-MATRIX.md` with screen IDs and honest API status.
- Added observation detail bottom sheet from server payload (review + status).
**Not done:** CI green proof deferred until foundation stabilizes; live snapshot blocked.

## 2026-11-11T16:20Z — Phase-2 interface gap closure (honest shells)

**Added:**
- Role workspaces (station head, observation dept, communications, networks, system manager, forecaster, AFTN recipient, Climatol).
- AFTN console shell; record matching shell; expanded electronic auditor case/decision tiles.
- Specialist planned disabled fields for rainfall, agriculture, soil temperature.
**Explicit:** no OCR, no AFTN traffic, no live forecast snapshot, no fake soil/rain values, server remains authz source.


## FLT-REVIEW-005 — مراجعة إضافة مراكز التنبؤ ومسار Flutter — 2026-11-11T16:16:41.107Z

- **الحالة:** المراجعة منجزة؛ نقل/مواءمة الميزة إلى المسار المعتمد والتحقق الآلي ما زالا مفتوحين.
- **الفرع:** `work/legacy-ui-migration-audit`.
- **Commits Grok التي تمت مراجعتها:** `1d3286c`, `bfe0282`, `6271ce5`, `a08613f`, `4b894b8`, `6ff6f36`.
- **النتيجة الأساسية:** شاشة المقارنة الجديدة، ربط التنقل، واختبارها أُضيفت إلى `mobile/metra_mobile/`، وهو مسار مرجعي فقط. أما CI فيبني ويختبر `flutter-app/`.
- **الوضع في المسار المعتمد:** `flutter-app/lib/features/forecasting/forecasting_center_screen.dart` يحتوي بالفعل خريطة وبحثاً واختيار محطات ومقارنة عبر API خادمي ونافذة ملف المحطة؛ كما يحتوي API client على `compareForecastingStations` و`getForecastingStationProfile`. لذا فإن FLT-005 ليس ميزة جديدة مثبتة في المسار المعتمد، بل تنفيذ موازٍ في المسار المرجعي.
- **الاختبارات:** اختبار المقارنة بمحطتين وحاجز منع الرصدات الوهمية موجود في اختبار المسار المرجعي فقط. اختبار المسار المعتمد الحالي يغطي فتح شاشة التنبؤ والتنقل، وليس fixture المقارنة الجديد.
- **CI:** combined statuses وPR workflow runs كانت فارغة للـcommits التي تمت مراجعتها؛ لا يوجد دليل نجاح. كما أن workflow يحدد فروع `main` فقط في push وpull_request، ولا يشمل فرع العمل.
- **قرار المراجعة:** لا دمج تلقائي ولا تعديل لملفات Flutter أثناء عمل Grok. يلزم مواءمة واعية للوظائف بين المسارين، نقل اختبار المقارنة إلى `flutter-app/`، ثم تشغيل CI على الفرع.
- **القيود:** لم يتم تعديل أي مصدر Flutter، ولم تُمس قاعدة البيانات أو migrations أو RLS، ولم يحدث دمج إلى `main` أو نشر.
- **المرجع:** `docs/progress/FRONTEND-COMPLETION-MATRIX.md` تم تحديثه في commit المراجعة.


## FLT-REVIEW-004 — تدقيق مسار تفاصيل بيانات المحطات — 2026-11-11T16:17:13.811Z

- **الحالة:** المراجعة منجزة؛ نقل تحسينات المصدر والدقة إلى Flutter المعتمد ما زال مطلوباً.
- **Commits:** `0f6dd68`, `e399ea2`, `5de8d78`, `549b147`, `8e136e3`، وتقرير الجولة `eeb82bd`.
- جميع تغييرات FLT-004 التي تضيف مصدر الإحداثيات ودقتها وواجهة تفاصيل المحطة واختبارها تقع في `mobile/metra_mobile/` وليس `flutter-app/`.
- النموذج في `flutter-app/` يتضمن الارتفاع `elevation_m` لكنه لا يعرّف حقلي `coordinateSource` و`coordinateAccuracyM`؛ لذلك لم تثبت مطابقة هذه الجزئية في المسار الذي يبنيه CI.
- تقرير FLT-004 نفسه يصرح بأن analyzer/tests والبناء والتحقق البصري لم تُنفذ.
- **الإجراء التالي:** مواءمة حقول مصدر الإحداثيات ودقتها وواجهة التفاصيل واختبارها داخل `flutter-app/` بعد مقارنة دقيقة، دون نسخ أعمى أو حذف المسار المرجعي.


## CONSOLIDATE-FLUTTER-01 — مواءمة الواجهات المرجعية مع Flutter المعتمد — 2026-11-11T16:28:23.193Z

- **الحالة:** مواءمة أولية منجزة؛ اختبارات Flutter/CI والتحقق البصري بانتظار التنفيذ.
- **الفرع:** `work/flutter-canonical-consolidation` (فرع مستقل مشتق من `work/legacy-ui-migration-audit`؛ لا دمج إلى `main`).
- **مقارنة المصدر:** `mobile/metra_mobile/` على `main` مقابل `flutter-app/` على فرع الدمج.
- **قرار الدمج:** لم يُنسخ المسار المرجعي بالكامل. النسخة المعتمدة أوسع في API/auth/home/station directory/observation/ops/reports؛ تم الحفاظ عليها، ونُقلت الوظائف الفريدة فقط.
- **التنقل:** نقل `MetraAdaptiveNavigation` إلى `flutter-app/lib/core/widgets/` ودمجه في `MetraHome`: NavigationRail على العرض الواسع وNavigationBar على العرض الصغير، مع الإبقاء على الوجهات الأساسية الخمس. اختبار responsive أضيف.
- **FLT-004:** أضيف `coordinateSource` و`coordinateAccuracyM` إلى `StationDirectoryItem` مع parsing من station_coordinates؛ عُرض المصدر والدقة في تفاصيل المحطة وملف مركز التنبؤ. أضيفت اختبارات API model وstation detail.
- **FLT-005:** لم تُنسخ شاشة المقارنة المرجعية كنسخة مكررة؛ الشاشة المعتمدة موجودة وتستخدم خريطة وبحثاً وملف محطة وAPI مقارنة خادمي يدعم 2–12 محطة، وهو أقوى من حساب المسافة محلياً في الشاشة المرجعية. تم الحفاظ على هذا التنفيذ.
- **الحسابات:** أضيفت قراءة `GET /api/v1/account/registration-status` إلى الملف الشخصي لإظهار حالة الحساب ومرحلة طلب الانضمام وملاحظة المراجعة ووقت UTC، مع loading/error/retry. أضيفت اختبارات حالة ناجحة وفشل آمن.
- **نتيجة التدقيق:** تسجيل الدخول لا يزال يفتح `MetraHome` بمجرد وجود Supabase session؛ لا يوجد access-context endpoint يعيد التعيينات والصلاحيات الفعلية. لا توجد شاشة فعلية لإدارة الأدوار والصلاحيات أو منع الوصول/انتهاء الجلسة. هذه فجوات موثقة في `docs/progress/ACCOUNT-SCREENS-AUDIT.md`.
- **الملفات التوثيقية:** تحديث `docs/progress/FRONTEND-COMPLETION-MATRIX.md`؛ إنشاء `docs/progress/ACCOUNT-SCREENS-AUDIT.md`.
- **التحقق:** لم يتم تشغيل `flutter analyze` أو `flutter test` أو Android/iOS build أو visual tests؛ لا يوجد Flutter SDK في بيئة التنفيذ الحالية. لا تُعتبر الاختبارات المضافة ناجحة قبل CI.
- **القيود:** لم يتم تعديل `main`، لم يحدث نشر، لم تُمس قاعدة البيانات الجديدة أو القديمة، ولم تطبق migrations/RLS/grants/seeds. لم يُحذف `mobile/metra_mobile/`.


## ACC-03/04/05 + REG-AUDIT-01 — استكمال واجهات الحسابات والتدقيق — 2026-11-11T16:46:17.037Z

- **الحالة:** واجهات وAPI client واختبارات مصدرية أضيفت؛ تحقق Flutter CI قيد الانتظار.
- **الفرع:** `work/flutter-canonical-consolidation`.
- **إدارة العضويات والصلاحيات:** إضافة `AuthorityAccessScreen` إلى قائمة المزيد؛ ربط كتالوج الجهات، أدوار العضوية، خيارات الصلاحيات، طوابير العضويات/المنح المعلقة والسارية/المجدولة، قرارات الاعتماد/الرفض، الإلغاء، وسجل التدقيق. كل العمليات تمر عبر API الموجود وتبقى صلاحياتها مفروضة خادمياً.
- **تدقيق التسجيل:** إضافة `listRegistrationAudit` و`RegistrationAuditScreen` وربط سجل تدقيق مرحلة المحطة/الجهة من شاشة مراجعة التسجيل.
- **بوابة الحساب:** `MetraAuthGate` يتحقق من `GET /api/v1/account/registration-status` قبل فتح مساحة العمل. الحساب النشط فقط يدخل؛ pending/null يذهب إلى متابعة التسجيل؛ suspended/disabled/rejected/unknown أو فشل التحقق يمنع الدخول التشغيلي ويعرض إعادة التحقق/الخروج.
- **منع تكرار التسجيل:** إظهار حالة الطلب وتاريخ UTC وملاحظة المراجعة، وإخفاء نموذج الإرسال أثناء انتظار اعتماد المحطة/النظام.
- **تعيينات المحطات:** أضيف حقل اختياري `valid_to` بتنسيق ISO-8601 مع UTC marker/offset، والتحقق من المستقبل، وتحويله إلى UTC قبل الإرسال. أضيفت نافذة تفاصيل التعيين للمعرّف والمستخدم والدور والحالة وفترة السريان والسبب والمنشئ.
- **الاختبارات المصدرية الجديدة/المحدثة:** `account_state_gate_test.dart`, `authority_access_screen_test.dart`, `registration_audit_screen_test.dart`, `registration_screen_test.dart`, `station_assignment_screen_test.dart`.
- **التوثيق:** `docs/progress/ACCOUNT-SCREENS-AUDIT.md` و`docs/progress/FRONTEND-COMPLETION-MATRIX.md` محدثان.
- **CI:** Client CI push workflow مفعّل على فرع الدمج. آخر run عند هذه اللحظة ينتظر/يعمل على tip سابق؛ أحدث tip سيحصل على run جديد بعد هذا التحديث. لا يُعلن النجاح قبل run مطابق تماماً للـHEAD.
- **المتبقي:** effective access-context للمستخدم، صفحة ملف مستخدم إداري كاملة، بحث المستخدمين المؤهلين، نهاية السريان لعضويات/منح الجهات، deep-link لإكمال إعادة كلمة المرور، اختبار انتهاء/سحب الجلسة، اختبارات منع الوصول عبر المحطات والجهات.
- **القيود:** لم يتم تطبيق أي migrations/RLS/grants/seeds ولم تُمس قواعد البيانات. لا دمج إلى `main` ولا نشر.


## ACC-06/07 + AUTH-RECOVERY-01 + CONSOLIDATE-FLUTTER-02 — توسيع شاشات الحسابات وتدقيق المصدر المرجعي — 2026-11-11T17:00:09.839Z

- **الحالة:** تنفيذ واجهات ودمج وظائف مرجعية منجز مصدرّياً؛ تصحيح اختبارات CI جارٍ.
- **استعادة كلمة المرور:** شاشة تعيين كلمة مرور جديدة، معالجة `AuthChangeEvent.passwordRecovery`، رابط `metra2027://auth-callback` مسجل في Android/iOS، واختبارات شاشة كلمة المرور. allow-list في Supabase واختبار البريد الفعلي ما زالا مطلوبين.
- **سجل تدقيق التسجيل:** `RegistrationAuditScreen` يقرأ سجلات مرحلة المحطة/النظام عبر endpoint موجود ويرتبط من شاشة مراجعة التسجيل.
- **سجل تدقيق المحطة:** `StationAuditLogScreen` يقرأ endpoint `/api/v1/stations/{stationId}/audit-log` ويرتبط من إدارة التعيينات.
- **إدارة العضويات والصلاحيات:** الشاشة الجديدة متصلة بالـAPI الحالي، تشمل الطلبات والطوابير والقرارات والإلغاء وسجل التدقيق. لا تنشئ صلاحيات محلياً.
- **تعيين المحطات:** نهاية سريان UTC اختيارية مع تحقق من المنطقة الزمنية، وتفاصيل تعيين قابلة للقراءة. المستخدم المستهدف ما زال UUID يدوياً لغياب API بحث مستخدمين مؤهلين.
- **بوابة الحساب:** active فقط يفتح المساحة التشغيلية؛ pending/null يذهب إلى التسجيل؛ suspended/disabled/rejected/unknown وفشل قراءة الحالة يمنع الدخول.
- **جرد النقل:** تم فحص جميع ملفات `mobile/metra_mobile/` مقارنة بـ`flutter-app/`. الملف الوحيد الفريد هو شاشة التنبؤ المرجعية؛ لم تنسخ لأنها أضعف من شاشة المقارنة الخادمية الموجودة في المسار المعتمد. كل الملفات المشتركة إما متطابقة أو النسخة المعتمدة أوسع، وتم دمج الوظائف الفريدة بدلاً من الاستبدال الكلي.
- **CI:** run `43063206728`: Flutter analyze ناجح، الاختبارات 78 ناجح / 4 فاشلة. تم إصلاح فشل Future.error في الاختبار، وتحديث عقد بيانات registration fixtures، وتصحيح fixture كتالوج الجهات. run `43063665760` للـSHA `7850c08` كان queued عند كتابة هذا السجل.
- **الوثائق:** تحديث `ACCOUNT-SCREENS-AUDIT.md`, `FRONTEND-COMPLETION-MATRIX.md`, `REQUIREMENTS-TRACEABILITY.md`, `PAGE-IMPLEMENTATION-STATUS.md`, وإنشاء `FLUTTER-REFERENCE-PATH-CONSOLIDATION.md` و`SUPABASE-AUTH-REDIRECT-SETUP.md`.
- **القيود:** لم تطبق migrations/RLS/grants/seeds، لم تلمس قاعدة البيانات القديمة، لا دمج إلى main ولا نشر.


## FLT-FRONTEND-VERIFY-03 — جرد الفرونت إند والتحقق من CI على HEAD الحالي — 2026-11-11T17:47:26.374Z

- **الحالة:** التحقق الآلي على HEAD الحالي ناجح؛ استكمال الفرونت إند الوظيفي ما زال جارياً.
- **المستودع/الفرع:** `gfa437926-tech/metra2027` / `work/flutter-canonical-consolidation`.
- **HEAD:** `51ed88afa415072e9e41679f585610e5615b9b5d`.
- **CI:** run `43071280050` نجح على نفس HEAD؛ Flutter analyze وFlutter tests ناجحة، وكذلك Angular tests/build واختبار Chromium PWA/IndexedDB. النجاح لا يغطي القبول البصري على الأجهزة أو اختبار البريد الفعلي.
- **الجرد:** تأكد وجود ملفات Flutter للحسابات والمحطات والرصد الساعي/اليومي/الظواهر ومركز التنبؤ والعمليات والصيانة والدعم والتقارير ومكاتب الأدوار والتدقيق الإلكتروني والذكاء الاصطناعي وClimatol وAFTN والوحدات التخصصية.
- **الفجوات المؤكدة:** التدقيق الإلكتروني لا يزال scaffold بلا إنشاء حالة/رفع/استخراج/مقارنة/قرار خادمي؛ تنفيذ AI معطل حتى AI Gateway؛ تنفيذ Climatol معطل حتى worker معزول وعقد بصمة بيانات واعتماد بشري؛ وحدات المطر والمناخ والزراعة وحرارة التربة معاينة محلية فقط حتى اعتماد الحقول والـAPI؛ الرصد اللحظي والنشرات في مركز التنبؤ تحتاج عقد snapshot؛ صفحات قوائم وتقارير الرصد الساعي واليومي وسجل النسخ والتصدير ما زالت غير مكتملة؛ إدارة المستخدمين العامة وسياق الصلاحيات الفعلي غير متاحين في API الحالي.
- **الخطوات التالية:** إكمال صفحات القوائم والتاريخ والتقارير باستخدام API الموجود أولاً، ثم إنهاء دورة الحسابات والتعيينات والصيانة والدعم، وبعدها ربط الوظائف المحجوبة عند اعتماد عقود Backend والتخزين والصلاحيات. لا نغيّر DB أو migrations/RLS/grants/seeds دون موافقة.
- **القيود:** لا تعديل على main، لا نشر، لا مساس بقاعدة البيانات القديمة أو الجديدة.


## FE-UI-SPECIALIST-02 / FE-ACCOUNT-VERIFY-03 / FE-ROLE-CATALOG-01 — توسعة الواجهات والتحقق — 2026-11-11T17:48:59.359Z

- **الحالة:** واجهات Flutter الإضافية نُفذت مصدرّياً؛ تحقق CI ناجح؛ تكامل الخدمات المتخصصة ما زال محجوباً بعقود Backend غير الموجودة.
- **AI:** مساحة مستقلة بخمسة أقسام (الرئيسية، التحليل، الشذوذ، التقارير، الحوكمة). لا تنفذ استدلالاً قبل AI Gateway ولا تعرض نتائج مصطنعة.
- **Climatol:** مساحة إعداد المحطات والمتغيرات والفترة، سير المعالجة، التشخيص والإصدارات. المحطات من API الدليل؛ لا تشغيل قبل عامل معزول وخدمة نتائج.
- **التدقيق الإلكتروني:** ثمانية أقسام للسجلات الورقية والميكانيكية والمقارنة والمراجعة والمكتبة والتدريب والتقارير. الرفع وOCR والقرارات غير مفعلة لغياب API.
- **AFTN:** وارد/صادر/إنشاء رسالة/القناة والتدقيق؛ المعاينة محلية فقط والإرسال معطل حتى بوابة خادمية معتمدة.
- **الوحدات المتخصصة:** واجهات محطة ونماذج/فلاتر قابلة للمعاينة المحلية للأمطار والمناخ والزراعة وحرارة التربة. لا حفظ أو إرسال ولا افتراض لوحدات أو حدود علمية غير معتمدة.
- **المطابقة:** مدخل مطابقة السجلات يفتح تبويب المقارنة داخل مساحة المدقق بدلاً من تكرار shell منفصل.
- **الأدوار:** أضيفت تعريفات واجهة لرافع السجلات والمدقق ومعتمد التدقيق ومحلل AI ومدير/معتمد النماذج ومرسل AFTN. هذه metadata تنظم التنقل فقط ولا تمنح أي صلاحية.
- **إصلاح حسابات:** عولج عمر TextEditingController في نافذة سبب طلب العضوية؛ صار المتحكم مملوكاً لنافذة مستقلة حتى إزالة المسار، مع إعادة بناء زر التأكيد عند الكتابة.
- **UTC:** إصلاح اختيار التاريخ بحيث تبقى قيمة اليوم التقويمية كما اختارها المستخدم ولا تتحول إلى اليوم السابق/التالي عند تحويل منتصف الليل إلى UTC.
- **CI exact tip:** run `43071280050` على `51ed88a`: Flutter analyze ناجح و85 اختباراً ناجحاً؛ Angular npm tests/build وChromium PWA/IndexedDB smoke test ثلاث مرات ناجحة.
- **ما بقي محجوباً:** live forecast snapshots/bulletins؛ specialist aggregate/report APIs؛ electronic audit case/evidence/OCR; AI Gateway; Climatol worker; AFTN gateway; hourly/daily history and export read models; effective account access-context; Supabase recovery redirect allow-list/device round-trip.
- **قيود:** لا DB migrations/RLS/grants/seeds، لا وصول إلى قاعدة البيانات القديمة، لا main merge ولا deployment.
