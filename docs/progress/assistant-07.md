# تقدم المساعد رقم 7 — الأمن السيبراني

**آخر تحديث:** 2026-11-10 23:28:49 UTC  
**المهمة:** SEC-07 — التدقيق الأمني وتقوية حماية METRA 2027  
**الحالة:** قيد التنفيذ  
**الفرع:** `security/initial-hardening-audit`  
**Pull Request:** [#30 — Draft](https://github.com/gfa437926-tech/metra2027/pull/30)  
**آخر Commit قبل هذا التحديث:** [1bb0267619d310a2efaecf427bb1fe8707034452](https://github.com/gfa437926-tech/metra2027/commit/1bb0267619d310a2efaecf427bb1fe8707034452)

## نسبة الإنجاز

**30% من نطاق مهمة SEC-07.**

طريقة الحساب: قُسم نطاق المهمة إلى 10 حزم متقاربة الوزن (قراءة البنية وتحديد النطاق، المصادقة، التفويض ونطاق المحطات، API، الحقن وCSRF/XSS، الأسرار والتشفير، السجلات، CORS/Headers/Rate limiting، الاعتماديات، النشر والتحقق). أُنجزت مراجعة ساكنة أولية عبر هذه المحاور، لكن لم تُستكمل الاختبارات الديناميكية أو التحقق من البيئة الإنتاجية؛ لذلك احتُسبت 3 حزم مكافئة من 10 فقط كإنجاز مكتمل جزئياً. هذه نسبة تقديرية لنطاق هذه المهمة فقط وليست نسبة المشروع.

## الملفات التي فُحصت

- `README.md`
- `backend/Metra.Api/Program.cs`
- `backend/Metra.Api/appsettings.json`
- `backend/Metra.Api/Metra.Api.csproj`
- `backend/Metra.Api/Security/StationAuthorizationService.cs`
- `backend/Metra.Api/Security/StationAuthorizationEndpointExtensions.cs`
- `backend/Metra.Api/Features/Users/AuthorityAccessEndpoints.cs`
- `backend/Metra.Api/Features/Users/RegistrationReviewEndpoints.cs`
- `backend/Metra.Api/Features/Users/RegistrationSubmissionEndpoints.cs`
- `backend/Metra.Api/Features/Users/StationAssignmentEndpoints.cs`
- `backend/Metra.Api/Features/Users/StationAuditEndpoints.cs`
- `backend/Metra.Api/Features/Users/StationUserDirectoryEndpoints.cs`
- `database/migrations/003_station_permission_rpc.sql`
- `database/migrations/020_authority_membership_and_permission_grant_lifecycle.sql`
- `database/migrations/021_authority_permission_grant_lifecycle.sql`
- `database/migrations/022_harden_authority_access_revocation_and_audit_index.sql`
- `database/migrations/023_bind_authority_access_decisions_to_route_scope.sql`
- `database/migrations/024_revoke_direct_service_role_writes_to_authority_audit.sql`
- `database/migrations/025_require_active_subject_for_authority_approval.sql`
- `angular-app/src/app/core/supabase/supabase-auth.service.ts`
- `angular-app/src/app/core/supabase/supabase.config.ts`
- `angular-app/src/app/core/supabase/auth.guard.ts`
- `angular-app/src/app/app.routes.ts`
- `angular-app/src/metra-config.js`
- `angular-app/package-lock.json`
- `mobile/metra_mobile/lib/core/auth/metra_auth.dart`
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs`
- `backend/Metra.Api.Tests/Security/SupabaseStationAuthorizationServiceTests.cs`
- `backend/Metra.Api.Tests/Features/Users/SupabaseAuthorityAccessServiceTests.cs`
- `.github/workflows/backend-ci.yml`
- `.github/workflows/client-ci.yml`
- `.github/workflows/publish-api-container.yml`
- `render.yaml`
- `backend/Dockerfile`
- `docs/security/authority-scope-authorization.md`
- `docs/security/role-permission-matrix.md`
- `docs/deployment/MULTI-ENVIRONMENT-HOSTING.md`
- `.gitignore`

## الملفات التي عُدلت في جولة التنفيذ الأولى

- `.gitignore` — إضافة استثناءات ملفات البيئة والأسرار المحلية والمفاتيح والشهادات الخاصة.
- `.github/workflows/client-ci.yml` — استخدام `npm ci` وفحص `npm audit --audit-level=high`.
- `docs/security/SECURITY-AUDIT-2026-11-11.md` — التقرير الأمني الأولي.
- `واجهات/README.md`, `واجهات/مهما.md`, `واجهات/تغيير.md` — ملفات تنسيق وتسليم تأسيسية؛ لم تكن موجودة على `main` وقت التدقيق، ولذلك أُنشئت على فرع المهمة ولم يُستبدل تاريخ سابق.

## ما نُفذ فعلياً

1. مراجعة ساكنة لمصادقة JWT وسياسة authorization الافتراضية.
2. مراجعة تفويض المحطات والسلطات والتحقق من actor المستمد من claim الموثق.
3. مراجعة سياسات RLS وRPC المتعلقة ببيانات الرصد وعمليات المراجعة وسجلات التدقيق.
4. مراجعة إعدادات CORS والنقل والأسرار وملفات النشر والاعتماديات على مستوى المصدر.
5. إضافة قواعد تجاهل الملفات الحساسة محلياً.
6. إضافة فحص npm إلى Client CI.
7. إنشاء تقرير المخاطر SEC-001 إلى SEC-009 مع التوصيات وبوابات الإطلاق.

## ما لم يُنفذ

- لم تُنفذ اختبارات اختراق أو اختبارات على أنظمة حية.
- لم تُنفذ عمليات تسجيل دخول فعلية ضد بيئة إنتاج أو اختبار.
- لم يُجر فحص كامل لتاريخ Git والأسرار؛ لم تُفحص أسرار GitHub Actions أو إعدادات مزود الاستضافة الخاصة.
- لم يُنفذ فحص npm محلياً أو فحص Flutter/Dependabot مستقل من هذه الجولة.
- لم تُضف بعد Rate Limiting أو HSTS/security headers أو حدود body عامة أو CSP أو host allow-list.
- لم تُعدل أي قاعدة بيانات أو migration أو RLS أو حساب مستخدم.
- لم يُدمج شيء إلى `main` ولم يحدث نشر.

## الاختبارات وGitHub Actions

- [Client CI — تشغيل PR الحالي](https://github.com/gfa437926-tech/metra2027/actions/runs/42922948363) — **قيد التنفيذ عند وقت هذا التحديث**.
- [Backend build — تشغيل PR الحالي](https://github.com/gfa437926-tech/metra2027/actions/runs/42922948212) — **قيد التنفيذ عند وقت هذا التحديث**.
- [Client CI — تشغيل سابق على commit مختلف](https://github.com/gfa437926-tech/metra2027/actions/runs/42922825265) — نجاح، لكنه لا يثبت نجاح التعديل الحالي.
- لم تُعلن أي اختبارات جديدة ناجحة دون نتيجة تشغيل فعلية.

## Pull Request وCommit

- PR: [#30](https://github.com/gfa437926-tech/metra2027/pull/30) — مفتوح، Draft، غير مدمج.
- الفرع: [security/initial-hardening-audit](https://github.com/gfa437926-tech/metra2027/tree/security/initial-hardening-audit).
- Commit التنفيذ الأول: [1bb0267619d310a2efaecf427bb1fe8707034452](https://github.com/gfa437926-tech/metra2027/commit/1bb0267619d310a2efaecf427bb1fe8707034452).

## العوائق والمهام المتبقية

عدد حزم العمل المتبقية: **7**:
1. التحقق من نتائج CI الحالية ومعالجة أي فشل.
2. تنفيذ Rate Limiting واختبارات 429 بعد تحديد proxy/forwarded headers الموثوقة.
3. إضافة HSTS وsecurity headers وسياسة CSP مناسبة والتحقق منها.
4. فرض حدود عامة لأحجام الطلبات واختبار 413.
5. استكمال فحص XSS/DOM/session storage وFlutter dependencies.
6. التحقق من الأسرار وتاريخ Git وإعدادات النشر الفعلية دون كشف أي قيمة سرية.
7. إجراء اختبارات صلاحيات متعددة الحسابات/المحطات/السلطات واختبارات JWT وIDOR قبل الإنتاج.

**العائق الرئيسي:** لا توجد في المستودع بيئة إنتاج مؤكدة أو هوية مستخدمين فعلية لاختبار التفويض عبر السلطات والمحطات. يتطلب ذلك بيئة معتمدة وحسابات اختبار، دون تغيير قاعدة البيانات أو RLS دون موافقة المستخدم.

## الخطوة التالية

مراجعة مخرجات Client CI وBackend build على PR #30 فور انتهائها، ثم تحديث هذا الملف وسجل التغييرات بنتيجة فعلية وروابط التشغيل، قبل تنفيذ تقوية API الآمنة.


## توثيق GitHub بعد الجولة

- **تاريخ المراجعة الإضافية:** 2026-11-10T23:29:37.567Z.
- Commit تحديث سجل التغييرات: [34c3c54af6f602be73f6529b4bdaabe9fc96efb5](https://github.com/gfa437926-tech/metra2027/commit/34c3c54af6f602be73f6529b4bdaabe9fc96efb5).
- تم تحديث وصف PR #30 ليربط تقرير التقدم وسجل التغييرات.
- بعد هذا التوثيق، شُغّلت مجدداً فحوص Client CI وBackend build على HEAD الجديد؛ كان Client CI بحالة pending وBackend build بحالة queued عند التحقق. لا توجد نتيجة نهائية بعد.
- الحالة الحالية لطلب المراجعة: مفتوح، Draft، غير مدمج؛ HEAD: `34c3c54af6f602be73f6529b4bdaabe9fc96efb5`.


## جولة متابعة — تقوية ترويسات API

**تاريخ التحديث:** 2026-11-10T23:31:02.214Z UTC  
**المهمة:** SEC-07  
**الحالة:** قيد التنفيذ  
**نسبة إنجاز المهمة:** 35% (تقدير موزون لنطاق SEC-07 فقط؛ أُضيفت معالجة ترويسات API كجزء منفذ مع اختبار آلي، بينما بقية حزم التحقق الديناميكي والاعتماديات والإنتاج لم تكتمل).

### الملفات التي فُحصت في هذه الجولة
- `backend/Metra.Api/Program.cs`
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs`
- `backend/Metra.Api.Tests/Metra.Api.Tests.csproj`
- حالة PR #30، حالة الفرع، وسجلات GitHub Actions.

### الملفات التي عُدلت
- `backend/Metra.Api/Program.cs` — إضافة `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, وسياسة CSP مقيدة لاستجابات API، وتفعيل HSTS خارج Development.
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs` — إضافة اختبار يتحقق من وجود الترويسات الخمس في استجابة health.

### المنفذ فعلياً
- إضافة middleware لترويسات الأمان على استجابات API.
- تفعيل HSTS في البيئات غير Development.
- إضافة اختبار تكاملي للترويسات.
- لم يُضف Rate Limiting بعد؛ يلزم حسم بنية reverse proxy وموثوقية forwarded headers حتى لا تُجمع عناوين العملاء أو تُطبق حدود غير صحيحة.

### الاختبارات وActions
- [Backend build على commit e9fd620 السابق](https://github.com/gfa437926-tech/metra2027/actions/runs/42923822634) — Success، لكنه لا يشمل التغييرات الحالية.
- [Client CI على commit e9fd620 السابق](https://github.com/gfa437926-tech/metra2027/actions/runs/42923822616) — Success، لكنه لا يختبر تغييرات Backend الحالية.
- [Backend build على commit f68e065](https://github.com/gfa437926-tech/metra2027/actions/runs/42923854797) — Success على SHA مختلف عن HEAD الذي تحققت منه؛ لا يُنسب نجاحه إلى التغييرات الحالية.
- عند تسجيل هذه الجولة، لم يظهر تشغيل نهائي موثق للـ HEAD الحالي `1bf6e3ab14901d7d1cb31a2e7fc513e7ba4b2ccb`. اختبار الترويسات لم يُعلن ناجحاً بعد.

### Commit وPR
- آخر commit في الفرع وقت تسجيل الجولة: [1bf6e3ab14901d7d1cb31a2e7fc513e7ba4b2ccb](https://github.com/gfa437926-tech/metra2027/commit/1bf6e3ab14901d7d1cb31a2e7fc513e7ba4b2ccb).
- [الفرع security/initial-hardening-audit](https://github.com/gfa437926-tech/metra2027/tree/security/initial-hardening-audit).
- [PR #30](https://github.com/gfa437926-tech/metra2027/pull/30) — مفتوح، Draft، غير مدمج.

### ما لم يُنفذ والعوائق
- لم يُنفذ Rate Limiting، ولا حدود body عامة، ولا تدقيق XSS كامل، ولا مراجعة تاريخ الأسرار، ولا اختبارات صلاحيات حقيقية متعددة الحسابات.
- لم تُعدل قاعدة البيانات أو RLS، ولم يحدث نشر أو دمج.
- العائق: عدم توثيق proxy/forwarded headers والـ production hostname؛ وعدم وجود هوية اختبار إنتاجية متعددة المحطات والسلطات.

### المتبقي والخطوة التالية
- **7 حزم متابعة**: تحقق CI على HEAD؛ Rate Limiting بعد تحديد proxy؛ request-body limits؛ مراجعة CSP/XSS/session؛ فحص Flutter وملفات الاعتماديات؛ تدقيق Git history/secrets والنشر؛ واختبارات IDOR وتداخل المحطات والسلطات.
- الخطوة التالية: التأكد من تشغيل Backend build وClient CI على HEAD الحالي، ثم معالجة أي فشل قبل تنفيذ تقوية إضافية.


## تحقق CI على التغييرات الأمنية الحالية

**وقت التحقق:** 2026-11-10T23:31:36.078Z UTC.  
**Commit الكود الذي اختُبرت عليه التغييرات:** [deb1b86b0a7e9f53a5ec07787edbed7c7755bb04](https://github.com/gfa437926-tech/metra2027/commit/deb1b86b0a7e9f53a5ec07787edbed7c7755bb04).

فحوص GitHub Actions على SHA المذكور كانت جميعها **قيد التنفيذ** وقت الاستعلام، ولم تُعلن ناجحة:
- [Backend build — run 42924025780](https://github.com/gfa437926-tech/metra2027/actions/runs/42924025780).
- [Angular build — run 42924025817](https://github.com/gfa437926-tech/metra2027/actions/runs/42924025817).
- [Flutter analyze and test — run 42924025817](https://github.com/gfa437926-tech/metra2027/actions/runs/42924025817).

هذا التحقق يؤكد أن CI بدأ على HEAD الخاص بـ PR #30. لا يوجد حتى هذه اللحظة تأكيد نجاح بناء .NET أو اختبار ترويسات API؛ يجب إعادة فحص النتيجة النهائية قبل اعتماد التغيير.


## جولة متابعة — Rate Limiting على API

**تاريخ التحديث:** 2026-11-10T23:34:50.847Z UTC  
**المهمة:** SEC-07 — حماية API من إساءة الاستخدام  
**الحالة:** قيد التنفيذ  
**نسبة إنجاز المهمة:** 40% من نطاق SEC-07 فقط (تقدير موزون؛ تمت إضافة rate limiting مع اختبار تكاملي، لكن التحقق الآلي لم ينتهِ بعد، كما أن ضبط proxy موثوق لم يُعتمد).

### ما تمت مراجعته
- `backend/Metra.Api/Program.cs` — خط أنابيب HTTP والمصادقة وترويسات الحماية.
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs` — اختبارات API الأمنية.
- `render.yaml` — إعداد نشر Render ومسار readiness؛ لا يتضمن إعداداً صريحاً لسلسلة proxies موثوقة.
- `.github/workflows/backend-ci.yml` — خطوات البناء واختبارات .NET.

### الملفات المعدلة
- `backend/Metra.Api/Program.cs`: إضافة global fixed-window rate limiter؛ 120 طلباً/دقيقة لكل JWT subject موثّق، و30 طلباً/دقيقة لمسار الطلبات غير المصادق عليها. لا يعتمد partitioning على `X-Forwarded-For` أو أي ترويسة عميل غير موثوقة. إضافة `Retry-After: 60` عند HTTP 429. ترتيب middleware صريح: routing ثم CORS ثم authentication ثم rate limiter ثم authorization. استثناء liveness `/api/v1/health` من الحصة حتى لا تتعطل مراقبة الخدمة؛ readiness يبقى خاضعاً للحصة.
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs`: اختبار يرسل 30 طلب readiness متتالياً ويتوقع رفض الطلب 31 بـ 429 مع `Retry-After`.

### ملاحظة تشغيلية مهمة
- لا يوجد في ملفات النشر التي تمت مراجعتها تعريف موثّق للـ trusted proxy chain أو forwarded headers؛ لذلك لم يتم تفعيل الثقة في `X-Forwarded-For`. الحصة الحالية للطلبات المجهولة مشتركة على مستوى العملية، وليست per-client-IP. هذا يمنع تزوير IP لكنه قد يجعل bucket المجهول مورداً مشتركاً؛ يجب حسم إعداد proxy الموثوق واختبار السلوك قبل الإنتاج. لم يتم ادعاء اكتمال هذا الجزء تشغيلياً.

### CI على HEAD الكودي
- آخر commit كودي يحوي التغييرات: [9689ab821a2dfb8200ded46cf30c33ed8068208f](https://github.com/gfa437926-tech/metra2027/commit/9689ab821a2dfb8200ded46cf30c33ed8068208f).
- [Backend build — run 42924494881](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494881) — queued وقت الفحص.
- [Client CI — run 42924494937](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494937) — pending وقت الفحص.
- لا توجد نتيجة نهائية بعد؛ لا نعلن نجاح الاختبارات قبل اكتمال التشغيل.

### GitHub وPR
- الفرع: [security/initial-hardening-audit](https://github.com/gfa437926-tech/metra2027/tree/security/initial-hardening-audit).
- PR [#30](https://github.com/gfa437926-tech/metra2027/pull/30) مفتوح، Draft، غير مدمج.
- Commit التوثيق لهذه الجولة سيُسجل بعد إضافة هذا التقرير وسجل التغييرات.

### حدود التنفيذ
- لا تغييرات في قاعدة البيانات أو migrations أو RLS أو حسابات المستخدمين.
- لا نشر ولا دمج إلى `main`.

### المتبقي والخطوة التالية
- **7 حزم متابعة:** التحقق من CI واختبار 429؛ اعتماد trusted proxy/forwarded headers ثم تحسين partitioning per-client؛ حدود request body؛ مراجعة CSP/XSS/session؛ فحص Flutter dependencies؛ تدقيق Git history والأسرار وإعدادات النشر؛ واختبارات صلاحيات متعددة الحسابات والمحطات والسلطات.
- الخطوة التالية: مراجعة Backend build على HEAD ومعالجة أي أخطاء ترجمة أو اختبار قبل توسيع إعدادات proxy أو تنفيذ حدود body.


## معالجة فشل اختبارات Rate Limiting وإعادة التحقق

**تاريخ التحديث:** 2026-11-10T23:35:50.983Z UTC.  
**Commit الإصلاح:** [2d285d6c446364976d340233993aca34d18e1d73](https://github.com/gfa437926-tech/metra2027/commit/2d285d6c446364976d340233993aca34d18e1d73).

### نتيجة CI السابقة على commit 9689ab8
- [Backend build run 42924494881](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494881) فشل في مرحلة الاختبارات، بينما نجح restore وبناء API وجميع اختبارات عقود SQL.
- سجل الاختبارات: 226 ناجحاً و8 فاشلة من أصل 234. سبب الفشل كان استهلاك الحصة المجهولة المشتركة من عدة اختبارات متوازية؛ أصبحت بعض اختبارات المصادقة وreadiness تتلقى 429 بدلاً من 401/503.

### الإصلاح
- تم تعديل `Program.cs`: الـ global limiter يطبق الآن 120 طلباً/دقيقة لكل JWT subject موثّق فقط؛ لا تُشارك طلبات عدم المصادقة في حصة واحدة مع اختبارات ونقاط API الأخرى.
- تم تخصيص policy مستقلة باسم `readiness` بحد 30 طلباً/دقيقة لحماية فحص Supabase المكلف؛ liveness يبقى مستثنى.
- بقيت الاستراتيجية دون اعتماد على `X-Forwarded-For` حتى تعريف trusted proxy chain.
- اختبار readiness يستنفد الحصة المخصصة ويتحقق من 429 و`Retry-After`.

### إعادة التحقق
- [Backend build على commit الإصلاح — run 42924648212](https://github.com/gfa437926-tech/metra2027/actions/runs/42924648212) — قيد التنفيذ وقت هذا التحديث؛ لا نتيجة نهائية بعد.
- لا نعتبر إصلاح الاختبارات ناجحاً حتى ينتهي التشغيل بنتيجة Success.

**الحالة:** SEC-07 قيد التنفيذ، نسبة الإنجاز 40% من نطاق المهمة فقط. PR [#30](https://github.com/gfa437926-tech/metra2027/pull/30) مفتوح Draft وغير مدمج. لا تغييرات DB/RLS ولا نشر.


## متابعة أمنية — تأكيد CI وحدود حجم الطلبات

**التاريخ:** 2026-11-11 UTC  
**المهمة:** SEC-07 — الأمن السيبراني وحماية المعلومات  
**الحالة:** قيد التنفيذ  
**نسبة الإنجاز التقديرية:** 45% من نطاق المساعد رقم 7 فقط.  
**طريقة الحساب:** إنجاز المراجعة الساكنة الأولية، وقواعد تجاهل الأسرار، وفحص npm، وترويسات API/HSTS، وRate Limiting مع اختبارات CI ناجحة؛ إضافة إلى تنفيذ سقف body على مستوى Kestrel ورفض Content-Length الزائد مع اختبارات حدودية، بانتظار CI لهذه الجولة.

### تحقق CI
- [Backend build run 42924648212](https://github.com/gfa437926-tech/metra2027/actions/runs/42924648212) — **Success** على commit `2d285d6c446364976d340233993aca34d18e1d73`؛ job `build` مكتمل بنجاح.
- [Backend build run 42924701188](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701188) — **Success** على commit التوثيق `32e5ecce8db2ad8899a49174d9d628fa1faf193b`.
- [Client CI run 42924701234](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701234) — **Success** على SHA نفسه.
- بعد إضافة سقف حجم الطلبات والاختبارات، بدأ [Backend build run 42925267116](https://github.com/gfa437926-tech/metra2027/actions/runs/42925267116) بحالة **in_progress**، و[Client CI run 42925267010](https://github.com/gfa437926-tech/metra2027/actions/runs/42925267010) بحالة **queued** عند التحديث. لا تُنسب لهما نتيجة نجاح قبل اكتمالهما.

### الملفات التي عُدلت في هذه الجولة
- `backend/Metra.Api/Program.cs`: تحديد حد أقصى عام لحجم body قدره 1 MiB عبر Kestrel، مع middleware يرفض Content-Length الأكبر من الحد قبل المصادقة وربط النماذج. حد Kestrel يبقى طبقة الإنفاذ للطلبات chunked/streamed.
- `backend/Metra.Api.Tests/Security/ApiAuthenticationTests.cs`: إضافة اختبار يثبت رفض 1 MiB + 1 بايت بـ HTTP 413، واختبار أن 1 MiB بالضبط لا يُرفض بواسطة middleware ويصل إلى طبقة المصادقة.

### القيود والمخاطر المفتوحة
- لم يُعتمد trusted proxy chain؛ لذلك لا يتم الوثوق بـ `X-Forwarded-For` ولا تقسيم الحصة المجهولة حسب IP.
- سقف 1 MiB إعداد عام أولي؛ يجب التأكد من ملاءمته لكل عقود الطلبات الفعلية، وخاصة أي عمليات استيراد أو ملفات كبيرة، قبل الإنتاج.
- لم تُجر اختبارات على خدمة حية، ولم تُعدل قاعدة البيانات أو migrations أو RLS أو حسابات المستخدمين.

### المتبقي والخطوة التالية
- **6 حزم متابعة:** (1) التحقق النهائي من CI على سقف body، (2) trusted proxy والحدود per-client، (3) تدقيق CSP/XSS وتخزين جلسة Angular، (4) فحص Flutter dependencies، (5) تدقيق Git history والأسرار وإعدادات النشر، (6) اختبارات IDOR وتداخل صلاحيات الحسابات والمحطات والسلطات.
- PR [#30](https://github.com/gfa437926-tech/metra2027/pull/30) ما زال مفتوحاً Draft وغير مدمج. لا نشر ولا تغييرات DB/RLS.
