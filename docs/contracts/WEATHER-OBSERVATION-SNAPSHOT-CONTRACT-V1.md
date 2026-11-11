# عقد لقطة الرصد للتنبؤ — Weather Observation Snapshot Contract v1

**الحالة:** مقترح للمراجعة والاعتماد — **غير مطبّق** على قاعدة البيانات ولا على مسار API إنتاجي لقراءة اللقطات.  
**الفرع:** `work/legacy-ui-migration-audit`  
**مرجع التنفيذ الحالي:** مركز التنبؤ (كتالوج + مقارنة جغرافية فقط)  
**التوقيت:** UTC حصراً في كل الحقول الزمنية.

---

## 1) تدقيق مصادر البيانات الحالية (من المستودع)

### 1.1 التخزين التشغيلي

| المصدر | الموقع | ملاحظات |
|---|---|---|
| جدول النشرات | `public.metra_observations` | `observation_type ∈ {daily,hourly,phenomenon}` |
| الحمولة | `payload jsonb` | كائن؛ الحقول داخل `payload.values` (نصوص) |
| وقت الرصد | `observed_at timestamptz` | من المغلف `observedAt` (UTC) |
| وقت الإنشاء | `created_at` | إدراج السجل |
| وقت الإرسال | `submitted_at` | عند الانتقال إلى submitted |
| وقت المراجعة | `reviewed_at` | عند اعتماد/إرجاع |
| الحالة | `status` | `draft` \| `submitted` \| `returned` \| `approved` |
| التدقيق | `metra_observation_audit_events` | أحداث دورة الحالة |

لا يوجد جدول منفصل باسم «لقطة تنبؤ» أو «آخر قراءة لكل محطة» في migrations الحالية.

### 1.2 عقود الحقول المعتمدة للإدخال (لا اختراع)

**ساعي** (`OBSERVATION-FIELD-CONTRACT-V1` + `HourlyObservationValidator`):  
`utcTime`, `dryTemp`, `wetTemp`, `dewPoint`, `stationPressure`, `seaLevelPressure`, `relativeHumidity`, `windDirection`, `windSpeed`, `visibility`, `totalCloudCover`, `cover12`, `cover123`, `precipitationAmount`, `pressureSlope`, `pressureShape`, `pastWeather`، وحقول اختيارية/شرطية: `vaporPressure`, `vaporPressureDiff`, `avgWindDirection`, `avgWindSpeed`, `currentWeather`, طبقات السحب `cloud*`.

**يومي**:  
`minTemp`, `maxTemp`, `precipitation`, `precipitationTrace`, `snowThickness` (غير إلزامي عام في الكود الحالي بعد سياسة 24h)، `evaporation`, `sunshine*`, `maxGust*`, `maxHumidity*`, `minHumidity*` حسب نوع التقرير.

**ظاهرة**: نوع `phenomenon` — ليست بديلاً عن الرصد الساعي الكامل.

### 1.3 عناصر طلبها التكليف مقابل التوفر

| عنصر العرض المطلوب | المصدر الحالي | ملاحظات |
|---|---|---|
| حرارة حالية | ساعي: `dryTemp` | لا حقل باسم «currentTemperature» منفصل |
| حرارة صغرى/عظمى | يومي: `minTemp` / `maxTemp` | ليست في الساعي |
| ضغط | ساعي: `stationPressure` / `seaLevelPressure` | |
| رطوبة | ساعي: `relativeHumidity` | يومي: عظمى/صغرى زمنية |
| نقطة الندى | ساعي: `dewPoint` | |
| رياح سرعة/اتجاه | ساعي: `windSpeed` / `windDirection` | مقياس اتجاه 00–36 كما في العقد |
| هبات | يومي 24h: `maxGustSpeed` / `maxGustDirection` / `maxGustTime` | **ليست** في العقد الساعي الحالي |
| أمطار | ساعي: `precipitationAmount`؛ يومي: `precipitation` | فترات مختلفة — لا تُخلط دون تعريف |
| رؤية | ساعي: `visibility` | |
| غيوم | ساعي: `totalCloudCover` + طبقات | |
| ObservedAtUtc | `observed_at` / مغلف | |
| ReceivedAtUtc | **لا عمود بهذا الاسم** | مرشّح تقريبي: `submitted_at` أو `created_at` — يحتاج قرار مالك |
| حالة الاعتماد | `status` | للتنبؤ يُقترح `approved` فقط |
| إحداثيات/ارتفاع | `station_catalogue` + `station_coordinates` | منفصل عن الحمولة |

### 1.4 ما لا يتوفر حالياً كمصدر مثبت في الكود

- جدول/مادة لقطة مجمّعة لكل محطة.
- سياسة حداثة مرتبطة بدورة إرسال رسمية لكل نوع محطة (classic/automatic/synoptic) — **غير موثّقة رقمياً في المستودع**.
- مصدر خارجي مستقل.
- حقل هبّات داخل النشرة الساعية.
- ضمان أن كل محطة تملك نشرة `approved` حديثة.

