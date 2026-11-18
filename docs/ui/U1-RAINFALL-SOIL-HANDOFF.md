# خطة الانتقال إلى U1 — Rainfall + Soil (بدون تنفيذ DB)

**الحالة:** جاهزة للتنفيذ بعد **موافقة مستقلة** من المالك على أي تغيير guard/RPC/schema.  
**مرجع الاعتماد:** `SEVEN-FORMS-APPROVAL-RECORD.md` (D1–D7) + `PHASE1-RAINFALL-SOIL.md`.

## ما هو مسموح الآن (قبل موافقة DB)

| بند | مسموح؟ |
|---|---|
| تحسين تحقق Flutter المحلي | نعم (منفَّذ جزئياً: decimal بلا حدود غير موثقة) |
| اختبارات مستودع محلي | نعم |
| توسيع `ObservationSubmissionRequestGuard` | **لا** دون موافقة |
| تعديل RPC / RLS / migrations | **لا** دون موافقة |
| منح صلاحيات إنتاج | **لا** |

## خطوات U1 المقترحة بعد الموافقة المستقلة

1. **API/.NET**  
   - السماح بـ `observationType` = `rainfall` | `soil` في الحارس فقط بعد جاهزية الحفظ.  
   - Validator مجالي: required = `observationDate` + `responsibilityAgreement==true`؛ أرقام منتهية للحقول الاختيارية ذات النوع decimal؛ **بلا** min/max أرصادية غير موثقة (D5).  
   - الإبقاء على JWT `sub` + `observation.create` + عزل المحطة.

2. **Supabase** (موافقة صريحة منفصلة)  
   - قبول النوعين في مسار الحفظ المعتمد دون خلط جداول الأعطال (D1).

3. **Flutter**  
   - مسار submit حقيقي لـ rainfall/soil بدل `awaitingApiContract`.  
   - رسائل عربية موحّدة مع hourly.  
   - الإبقاء على لافتة «محلي فقط» للأنواع غير المربوطة.

4. **اختبارات**  
   - .NET: guard + validator + 401/403.  
   - Flutter: submit ناجح/فاشل، منع تكرار، مسودة محطة.

## ترتيب لا يُنفَّذ في U1

- agricultural / hourlyclimate  
- fault* (D2 مؤجّل)  
- E2E / Staging
