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
