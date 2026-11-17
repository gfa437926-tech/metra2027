/// Approved local-only catalogue form codes (PR #53 field catalogues).
///
/// These forms have no approved server persistence contract yet.
/// Do not invent endpoints, table names, or RPC for them.
enum CatalogFormType {
  agricultural,
  hourlyClimate,
  rainfall,
  soil,
  faultEquipment,
  faultTelecom,
  faultIt,
}

extension CatalogFormTypeCode on CatalogFormType {
  /// Stable machine code used in drafts and future contracts.
  String get code => switch (this) {
        CatalogFormType.agricultural => 'agricultural',
        CatalogFormType.hourlyClimate => 'hourlyclimate',
        CatalogFormType.rainfall => 'rainfall',
        CatalogFormType.soil => 'soil',
        CatalogFormType.faultEquipment => 'faultequipment',
        CatalogFormType.faultTelecom => 'faulttelecom',
        CatalogFormType.faultIt => 'faultit',
      };

  String get arabicTitle => switch (this) {
        CatalogFormType.agricultural => 'الرصد الزراعي',
        CatalogFormType.hourlyClimate => 'الرصد المناخي الساعي',
        CatalogFormType.rainfall => 'رصد الأمطار',
        CatalogFormType.soil => 'رصد التربة',
        CatalogFormType.faultEquipment => 'أعطال الأجهزة',
        CatalogFormType.faultTelecom => 'أعطال الاتصالات',
        CatalogFormType.faultIt => 'بلاغات تقنية المعلومات',
      };

  /// Explicit operator-facing notice: local only until an API contract exists.
  String get pendingContractNotice =>
      'تحقق محلي فقط — لا حفظ على الخادم. الإرسال الإنتاجي يتطلب عقد API معتمداً.';
}
