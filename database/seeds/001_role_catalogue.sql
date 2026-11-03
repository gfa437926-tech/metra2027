-- METRA 2027 baseline role catalogue.
-- Idempotent: inserts missing role definitions only; never overwrites reviewed values.
-- Elevated roles are deliberately not self-requestable during public registration.

insert into public.metra_role_catalogue
    (role_code, name_ar, name_en, description_ar, description_en,
     is_requestable, is_active, display_order)
values
    ('observer', 'راصد جوي', 'Weather Observer',
     'إدخال الرصد الجوي والنشرات الخاصة بالمحطة المعتمد عليها ضمن حدود التكليف.',
     'Enters meteorological observations and station reports within the approved assignment.',
     true, true, 10),
    ('station_head', 'رئيس محطة', 'Station Manager',
     'إدارة شؤون المحطة والراصدين ومراجعة النشرات ضمن نطاق المحطة.',
     'Manages station operations and observers and reviews reports within the station scope.',
     false, true, 20),
    ('station_auditor', 'مدقق محطة', 'Station Auditor',
     'مراجعة جودة واكتمال النشرات للمحطة وفق صلاحيات التدقيق.',
     'Reviews station report quality and completeness within assigned audit scope.',
     false, true, 30),
    ('chief_auditor', 'المدقق الرئيسي العام', 'Chief Auditor',
     'التدقيق النهائي العام للنشرات وفق مسار الاعتماد المؤسسي.',
     'Performs final central audit under the institutional approval workflow.',
     false, true, 40),
    ('network_director', 'رئيس دائرة الشبكات', 'Network Director',
     'الإشراف على شبكة المحطات واعتماد بياناتها وتكليفاتها حسب الصلاحيات.',
     'Oversees the station network and approves station data and assignments.',
     false, true, 50),
    ('statistics_director', 'رئيس دائرة الإحصاء', 'Statistics Director',
     'الإشراف على الإحصاء المناخي والتحليلات والمخططات والتقارير.',
     'Oversees climatological statistics, analytics, charts and reports.',
     false, true, 60),
    ('aftn_operator', 'مسؤول دائرة AFTN', 'AFTN Operations Officer',
     'إدارة رسائل AFTN والترميز والإرسال ومتابعة سجل التسليم.',
     'Manages AFTN messages, encoding, transmission and delivery records.',
     false, true, 70),
    ('system_admin', 'مدير النظام', 'System Administrator',
     'إدارة الإعدادات التقنية والحسابات والصلاحيات دون تجاوز ضوابط التدقيق.',
     'Manages technical configuration, accounts and permissions under audit controls.',
     false, true, 90)
on conflict (role_code) do nothing;