---

## 2) العقد المقترح — `WeatherObservationSnapshot` v1

### 2.1 مبادئ

1. كل قيمة أرصاد اختيارية (`null` عند الغياب) — **ممنوع** استبدال المفقود بـ `0`.
2. القيم الأرصادية تبقى **نصوصاً** كما في عقد الإدخال (حفاظاً على `#` والدقة) **أو** تُعرَّف طبقة عرض منفصلة لاحقاً دون تغيير التخزين.
3. المصدر والحالة الزمنية صريحان.
4. لا خلط ساعي ويومي في نفس الحقل دون `sourceObservationType` و`fieldProvenance`.
5. UTC فقط.

### 2.2 الشكل المنطقي (JSON Schema مفهومي)

```json
{
  "contractVersion": "weather-observation-snapshot/1.0",
  "stationId": "00000000-0000-0000-0000-000000000000",
  "stationCode": null,
  "wmoStationId": null,
  "stationNameAr": null,
  "sourceObservationId": null,
  "sourceObservationType": null,
  "approvalStatus": null,
  "observedAtUtc": null,
  "receivedAtUtc": null,
  "retrievedAtUtc": "2026-11-10T22:00:00Z",
  "dataQuality": "no_data",
  "freshness": "no_data",
  "sourceSystem": "metra_observations",
  "elements": {
    "dryTemp": null,
    "wetTemp": null,
    "dewPoint": null,
    "minTemp": null,
    "maxTemp": null,
    "stationPressure": null,
    "seaLevelPressure": null,
    "relativeHumidity": null,
    "windSpeed": null,
    "windDirection": null,
    "maxGustSpeed": null,
    "maxGustDirection": null,
    "precipitationAmount": null,
    "precipitationDaily": null,
    "precipitationTrace": null,
    "visibility": null,
    "totalCloudCover": null
  },
  "fieldProvenance": {},
  "notesAr": "مثال بنية فقط — القيم null تعني غير متاح، وليست صفراً."
}
```

### 2.3 خريطة الحقول ← المصدر

| حقل اللقطة | مصدر مقترح | ملاحظة |
|---|---|---|
| `elements.dryTemp` | hourly `values.dryTemp` | |
| `elements.wetTemp` | hourly `values.wetTemp` | |
| `elements.dewPoint` | hourly `values.dewPoint` | |
| `elements.minTemp` / `maxTemp` | daily `values.minTemp` / `maxTemp` | من آخر يومي معتمد إن وُجد — **قرار سياسة** إن دُمجت مع ساعي |
| `elements.stationPressure` | hourly `values.stationPressure` | |
| `elements.seaLevelPressure` | hourly `values.seaLevelPressure` | |
| `elements.relativeHumidity` | hourly `values.relativeHumidity` | |
| `elements.windSpeed` / `windDirection` | hourly | |
| `elements.maxGust*` | daily 24h إن وُجد | وإلا null |
| `elements.precipitationAmount` | hourly | |
| `elements.precipitationDaily` | daily `precipitation` | لا تُعرض كـ «نفس» الساعي |
| `elements.visibility` | hourly | |
| `elements.totalCloudCover` | hourly | |
| `approvalStatus` | `metra_observations.status` | |
| `observedAtUtc` | `observed_at` | |
| `receivedAtUtc` | **قرار معلّق:** `submitted_at` مفضّل عند الإرسال؛ وإلا `created_at` | |
| `stationCode` | `local_station_code` من الكتالوج | |

### 2.4 اختيار «أحدث» نشرة (قاعدة مقترحة — تحتاج موافقة)

للتوقع التشغيلي الافتراضي:

1. مرشّح أساسي: آخر سجل `observation_type = 'hourly'` و `status = 'approved'` للمحطة، مرتّب بـ `observed_at DESC`.
2. إثراء اختياري من آخر `daily` معتمد لنفس المحطة لعناصر min/max/gust فقط، مع إثبات `fieldProvenance`.
3. استبعاد `draft` / `returned` / `submitted` غير المعتمد من لوحة التنبؤ العامة.

**بديل أشد صرامة:** الساعي المعتمد فقط؛ اليومي في بطاقة منفصلة.

---

## 3) سياسة الاطلاع (مقترح)

| العملية | من يُسمح | آلية |
|---|---|---|
| قراءة لقطة تنبؤ / كتالوج للتنبؤ | كل حساب **مفعّل ومصادق** (راصد، رئيس محطة، اتصالات، ورش، مدير نظام، متنبئ، …) | API بـ JWT صالح؛ **منفصل** عن `observation.create` / قرار الاعتماد |
| تعديل أو اعتماد نشرة | حسب صلاحيات المحطة الحالية فقط | دون تغيير |

