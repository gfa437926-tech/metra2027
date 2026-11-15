# METRA 2027 — اكتمال واجهات Flutter (2026-11-15)

**الفرع:** `work/flutter-full-interface-completion-2026-11-15`  
**الأساس:** `work/metra-all-workspaces-ui-2026-11-15`  
**التطبيق:** `mobile/metra_mobile/` فقط — بدون مشروع Flutter جديد.

## الواجهات الرئيسية الـ14 (منفّذة ومربوطة بالتنقل)

| # | الوجهة | الملف |
|---:|---|---|
| 1 | الرئيسية | `features/home/metra_home.dart` |
| 2 | المحطات | `features/stations/station_directory_screen.dart` |
| 3 | التنبؤ | `features/forecast_centres/forecast_centre_screen.dart` |
| 4 | ساعي | `features/observations/hourly_observation_entry_screen.dart` |
| 5 | يومي | `features/observations/daily_observation_entry_screen.dart` |
| 6 | مراجعة | `features/observations/observation_review_screen.dart` |
| 7 | تدقيق | `features/audit/electronic_audit_screen.dart` |
| 8 | تقارير | `features/reports/reports_hub_screen.dart` (+ أرشيف) |
| 9 | ذكاء اصطناعي | `features/ai/ai_workspace_screen.dart` (6 أقسام) |
| 10 | CLIMATOL | `features/climatol/climatol_workspace_screen.dart` (6 أقسام) |
| 11 | مستخدمون | `features/admin/user_management_screen.dart` |
| 12 | إعدادات | داخل `metra_home.dart` |
| 13 | السجلات/المسجلات | `features/records/records_review_workspace_screen.dart` |
| 14 | الأجهزة | `features/instruments/instrument_management_screen.dart` (6 أقسام) |

## توسيع 2026-11-15

- مكوّن مشترك: `core/widgets/metra_workspace_shell.dart`
- مركز التقارير: أقسام تشغيلية / مناخية / جودة / تصدير
- مختبر AI: بيانات، وسم، تدريب، تقييم، مستودع، مراقبة
- CLIMATOL: مجموعات، فحص، انقطاعات، تشغيل، نتائج، تقارير
- الأجهزة: سجل، توزيع، معايرة، أعطال، صيانة، تقارير

## حدود الأمان والصدق

- لا بيانات علمية وهمية تُعرض كتشغيلية.
- AI / CLIMATOL / الأجهزة / المسجلات: واجهات كاملة مع مسودات محلية وempty states حتى توفر API.
- الرصد الساعي/اليومي/المراجعة/الأرشيف/المستخدمون: مسارات API موجودة؛ الكتابة العلمية تبقى gated حسب إعداد الخادم.
- Angular مؤجّل؛ لا `flutter create`.

## التشغيل

```bash
cd mobile/metra_mobile
flutter pub get
flutter analyze --no-fatal-infos
flutter test --concurrency=1
```
