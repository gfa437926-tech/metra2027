# METRA 2027 — Complete Screen Inventory

**Baseline branch:** `work/metra-all-workspaces-ui-2026-11-15`  
**Documentation branch:** `docs/metra-complete-ui-specifications-2026-11-16`  
**Scope:** Flutter first; Angular deferred.

## Legend
- **واجهة موجودة**: يوجد ملف Flutter مخصص.
- **جزئي/موزع**: توجد أجزاء من الوظيفة ضمن شاشات أخرى أو نموذج قديم.
- **غير مثبت**: لم يظهر تنفيذ Flutter مستقل أو عقد API واضح.
- **غير موصول/محكوم**: لا يجوز وصف التكامل بأنه إنتاجي قبل نشر الخدمة والتحقق منها.

## جرد الصفحات

| # | الصفحة | الدور الأساسي | مواصفة Markdown | ملف Flutter الحالي | مرجع HTML قديم | التصميم/التنفيذ حسب الحصر |
|---:|---|---|---|---|---|---|
| 1 | تسجيل الدخول والمصادقة | جميع المستخدمين | [هوية ووصول](identity-access.md) | `core/auth/metra_auth.dart` | `index.html` (يلزم فحص المطابقة) | جزئي؛ تحقق من تدفق المزود |
| 2 | التسجيل وطلبات الحساب | مستخدم جديد/مدير النظام | [هوية ووصول](identity-access.md) | `features/admin/user_management_screen.dart` | نماذج قديمة يلزم تعيينها | scaffold جزئي |
| 3 | استعادة كلمة المرور | المستخدم | [هوية ووصول](identity-access.md) | `core/auth/metra_auth.dart` | غير مثبت | جزئي/تحقق مطلوب |
| 4 | الرئيسية ولوحة المؤشرات | جميع الأدوار وفق الصلاحية | [مساحات الإدارات](departments/department-workspaces.md) | `features/home/metra_home.dart` | `main.html`, `manager-dashboard.html` | موجودة؛ المؤشرات تعتمد على API |
| 5 | دليل المحطات | مستخدم المحطة/الأدوار الشاملة | [رئيس دائرة الشبكات](network-management/network-director.md) | `features/stations/station_directory_screen.dart` | لا يوجد مرجع محدد | موجود؛ النطاق محكوم بالخادم |
| 6 | سجل تدقيق المحطة | المدقق/المخول | [المدقق](audit/auditor.md) | `features/stations/station_audit_log_screen.dart` | لا يوجد مرجع محدد | موجود؛ تحقق من RPC/staging |
| 7 | التنبؤ ومراكز التنبؤ | مختص التنبؤ | [مراكز التنبؤ](forecast/forecast-centres.md) | `features/forecast_centres/forecast_centre_screen.dart` | لا يوجد مرجع محدد | واجهة موجودة؛ feed pending |
| 8 | إدخال الرصد الساعي | الراصد | [الرصد الساعي](observations/hourly-entry.md) | `features/observations/hourly_observation_entry_screen.dart` | `hourly_reports.html`, `h_climate_send.html` | موجودة؛ الإرسال gated |
| 9 | إدخال الرصد اليومي | الراصد | [الرصد اليومي](observations/daily-entry.md) | `features/observations/daily_observation_entry_screen.dart` | `daily.html`, `daily_reports.html` | موجودة؛ الإرسال gated |
| 10 | الظواهر الجوية | الراصد/المدقق | [الظواهر](phenomena/phenomena.md) | ضمن daily form؛ لا شاشة مستقلة مثبتة | `phenomena.html`, `weather_phenomena.html` | جزئي/موزع |
| 11 | الأمطار والهطول | الراصد/المختص | [الأمطار](rainfall/rainfall.md) | لا شاشة مستقلة مثبتة | `rainfall_reports.html` | مرجع قديم + mapping؛ Flutter مستقل غير مثبت |
| 12 | البيانات الزراعية | المختص الزراعي | [الزراعة](agriculture/agriculture.md) | لا شاشة مستقلة مثبتة | `agricultural_reports.html` | مرجع قديم + mapping؛ Flutter مستقل غير مثبت |
| 13 | بيانات التربة | المختص | [الزراعة](agriculture/agriculture.md) | لا شاشة مستقلة مثبتة | `soil_temperature.html`, `soil-send.html` | يلزم فصلها عن الحقول الزراعية |
| 14 | البيانات المناخية | مختص المناخ | [المناخ](climate/climate.md) | جزئياً ضمن Climatol/التقارير | `climate_hourly_reports.html` | جزئي؛ يلزم تحديد نموذج الإدخال |
| 15 | مراجعة واعتماد الأرصاد | المدقق/رئيس المحطة | [مراجعة الرصد](observations/review-workflow.md) | `features/observations/observation_review_screen.dart` | لا يوجد مرجع محدد | موجود؛ staging/RPC pending |
| 16 | التدقيق الإلكتروني | المدقق | [المدقق](audit/auditor.md) | `features/audit/electronic_audit_screen.dart` | لا يوجد مرجع محدد | read-only وفق التتبع |
| 17 | التقارير | المستخدم المخول | [التقارير والأرشيف](reports/reports-archive.md) | `features/reports/reports_hub_screen.dart` | عدة ملفات تقارير | موجود؛ export/print جزئي |
| 18 | أرشيف الرصد | المستخدم المخول | [التقارير والأرشيف](reports/reports-archive.md) | `features/reports/observation_archive_screen.dart` | ملفات تقارير متعددة | موجود؛ fail-closed حتى نشر الخدمات |
| 19 | إدارة المستخدمين | مدير النظام | [مدير النظام](system-administration/system-administrator.md) | `features/admin/user_management_screen.dart` | `fix.html`, `fix-tel.html` | scaffold/واجهة موجودة |
| 20 | إدارة الأجهزة والمعايرة | مسؤول الأجهزة/الورشة | [أعطال الأجهزة](equipment-faults/instrument-faults.md) | `features/instruments/instrument_management_screen.dart` | `workshop-manager.html` | مسودات محلية؛ backend pending |
| 21 | أعطال أجهزة الرصد | فني/رئيس محطة | [أعطال الأجهزة](equipment-faults/instrument-faults.md) | لا شاشة أعطال مستقلة مثبتة | `workshop-manager.html` | غير مثبت كمسار متكامل |
| 22 | أعطال الاتصالات | فني الاتصالات/FTN | [أعطال الاتصالات](telecom/telecom-faults.md) | لا شاشة Flutter مستقلة مثبتة | `telecom-manager.html`, `it.html` | غير مثبت |
| 23 | إدارة FTN | مسؤول FTN | [مسؤول FTN](telecom/ftn-operator.md) | لا شاشة Flutter مستقلة مثبتة | `it-maneger.html`, `it.html` | غير مثبت |
| 24 | رئيس المحطة | رئيس المحطة | [رئيس المحطة](station-management/station-head.md) | موزع على المحطات والمراجعة | `manager-dashboard.html` | لا شاشة دور مستقلة مثبتة |
| 25 | رئيس دائرة الشبكات | رئيس دائرة الشبكات | [رئيس الشبكات](network-management/network-director.md) | دليل المحطات جزئياً | `manag-net.html` | لا لوحة شبكات مستقلة مثبتة |
| 26 | مدير النظام | مدير النظام | [مدير النظام](system-administration/system-administrator.md) | إدارة المستخدمين جزئياً | `fix.html` | جزئي |
| 27 | مدير الرصد/مدير المناخ والإدارات | مدراء الإدارات | [مساحات الإدارات](departments/department-workspaces.md) | لا شاشات مستقلة لكل إدارة مثبتة | `main.html`, `manager-dashboard.html` وغيرها | غير مكتمل التوثيق/التنفيذ |
| 28 | الذكاء الاصطناعي | مختص AI/المدقق | [الذكاء الاصطناعي](ai/ai-workspace.md) | `features/ai/ai_workspace_screen.dart` | لا يوجد | UI موجود؛ backend pending |
| 29 | CLIMATOL والتجانس | مختص المناخ | [المناخ](climate/climate.md) | `features/climatol/climatol_workspace_screen.dart` | لا يوجد | إعداد واجهة؛ runtime pending |
| 30 | السجلات المصورة والرقمنة | فني/مدقق | [السجلات والرقمنة](records/records-digitization.md) | `features/records/records_review_workspace_screen.dart` | لا يوجد | workspace وطلبات typed؛ OCR/backend pending |
| 31 | مقارنة الصورة بالحقيقة المرجعية | المدقق العلمي | [السجلات والرقمنة](records/records-digitization.md) | ضمن records workspace؛ الشاشة الفرعية تحتاج تحقق | لا يوجد | مواصفة مطلوبة؛ تنفيذ مستقل غير مثبت |
| 32 | الإعدادات والحساب والمساعدة | جميع المستخدمين | [الإعدادات](settings.md) | `features/home/metra_home.dart` (_SettingsPage) | `sidebar.html` | موجودة جزئياً |
| 33 | أعطال الشبكات/إدارة الشبكة | رئيس الشبكات/FTN | [أعطال الاتصالات](telecom/telecom-faults.md) | غير مثبت | `manag-net.html` | غير مثبت كواجهة Flutter |

