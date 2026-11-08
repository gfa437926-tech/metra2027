# بناء نسخة تجريبية قابلة للتثبيت — METRA Flutter

## Android (APK تجريبي)
على جهاز فيه Flutter SDK و Android SDK:

```bash
cd flutter-app
flutter pub get
flutter create . --platforms=android,ios   # إن لزم لاستكمال ملفات Gradle/Xcode القياسية
flutter build apk --debug
# الناتج: build/app/outputs/flutter-apk/app-debug.apk
```

للتجربة الداخلية مع توقيع debug (مثبت على أجهزة الاختبار فقط):

```bash
flutter build apk --release
```

> إصدار المتاجر يتطلب keystore خاصاً وليس توقيع debug.

## iOS
يتطلب macOS + Xcode:

```bash
cd flutter-app
flutter pub get
flutter build ios --debug --no-codesign
# أو فتح ios/Runner.xcworkspace في Xcode للتوقيع والتثبيت على جهاز
```

## الإعداد قبل التشغيل
لا تضع service_role في التطبيق. استخدم فقط:
- عنوان API (`…/api/v1`)
- Supabase URL
- anon key

## حدود هذه البيئة السحابية
لا يمكن إنتاج APK/IPA موقّع هنا بسبب غياب Android SDK كامل وقتل عملية Flutter tool على الذاكرة.
المنصات أُضيفت في المستودع؛ البناء النهائي يتم على جهاز المطوّر أو CI مخصص للموبايل.
