# METRA 2027 — جاهزية الإنتاج

تاريخ التحديث: 2026-11-16  
الفرع: `feat/phenomenon-observation-submit-2026-11-16`  
PR: #55 (Draft) فوق أساس #54 (Draft)

## 1. بنية النظام

| الطبقة | التقنية |
|---|---|
| عميل | Flutter (`mobile/metra_mobile`) — عربي RTL |
| API | ASP.NET (`backend/Metra.Api`) |
| هوية | Supabase Auth (JWT) — مفتاح نشر عام في العميل فقط |
| بيانات | Supabase PostgreSQL عبر RPC من الخادم (Service Role على الخادم فقط) |

## 2. وحدات قابلة للاستخدام فعلياً (متصلة بالخادم)

| الوحدة | الوظائف |
|---|---|
| تسجيل الدخول/الخروج/استعادة كلمة المرور | Supabase Auth + تخزين جلسة آمن |
| الرصد الساعي | validate + submit + idempotency client + عرض أخطاء عربية |
| الرصد اليومي | نفس الساعي |
| الظواهر الجوية | validate + submit عبر عقود معتمدة |
| مراجعة الأرصاد | قائمة/قرار ضمن الصلاحيات |
| دليل المحطات | قراءة من API المعتمد |
| إدارة محطة (جزئي) | حسب endpoints الموجودة |

## 3. وحدات واجهة فقط / محلية

| الوحدة | الحالة |
|---|---|
| زراعي، مناخي ساعي، أمطار، تربة، أعطال (أجهزة/اتصالات/IT) | تحقق محلي + بانر «لا حفظ» |
| CLIMATOL | واجهة تنظيم — المحرك غير مُدّعى |
| أرشيف/AI/OCR | واجهات حالات — بلا نتائج وهمية كتحليل حقيقي |
| أجهزة/شبكات/تقارير موسّعة | تنظيم واجهات + عقود مقترحة |

## 4. واجهات API المتاحة (مختصر)

- `POST .../observations/hourly|daily|phenomena/validate`
- `POST /api/v1/stations/{stationId}/observations` (types: hourly, daily, phenomenon)
- قرارات المراجعة والطوابير حسب endpoints المسجّلة
- دليل المحطات، تسجيل المستخدمين، التدقيق، التعيينات (حسب الملفات في `Features/`)

## 5. عقود مقترحة تحتاج موافقة

انظر `docs/api-contracts/PROPOSED-FORMS-WITHOUT-PERSISTENCE.md`.

أي schema/RPC/RLS **يتطلب موافقة صريحة** قبل التنفيذ.

## 6. الصلاحيات

- تُفرض على الخادم عبر `RequireStationPermission` وعزل `stationId`.
- الواجهة لا تمنح وصولاً؛ تخفي فقط مسارات تحتاج محطة مختارة.

## 7. تشغيل محلي

```bash
# API
cd backend && dotnet test Metra.Api.Tests

# Flutter
cd mobile/metra_mobile
flutter pub get
flutter analyze
flutter test
flutter build web --release \
  --dart-define=METRA_API_BASE_URL=https://api.example \
  --dart-define=METRA_SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=...
```

## 8. Staging مطلوب قبل إعلان إنتاج الرصد

- حسابات A/B، محطات S1/S2، JWT، تنفيذ L1–L7 في `docs/hourly-daily-live-test-plan.md`

## 9. مخاطر متبقية

| خطر | تخفيف |
|---|---|
| Idempotency RPC غير مثبت حياً | خطة L2/L3 على Staging |
| نماذج سبعة بلا حفظ | عقود مقترحة — لا تنفيذ |
| اعتماد PR #54/#55 غير مدمجين | إبقاء Draft حتى مراجعة |

## 10. قائمة مهام تنفيذية متبقية

1. [ ] توفير Staging وتنفيذ L1–L7 وتوثيق النتائج
2. [ ] مراجعة ودمج تدريجي لـ PR #54 ثم #55 بعد الموافقة
3. [ ] اعتماد عقود النماذج السبعة أو رفضها
4. [ ] ربط CLIMATOL/الأرشيف عند توفر المحركات دون نتائج وهمية
5. [ ] توسيع إدارة المستخدمين وفق endpoints الحالية فقط
