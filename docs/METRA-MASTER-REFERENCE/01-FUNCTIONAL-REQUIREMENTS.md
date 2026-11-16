# 01 — المتطلبات الوظيفية الكاملة

الإصدار: FINAL-DRAFT-2026-11-15

حالة التنفيذ: **موجود في الكود** | **جزئي** | **موثق فقط** | **مطلوب غير منفذ** | **مقترح**.

| FR ID | الاسم عربي | English | أدوار | شاشة | API | الحالة | مصدر الإثبات |
|---|---|---|---|---|---|---|---|
| FR-OBS-HOURLY | إدخال الرصد الساعي | Hourly observation entry | Observer | SCR-HOURLY | API-OBS-SUBMIT | جزئي: UI + gate | metra-old hourly + Flutter |
| FR-OBS-DAILY | إدخال الرصد اليومي | Daily observation entry | Observer | SCR-DAILY | API-OBS-SUBMIT | جزئي: UI + gate | metra-old daily + Flutter |
| FR-OBS-AGRI | النشرة الزراعية | Agricultural bulletin | Observer | — (U-03) | TBD | قديم فقط | metra-old agri |
| FR-OBS-HCLIMATE | المناخ الساعي | Hourly climate | Observer | — (U-03) | TBD | قديم فقط | metra-old h_climate |
| FR-OBS-RAIN | نشرة الأمطار | Rainfall report | Observer | — (U-03) | TBD | قديم فقط | metra-old rain |
| FR-OBS-SOIL | حرارة التربة | Soil temperature | Observer | — (U-03) | TBD | قديم فقط | metra-old soil |
| FR-OBS-REVIEW | مراجعة واعتماد الرصدات | Observation review | Head/Auditor | SCR-REVIEW | API-OBS-DECISION | جزئي: UI + gate | Flutter + Endpoints |
| FR-OBS-QUEUE | قائمة انتظار المراجعة | Review queue | Head/Auditor | SCR-REVIEW | API-OBS-QUEUE | جزئي | ObservationQueueEndpoints |
| FR-OBS-VALIDATE | التحقق من الحمولة | Payload validation | system | — | API-OBS-VALIDATE-* | موجود | ObservationValidationEndpoints |
| FR-STATION-DIR | دليل المحطات | Station directory | Auth | SCR-STATIONS | API-STATIONS | جزئي live | StationDirectoryEndpoints |
| FR-STATION-AUDIT | سجل تدقيق المحطة | Station audit log | Granted | SCR-STATION-AUDIT | API-STATION-AUDIT | liveApi (client) | StationAuditEndpoints |
| FR-ARCHIVE | أرشيف الرصدات | Observation archive | Granted | SCR-ARCHIVE | API-ARCHIVE | fail-closed 503 | client + policy |
| FR-FAULT-EQ | بلاغ عطل أجهزة | Equipment fault | Workshop | SCR-INSTRUMENTS | TBD | UI جزئي | fix.html |
| FR-FAULT-TEL | بلاغ عطل اتصالات | Telecom fault | Telecom | — | TBD | قديم؛ فجوة U-04 | fix-tel.html |
| FR-FAULT-IT | بلاغ IT | IT fault | IT | — | TBD | قديم | it.html |
| FR-USERS-REG | تسجيل المستخدمين | User registration | Admin | SCR-USERS | API-REG-* | جزئي API | Registration endpoints |
| FR-AUTH-GRANT | منح الصلاحيات | Permission grants | Authority admin | SCR-USERS | API-AUTH-* | جزئي API | AuthorityAccessEndpoints |
| FR-REPORTS | مركز التقارير | Reports hub | roles vary | SCR-REPORTS | — | UI catalogue | reports_hub_screen |
| FR-FORECAST | مراكز التنبؤ | Forecast centres | Forecast | SCR-FORECAST | — | gated/mock | forecast_centre_screen |
| FR-CLIMATOL | التجانس المناخي | Climatol | Climate | SCR-CLIMATOL | — | UI only | climatol_workspace |
| FR-AI | مختبر AI | AI workspace | AI | SCR-AI | — | UI only | ai_workspace |
| FR-RECORDS | رقمنة السجلات | Records digitization | Records | SCR-RECORDS | — | UI only | records_review |
| FR-INSTRUMENTS | إدارة الأجهزة | Instruments | Workshop | SCR-INSTRUMENTS | — | UI sections | instrument_management |
| FR-SETTINGS | إعدادات الحساب | Settings | Self | SCR-SETTINGS | auth | present | metra_home |
| FR-HOME | الرئيسية والتنقل | Home navigation | Auth | SCR-HOME | — | present | metra_home.dart |

## قواعد مشتركة لكل FR تشغيلي
- المدخلات/المخرجات: حسب fields/* و api/*
- عزل محطة على الخادم
- نجاح: 2xx · فشل: 400/401/403/503/gate
- اختبارات: testing/TEST-MATRIX.md + TRACEABILITY