**اقتراح رمز صلاحية (إن لزم في DB لاحقاً):** `forecasting.view`  
أو سياسة «أي مستخدم authenticated» على مسارات `/api/v1/forecasting/**` مع تقييد البيانات إلى `approved` فقط.

**Fail-closed:** انقطاع خدمة التفويض أو الكتالوج → 503/403 وليس سماح.

**لا تُفرض صلاحية المحطة الضيقة** على قراءة اللقطة العامة للتنبؤ إذا اعتُمد أن المتنبئ يرى كل المحطات — هذا **قرار مالك** (وطني مقابل محطة).

---

## 4) حداثة البيانات (مقترح — بلا أرقام مخترعة)

حالات العرض:

| `freshness` | المعنى |
|---|---|
| `fresh` | ضمن عتبة دورة المحطة/النوع بعد `observed_at` |
| `delayed` | تجاوز العتبة الأولى دون تجاوز عتبة «قديم» |
| `stale` | تجاوز العتبة الثانية |
| `no_data` | لا سجل معتمد |
| `incomplete` | سجل معتمد لكن عناصر أساسية للعرض ناقصة |

**العتبات بالدقائق/الساعات:** **غير موجودة في المستودع** لأنواع classic/automatic/synoptic.  
يجب أن يزوّد المالك جدولاً رسمياً (مثال للتعبئة فقط — ليس سياسة معتمدة):

| station_type | عتبة fresh | عتبة delayed→stale | أساس الوقت |
|---|---|---|---|
| automatic | ؟ | ؟ | observed_at أو received |
| classic | ؟ | ؟ | |
| synoptic | ؟ | ؟ | |

حتى الاعتماد: الواجهة تعرض `freshness` فقط عند توفر سياسة؛ وإلا `unknown_policy` أو الاكتفاء بـ `no_data` / وجود لقطة.

---

## 5) التكامل مع ما نُفّذ

| مكوّن | الربط |
|---|---|
| Angular Forecasting Center | بعد اعتماد العقد + API قراءة: ملء بطاقات العناصر من `elements.*` مع الإبقاء على المقارنة/الخريطة الجغرافية |
| Flutter Forecasting Center | نفس العقد |
| .NET | DTO + mapper من `payload` (مسودة كود دون endpoint إنتاجي يسرّب بيانات غير معتمدة) |
| مسارات المقارنة/الخريطة | تبقى على الكتالوج؛ لا تُكسر |

مسارات API مقترحة **بعد الموافقة** (غير مفعّلة كقراءة لقطة حية في هذه الجولة):

- `GET /api/v1/forecasting/stations/{stationId}/snapshot`
- `GET /api/v1/forecasting/snapshots?stationIds=...` (حد أعلى للعدد)

---

## 6) تغييرات قاعدة البيانات المحتملة (للموافقة فقط)

| الخيار | الوصف | حاجة SQL |
|---|---|---|
| **A — بدون جدول جديد** | استعلام آخر `approved` hourly من `metra_observations` عبر API/service role بعد تحقق JWT | قد يكفي مع فهرس موجود `(station_id, status, observed_at desc)` |
| **B — مادّة/جدول لقطات** | جدول `metra_station_weather_snapshots` يُحدَّث عند الاعتماد | migration + RLS |
| **C — صلاحية `forecasting.view`** | في مصفوفة الصلاحيات | migrations هوية |

**لا يُطبَّق أي خيار دون موافقة صريحة.**

---

## 7) اختبارات القبول (عند التنفيذ لاحقاً)

1. لقطة بدون نشرة معتمدة → كل العناصر null و`no_data`.  
2. نشرة معتمدة تنقص فيها الرؤية → `visibility: null` وليس `0`.  
3. مستخدم مصادق يقرأ اللقطة وفق السياسة المعتمدة؛ غير مصادق → 401.  
4. مسارات التعديل/الاعتماد لا تُفتح من واجهة التنبؤ.  
5. UTC في `observedAtUtc` / `receivedAtUtc` / `retrievedAtUtc`.  
6. عدم خلط `precipitationAmount` و`precipitationDaily` في حقل واحد.  
7. CI أخضر.

---

## 8) قرارات معلّقة للمالك

1. تعريف `receivedAtUtc` = `submitted_at` أم `created_at` أم حقل جديد؟  
2. هل اللقطة العامة لكل المحطات لكل الحسابات المفعّلة، أم نطاق محطة؟  
3. هل تُعرض فقط `approved`؟  
4. جدول عتبات الحداثة لكل `station_type`.  
5. هل يُدمج آخر يومي مع آخر ساعي في نفس اللقطة؟  
6. خيار التخزين A vs B vs C.

---

## 9) ملخص الجاهزية

| البند | جاهز؟ |
|---|---|
| تدقيق المصادر | نعم (من الكود/SQL في المستودع) |
| نص العقد v1 | نعم — للموافقة |
| API قراءة لقطة حية | لا — بعد الموافقة |
| SQL | لا تطبيق |
| ربط Angular/Flutter بالقيم | بعد API |
