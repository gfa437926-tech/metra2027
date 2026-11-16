# 02 — مصفوفة التتبع Legacy → New

رموز: M مطابق | P يحتاج استكمال | R تسمية مختلفة | L قديم فقط | N جديد | C تعارض | U غير قابل للتحقق

## الرصد
- نشرة ساعية → hourly_observation_entry_screen (P, gated)
- نشرة يومية → daily_observation_entry_screen (P, gated)
- زراعي/مطري/تربة/h_climate → ضمن رصد/تقارير (P/L)
- مراجعة واعتماد → observation_review_screen (P, gated)

## أعطال
- fix / fix-tel / it → instrument_management + workflows (P/L)

## تقارير
- view-data/* → reports_hub_screen (P)
- أرشيف → observation_archive_screen (N, 503 fail-closed)

## جديد
- CLIMATOL, AI, records, full instruments (N)

لا تُحذف أي وظيفة قديمة دون قرار موثق.
