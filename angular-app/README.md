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

## إعداد الاتصال الآمن وقت التشغيل

قبل تشغيل وظائف المراجعة، يحقن خادم الاستضافة إعدادات عامة في الصفحة قبل تحميل ملفات Angular، مثلاً:

```html
<script>
  window.__METRA_CONFIG__ = {
    apiBaseUrl: 'https://api.example.gov',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'YOUR_PUBLIC_ANON_KEY'
  };
</script>
```

استبدل القيم بعناوين البيئة الفعلية. عنوان API يجب أن يكون HTTPS في بيئة النشر. مفتاح anon/public مخصص للمتصفح ولا يمنح صلاحيات بذاته؛ تعتمد الصلاحيات على جلسة المستخدم وسياسات الخادم. **يُمنع منعاً باتاً وضع مفتاح `service_role` أو أي سر خادمي هنا أو في ملفات Angular.**

توجد شاشة تسجيل دخول موصولة بخدمة Supabase Auth (`/login`)، وتقرأ الخدمة جلسة المستخدم وتضيف رمز الوصول إلى طلبات API. يتضمن إعداد Angular الحالي عنوان مشروع METRA Supabase الجديد ومفتاحه العام publishable، ويمكن تجاوزهما بأسرار GitHub Actions `METRA_SUPABASE_URL` و`METRA_SUPABASE_ANON_KEY`. لا يوجد حتى الآن عنوان HTTPS مستضاف لـ ASP.NET Core API؛ لذلك يبقى `apiBaseUrl` فارغاً وتظل عمليات التسجيل والمراجعة وإدارة المستخدمين غير متاحة عبر Pages حتى اختيار مضيف API وضبط `METRA_API_BASE_URL`. لا تستخدم عنواناً افتراضياً أو تجريبياً لهذا المتغير.

## الهيكل
- `src/app/core`: الخدمات والإعدادات المشتركة.
- `src/app/features/reports`: التقارير الساعية واليومية والمناخية.
- `src/app/features/agriculture`: وحدة البيانات الزراعية.
- `src/app/features/soil`: حرارة التربة.
- `src/app/features/users`: إدارة المستخدمين.
- `src/app/features/dashboard`: الصفحة الرئيسية.

## الاتصال بالخلفية
الخلفية المعتمدة للمشروع هي ASP.NET Core Web API فقط. تعمل واجهة Angular حالياً بصورة مستقلة دون الحاجة إلى تشغيل الخادم، وستتصل به عبر HTTP API عند تنفيذ وظائف البيانات. لا ينبغي للمتصفح الاتصال بقاعدة البيانات مباشرة.

## استقلال التشغيل
لا تحتاج هذه النسخة إلى Flutter SDK أو .NET SDK للتثبيت أو التشغيل أو البناء. لها اعتماديات npm وأوامر تشغيل وبناء خاصة بها.


## المعاينة المنشورة

يُبنى هذا التطبيق ويُنشر إلى GitHub Pages عبر workflow الموجود في `.github/workflows/deploy-pages.yml` عند تغيير ملفات `angular-app/` على فرع `main`. رابط المشروع المتوقع:

https://gfa437926-tech.github.io/metra2027/

هذا الرابط يصبح معاينة فعلية بعد نجاح مرحلة Deploy في GitHub Actions وتفعيل GitHub Pages للمستودع. قد تظهر واجهة التطبيق دون اتصال بالخدمات الخلفية إذا لم تُضبط قيم runtime وواجهة API؛ لا تضع أسرار الخادم في إعدادات المتصفح.
