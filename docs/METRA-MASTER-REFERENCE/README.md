# METRA Master Reference v2 — الدليل المرجعي التنفيذي

**الفرع:** `docs/metra-master-reference-v2-2026-11-15`  
**التاريخ:** 2026-11-15  
**المستودعات المفحوصة:**
- قديم (قراءة فقط): https://github.com/gfa437926-tech/metra-old
- جديد: https://github.com/gfa437926-tech/metra2027

## تحذير نزاهة
هذا الدليل يفصل بين: (1) مثبت من المصدر (2) واجهة فقط في Flutter (3) مقترح/يحتاج اعتماداً.

## ما ثبت بالفحص في هذه الجولة
| مقياس | قيمة مثبتة |
|---|---|
| شاشات HTML في Old بها نماذج | 21 |
| حقول مستخرجة في 9 نماذج إدخال رئيسية | 174 |
| حقول عبر كل صفحات HTML (بعد/قبل إزالة تكرار) | ~287 |
| ملفات forms/ التفصيلية | 9 |
| حدود رقمية مثبتة من enhanced-validation.js (ساعي) | 15 حقلاً |
| مقارنات حدود في daily_validation.js | حرارة/هطول/ثلج/تبخر/سطوع/رطوبة/وقت |
| وجهات Flutter على فرع الواجهات | 14 |
| PR مفتوحة لم تُدمج | #49, #50 |

## نقطة الدخول
1. `legacy-analysis/LEGACY-FUNCTION-INVENTORY.md`
2. `forms/` (كل نموذج)
3. `fields/EXTRACTED-FIELD-CATALOG.md`
4. `scientific/DATA-DICTIONARY-PROVEN-BOUNDS.md`
5. `traceability/LEGACY-TO-2027-MATRIX.md`
6. `15-UNRESOLVED-QUESTIONS-AND-CONFLICTS.md`

## قيود
لا تعديل metra-old · لا migrations · لا أسرار · لا دمج تلقائي
