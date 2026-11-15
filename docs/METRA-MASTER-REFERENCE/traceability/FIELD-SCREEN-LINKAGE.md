# ربط الحقول بالشاشات

**مصدر البيانات:** `fields-174-part1.csv` + `part2.csv` بعد `assemble_and_verify.py`

## ملخص

| الحالة | العدد |
|---|---|
| إجمالي الحقول | 174 |
| مرتبط بـ `screen_id` غير فارغ | 83 |
| بدون `screen_id` | **91** |

## المرتبط حالياً

| form_id | screen_id | عدد | ملاحظة |
|---|---|---|---|
| hourly | SCR-HOURLY | 36 | Flutter موجود؛ submit gated |
| daily | SCR-DAILY | 32 | Flutter موجود؛ submit gated |
| fault-equipment | SCR-INSTRUMENTS | 15 | UI أقسام جزئية |

## غير المرتبط (91) — بلا اختراع روابط منفّذة

| form_id | عدد | FR | شاشة مقترحة | قرار |
|---|---|---|---|---|
| agricultural | 31 | FR-OBS-AGRI | SCR-AGRI | **U-03** |
| hourly-climate | 15 | FR-OBS-HCLIMATE | SCR-HCLIMATE | **U-03** |
| rainfall | 7 | FR-OBS-RAIN | SCR-RAIN | **U-03** |
| soil | 7 | FR-OBS-SOIL | SCR-SOIL | **U-03** |
| fault-telecom | 21 | FR-FAULT-TEL | SCR-FAULT-TELECOM | **U-04** |
| fault-it | 10 | FR-FAULT-IT | SCR-FAULT-IT | **U-04** |

لا يُعبَّأ `screen_id` لهذه النماذج في CSV حتى اعتماد القرار.  
ملفات `screens/SCR-*.md` المقترحة = **مواصفة** وليست دليلاً على تنفيذ Flutter.
