# مسار التشغيل حتى النهاية (بعد اكتمال كود الفرع)

هذا المسار يخص **المشغّل / مالك المشروع**. الكود على `work/legacy-ui-migration-audit` جاهز للمراجعة؛ الخطوات أدناه لا تُنفَّذ تلقائياً من المستودع دون أسرار وموافقة.

## المرحلة O1 — موافقة قاعدة البيانات (الجديد فقط)

1. افتح `docs/security/phase-e-database-approval-package.md`.
2. وقّع القرار:
   - [ ] تطبيق migrations 1–12
   - [ ] تفعيل جدول `metra_manual_archive_confirmations`
   - [ ] منح `archive.read` / `archive.confirm`
3. نفّذ على **مشروع Supabase الجديد فقط**.
4. لا تتصل بالقاعدة القديمة ولا تستورد محطاتها.

## المرحلة O2 — الأسرار

| السر | المكان |
|---|---|
| Supabase URL + anon | إعدادات Angular/Flutter العامة |
| Service role | خادم .NET / Secret Store فقط |
| MetraOps connection string | خادم فقط |
| JWT/JWKS | خادم فقط |

## المرحلة O3 — Staging

1. نشر API على Staging مع HTTPS.
2. نشر Angular على نفس البيئة.
3. ضبط `metra-config` / Flutter API base URL.
4. فحص `/api/v1/ready`.

## المرحلة O4 — قبول تشغيلي

نفّذ قائمة القبول في `docs/operations/phase-h-delivery-package.md` (عزل محطات، رصد، مراجعة، أعطال، دعم، تسجيل، تعيين، أرشفة).

## المرحلة O5 — الدمج

1. راجع PR #11 (Draft).
2. تأكد من CI أخضر على آخر commit.
3. ادمج إلى `main` **يدوياً بعد موافقتك**.

## المرحلة O6 — الإنتاج

1. أسرار Production منفصلة عن Staging.
2. نشر تدريجي + مراقبة.
3. نسخة احتياطية/استعادة مختبرة قبل الإعلان التشغيلي.

## المرحلة O7 — توسعات أرصادية لاحقة (اختيارية)

بعد اعتماد الصيغ والعقود فقط:
- مناخي / سنوي / مطري / تربة / زراعي كـ API وقراءات حقيقية.
