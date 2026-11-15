# مواصفات واجهات METRA 2027

هذه الوثائق هي مرجع حصر ومواصفات واجهات Flutter ذات الأولوية. أُنشئت على فرع توثيق مستقل، بالاستناد إلى الملفات الموجودة في المستودع وقت إعدادها.

## حدود الدقة
- **موجود**: يوجد ملف/مسار واضح في المستودع.
- **جزئي**: توجد شاشة أو وثيقة مرتبطة، لكن لا يثبت ذلك اكتمال كل الحقول أو السلوك.
- **غير مثبت**: لم يظهر تنفيذ Flutter مخصص أو عقد خدمة مثبت في الفحص الحالي.
- أسماء الحقول التفصيلية لا تُخترع. تُستخرج من نماذج المصدر وملفات mapping والعقود العلمية المعتمدة قبل اعتماد التنفيذ.
- وجود مواصفة لا يعني أن الواجهة أو التكامل جاهز إنتاجياً.

## خريطة الملفات
| المجال | المواصفة |
|---|---|
| الرصد الساعي | [hourly-entry](observations/hourly-entry.md) |
| الرصد اليومي | [daily-entry](observations/daily-entry.md) |
| مراجعة واعتماد الرصد | [review-workflow](observations/review-workflow.md) |
| الظواهر الجوية | [phenomena](phenomena/phenomena.md) |
| الأمطار والهطول | [rainfall](rainfall/rainfall.md) |
| البيانات الزراعية | [agriculture](agriculture/agriculture.md) |
| إدخال البيانات المناخية والتجانس | [climate](climate/climate.md) |
| أعطال الاتصالات | [telecom-faults](telecom/telecom-faults.md) |
| أعطال أجهزة الرصد | [instrument-faults](equipment-faults/instrument-faults.md) |
| المدقق | [auditor](audit/auditor.md) |
| رئيس المحطة | [station-head](station-management/station-head.md) |
| رئيس دائرة الشبكات | [network-director](network-management/network-director.md) |
| مسؤول FTN والاتصالات | [ftn-operator](telecom/ftn-operator.md) |
| مدير النظام | [system-administrator](system-administration/system-administrator.md) |
| صفحات الإدارات | [department-workspaces](departments/department-workspaces.md) |
| التقارير والأرشيف | [reports-archive](reports/reports-archive.md) |
| مراكز التنبؤ | [forecast-centres](forecast/forecast-centres.md) |
| السجلات المصورة والرقمنة | [records-digitization](records/records-digitization.md) |
| الذكاء الاصطناعي | [ai-workspace](ai/ai-workspace.md) |

## مواصفات إضافية
- [الجرد الشامل لجميع الشاشات](METRA-COMPLETE-SCREEN-INVENTORY.md)
- [المصادقة والتسجيل واستعادة الحساب](identity-access.md)
- [الإعدادات والحساب](settings.md)

## ملفات المصدر الحالية ذات الصلة
- Flutter: `mobile/metra_mobile/lib/features/**`
- نظام التصميم: `mobile/metra_mobile/lib/core/widgets/metra_ui.dart`
- التنقل التكيفي: `mobile/metra_mobile/lib/core/widgets/metra_adaptive_navigation.dart`
- المصادقة: `mobile/metra_mobile/lib/core/auth/metra_auth.dart`
- كتالوج الواجهات: `docs/delivery/METRA-FLUTTER-INTERFACE-CATALOG-2026-11-15.md`
- خريطة التنقل: `docs/delivery/FLUTTER-NAVIGATION-MAP.md`
- تتبع المتطلبات: `docs/delivery/FLUTTER-UI-REQUIREMENTS-TRACEABILITY.md`
- فجوات الواجهة: `docs/delivery/FLUTTER-UI-REMAINING-GAPS.md`
- mappings: `docs/form-label-mapping-*.md`

## ضوابط ثابتة
1. Flutter هو الأولوية الحالية؛ Angular مؤجل.
2. العربية وRTL إلزاميان، مع تصميم متجاوب وتجنب تكرار القائمة الجانبية.
3. المستخدم العادي مقيد بمحطته المخصصة. رئيس دائرة الشبكات والمدققون المخولون يمكنهم القراءة الشاملة وفق تفويض الخادم.
4. لا يُسمح باستنتاج الصلاحيات من إخفاء عناصر الواجهة؛ الخادم هو المرجع النهائي.
5. لا تعديل على قاعدة البيانات المستضافة أو قاعدة البيانات القديمة، ولا تنفيذ migrations دون مراجعة واعتماد صريح.
6. لا مفاتيح سرية أو service-role داخل Flutter.
7. أي بيانات توضيحية يجب تمييزها بوضوح كبيانات تجريبية.
8. لا يُعلن اكتمال شاشة إلا بعد تنفيذها واختبارها وتوثيق نتيجة الاختبار.

## دورة اعتماد كل صفحة
تحليل المصدر القديم/النموذج ← مطابقة الحقول ← اعتماد العقد العلمي ← تنفيذ Flutter ← ربط API مصرح به ← اختبارات widget/API/صلاحيات ← مراجعة RTL والاستجابة ← اعتماد الحالة.