## الملفات المرجعية الحالية
- `docs/delivery/METRA-FLUTTER-INTERFACE-CATALOG-2026-11-15.md`
- `docs/delivery/FLUTTER-NAVIGATION-MAP.md`
- `docs/delivery/FLUTTER-UI-REQUIREMENTS-TRACEABILITY.md`
- `docs/delivery/FLUTTER-UI-REMAINING-GAPS.md`

## الخلاصة التنفيذية
وجود HTML قديم أو مواصفة Markdown لا يعني وجود شاشة Flutter مكتملة. الأولوية التنفيذية بعد هذا الجرد:
1. فصل الظواهر/المطرية/الزراعية/المناخية إلى شاشات أو وحدات واضحة بناءً على النماذج المصدرية.
2. تصميم واجهات رئيس المحطة ورئيس دائرة الشبكات والمدقق ومدير النظام ومسؤول FTN كمساحات دور واضحة.
3. تعريف واعتماد عقود أعطال الاتصالات وأعطال الأجهزة قبل ربطها.
4. استكمال مصفوفة الأدوار وواجهات الإدارات.
5. اختبار كل شاشة فعلياً على الهاتف والكمبيوتر وعبر APIs staging.

**لا تعتبر أي خانة غير مثبتة مكتملة لمجرد إضافة هذه الوثيقة.**
