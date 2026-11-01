# METRA 2027 — Angular application

مشروع Angular مستقل داخل المستودع الحالي. ملفات التطبيق القديم في جذر المستودع لم تُنقل ولم تُعدّل.

## المتطلبات
- Node.js إصدار متوافق مع Angular 20
- npm

## التشغيل
```bash
cd angular-app
npm install
npm start
```

## بناء نسخة الإنتاج
```bash
npm run build
```

## الهيكل
- `src/app/core`: الخدمات والإعدادات المشتركة (ومنها إعداد Supabase).
- `src/app/features/reports`: التقارير الساعية واليومية والمناخية.
- `src/app/features/agriculture`: وحدة البيانات الزراعية.
- `src/app/features/soil`: حرارة التربة.
- `src/app/features/users`: إدارة المستخدمين.
- `src/app/features/dashboard`: الصفحة الرئيسية.

## إعداد Supabase
ملف `src/app/core/supabase/supabase.config.ts` يحتوي قيماً فارغة عمداً. زوّد عنوان المشروع ومفتاح anon/public عبر إعدادات بيئة البناء قبل تفعيل الاتصال. لا تستخدم مفتاح `service_role` في المتصفح.

## حالة النقل
هذه مرحلة تأسيس هيكل Angular ومسارات أولية فقط. لم تُنقل بعد نماذج الإدخال أو منطق التحقق والمزامنة أو المصادقة. يجب مراجعة سياسات RLS وصلاحيات قاعدة البيانات قبل تشغيل أي وظائف حساسة في بيئة الإنتاج.
