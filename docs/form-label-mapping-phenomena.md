# مطابقة صفحة عرض ظواهر المطر والثلج

المصدر المرجعي: `phenomena.html` في جذر المستودع.  
مكوّن Angular: `angular-app/src/app/features/phenomena/phenomena.component.ts`  
المسار: `/phenomena`

## مسميات الحقول والمعرفات

| المسمى الأصلي | معرّف HTML الأصلي | معرّف Angular / الحالة |
|---|---|---|
| التاريخ الحالي | `currentDate` | `currentDate` |
| الوقت الحالي | `currentTime` | `currentTime` |
| التوقيت العالمي (UTC) | `utcTime` | `utcTime` |
| التاريخ | `filterDate` | `filterDate` |
| نوع الظاهرة | `filterType` | `filterType` |
| المحطة | `filterStation` | `filterStation` |
| الشدة | `filterIntensity` | `filterIntensity` |
| من تاريخ | `filterStartDate` | `filterStartDate` |
| إلى تاريخ | `filterEndDate` | `filterEndDate` |
| بحث | `searchBtn` | موجود |
| إعادة تعيين | `resetBtn` | موجود |
| تصدير البيانات | `exportBtn` | موجود؛ JSON |
| تحديث | زر `refreshData()` | معطل حتى ربط API |
| عرض التفاصيل | `view-detail-btn` | موجود |
| عرض جدول المطر | `view-rainfall-btn` | موجود |
| طباعة التقرير | `printDetailBtn` | موجود |
| طباعة الجدول | `printRainfallTable()` | موجود |
| تصدير كملف CSV | `exportRainfallData()` | موجود |

## القيم الأصلية

- نوع الظاهرة: `rain` مطر، `snow` ثلج، `rain_snow` مطر وثلج معاً، `hail` برد، `drizzle` رذاذ، `storm` عاصفة رعدية.
- الشدة: `light` خفيفة، `moderate` متوسطة، `heavy` شديدة، `very_heavy` شديدة جداً.
- جميع أوقات الظاهرة والفترات معروضة بالتوقيت العالمي UTC.
- الفترات الساعية: 00، 06، 12، 18.
- المطر: `ddd.d` وبالوحدة مم.
- الثلج: `ddd` وبالوحدة سم.
- جدول المصدر: `weather_phenomena`.
- حقول السجل التي تستخدمها الصفحة الأصلية تشمل `report_id`, `phenomenon_type`, `phenomenon_date`, `start_time`, `end_time`, `phenomenon_duration`, `intensity`, `station_name`, `user_name`, `user_email`, `user_role`, `submission_date`, `submission_time`, `general_notes` وحقول الساعات الأربع `hour_00/06/12/18_rain`, `_snow`, `_notes`.

## العناوين الأصلية

- نظام إدارة البيانات الجوية
- عرض ظواهر المطر والثلج
- التعريف بالمحطة والراصد
- فلاتر البحث والتصفية
- جدول تأشيرات المطر والثلج
- تفاصيل الظاهرة الجوية
- معلومات الظاهرة
- معلومات التسجيل
- الملاحظات العامة
- بيانات الفترات الساعية (UTC)
- جدول تأشيرات المطر والثلج (UTC)
- مساعدة - عرض ظواهر المطر والثلج

## حالة النقل

نُقلت واجهة العرض والفلاتر والبطاقات والإحصائيات المحسوبة من السجلات والتفاصيل وجدول الفترات والطباعة وتصدير JSON/CSV إلى Angular. لا توجد بيانات تجريبية أو إحصائيات افتراضية. صفحة HTML الأصلية كانت تستخدم عنوان Supabase مختلفاً عن مشروع METRA الحالي وتقرأ معلومات المستخدم من localStorage مع قيم بديلة؛ لم ننقل اتصال قاعدة البيانات القديم أو القيم البديلة. لذلك لا تُعرض سجلات حتى يُعتمد ربط API ومصدر الهوية وقاعدة البيانات الحالية. زر تحديث غير متاح حالياً، وتصدير JSON/CSV يعتمد وجود سجلات فعلية.

**المتبقي:** توصيل مصدر البيانات المعتمد بعد اعتماد مخطط الجدول وسياسات الوصول، والتحقق البصري مقابل الصفحة الأصلية في المتصفح، ومراجعة المطابقة الدقيقة لكل النصوص في نافذة المساعدة والتفاصيل.
