/// Catalog of operational role workspaces. Server remains source of truth for
/// permissions; this only organizes navigation and honest capability status.
class RoleWorkspaceDefinition {
  const RoleWorkspaceDefinition({
    required this.code,
    required this.titleAr,
    required this.summaryAr,
    required this.availableNow,
    required this.blockedUntilContract,
  });

  final String code;
  final String titleAr;
  final String summaryAr;
  final List<String> availableNow;
  final List<String> blockedUntilContract;
}

const List<RoleWorkspaceDefinition> kRoleWorkspaces = [
  RoleWorkspaceDefinition(
    code: 'station_head',
    titleAr: 'رئيس المحطة',
    summaryAr: 'إشراف على محطة العمل: مراجعة النشرات، الأعطال، الدعم، التعيينات ضمن المحطة.',
    availableNow: [
      'دليل المحطات واختيار محطة العمل',
      'طابور المراجعة والاعتماد/الإرجاع',
      'أعطال المعدات وبلاغات الدعم',
      'ملخص التشغيل وحالة النشرات',
      'أرشفة Excel يدوية (تأكيد إداري)',
    ],
    blockedUntilContract: [
      'تقارير إدارية مجمّعة خارج عقود API الحالية',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'observation_dept_head',
    titleAr: 'رئيس دائرة الرصد',
    summaryAr: 'متابعة جودة الإدخال والمراجعة عبر المحطات المخوّلة من الخادم فقط.',
    availableNow: [
      'مراجعة النشرات ضمن المحطات المخوّلة',
      'حالة النشرات المُرجَعة والمعلّقة',
    ],
    blockedUntilContract: [
      'لوحة مؤشرات وطنية دون عقد تقارير معتمد',
      'اعتماد جماعي عبر محطات غير مخوّلة',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'communications_head',
    titleAr: 'رئيس دائرة الاتصالات',
    summaryAr: 'متابعة قنوات الاتصال والبلاغات المرتبطة بالمحطة — بلا وصول لبيانات محطة غير مخوّلة.',
    availableNow: [
      'بلاغات الدعم الفني المرتبطة بالمحطة',
      'ملخص التشغيل عند اختيار محطة',
    ],
    blockedUntilContract: [
      'لوحة اتصالات وطنية / AFTN تشغيلية كاملة',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'networks_head',
    titleAr: 'رئيس دائرة الشبكات',
    summaryAr: 'إشراف على جاهزية الشبكة والأعطات ذات الصلة عند توفر المسارات.',
    availableNow: [
      'أعطال المعدات ضمن المحطة المخوّلة',
      'بلاغات الدعم',
    ],
    blockedUntilContract: [
      'خريطة شبكة وطنية ومراقبة SLA',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'system_manager',
    titleAr: 'مدير النظام',
    summaryAr: 'إدارة الحسابات والصلاحيات والتعيينات وفق ما يفرضه Backend.',
    availableNow: [
      'مراجعة طلبات التسجيل',
      'تعيينات المحطة والأدوار القابلة للطلب',
      'الملف الشخصي وتوضيح مصدر الصلاحيات',
    ],
    blockedUntilContract: [
      'إدارة مستخدمين وطنية كاملة وتدقيق أمني متقدم في الواجهة',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'forecaster',
    titleAr: 'المتنبئ الجوي',
    summaryAr: 'اطلاع على دليل المحطات والمقارنة الجغرافية؛ الرصد اللحظي بعد اعتماد العقد.',
    availableNow: [
      'مركز التنبؤ: الدليل والمقارنة والملف الكتالوجي',
      'لا تعديل أو اعتماد نشرات من واجهة الاطلاع',
    ],
    blockedUntilContract: [
      'لقطة الرصد اللحظية (Weather Observation Snapshot)',
      'رسوم بيانية زمنية من مصدر معتمد',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'aftn_recipient',
    titleAr: 'مستقبل AFTN',
    summaryAr: 'استقبال ومراجعة رسائل AFTN التشغيلية بعد اعتماد القناة والعقد.',
    availableNow: [],
    blockedUntilContract: [
      'قناة AFTN خادمية',
      'قوالب الرسائل والتحقق والتخزين',
      'عزل المحطة/المركز في رسائل AFTN',
    ],
  ),
  RoleWorkspaceDefinition(
    code: 'climatol_officer',
    titleAr: 'تجانس Climatol / المناخ',
    summaryAr: 'تشغيل التجانس على عامل معزول؛ النتائج منتج مستقل دون تعديل السجلات الأصلية.',
    availableNow: [],
    blockedUntilContract: [
      'عامل Climatol معزول',
      'بصمة مجموعة البيانات وإصدار البرنامج',
      'مسار اعتماد بشري للنتائج',
    ],
  ),
];
