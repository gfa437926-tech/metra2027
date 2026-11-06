import 'package:flutter/material.dart';

import '../../models/current_user_context.dart';
import '../../services/current_user_context_client.dart';

/// Displays assignments returned by the authenticated identity endpoint.
/// Authorization remains exclusively enforced by the API on every request.
class AssignedStationsScreen extends StatelessWidget {
  const AssignedStationsScreen({
    super.key,
    required this.sessionState,
    required this.userContext,
  });

  final CurrentUserSessionState sessionState;
  final CurrentUserContext? userContext;

  @override
  Widget build(BuildContext context) {
    final assignments = userContext?.assignments ?? const [];
    final activeCount = assignments.where((item) => item.isActive).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.hub_outlined, color: Colors.white, size: 34),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المحطات المرتبطة بحسابك',
                          style: TextStyle(color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('تعيينات المحطات الواردة من خدمة الهوية.',
                          style: TextStyle(color: Color(0xFFDCE6ED),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (sessionState == CurrentUserSessionState.loading)
            const _StateCard(Icons.sync, 'جارٍ تحميل بيانات الحساب',
                'انتظر حتى تكتمل قراءة سياق المستخدم.')
          else if (sessionState == CurrentUserSessionState.unconfigured)
            const _StateCard(Icons.cloud_off_outlined, 'خدمة الهوية غير مهيأة',
                'لن نعرض محطات افتراضية أو بيانات غير موثقة.')
          else if (sessionState == CurrentUserSessionState.unauthenticated)
            const _StateCard(Icons.lock_outline, 'يلزم تسجيل الدخول',
                'سجّل الدخول بحساب معتمد لعرض تعيينات المحطات.')
          else if (sessionState != CurrentUserSessionState.active &&
              sessionState != CurrentUserSessionState.pendingApproval)
            const _StateCard(Icons.shield_outlined, 'تعذّر عرض التعيينات',
                'حالة الحساب أو خدمة الهوية لا تسمح بعرض البيانات حالياً.')
          else ...[
            Row(
              children: [
                Expanded(child: _CountCard('إجمالي التعيينات',
                    assignments.length, Icons.location_on_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _CountCard('التعيينات الفعالة',
                    activeCount, Icons.verified_outlined)),
              ],
            ),
            const SizedBox(height: 14),
            if (assignments.isEmpty)
              const _StateCard(Icons.location_off_outlined,
                  'لا توجد محطة مرتبطة',
                  'لم تُرجع خدمة الهوية أي تعيين محطة لهذا الحساب.')
            else
              ...assignments.map((item) => _AssignmentCard(item)),
            const SizedBox(height: 10),
            const Text(
              'ملاحظة أمنية: أسماء المحطات والأدوار هنا للعرض فقط. الخادم هو المرجع الوحيد للتحقق من الصلاحيات ونطاق المحطة عند كل طلب.',
              style: TextStyle(color: Color(0xFF657786), fontSize: 12,
                  height: 1.7),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard(this.label, this.count, this.icon);
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF2980B9)),
              const SizedBox(height: 8),
              Text(count.toString(), style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(
                  fontSize: 11, color: Color(0xFF657786))),
            ],
          ),
        ),
      );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard(this.item);
  final CurrentUserStationAssignment item;

  @override
  Widget build(BuildContext context) {
    final active = item.isActive;
    final role = _roleLabel(item.roleCode);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E9EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF3F8),
                child: Icon(Icons.location_on_outlined,
                    color: Color(0xFF2980B9)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15))),
              Chip(
                label: Text(active ? 'فعال' : 'غير فعال'),
                backgroundColor: active
                    ? const Color(0xFFE7F5EC)
                    : const Color(0xFFF1F2F4),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const Divider(height: 22),
            _DetailLine('رمز المحطة', item.stationId),
            _DetailLine('الدور', role),
            _DetailLine('بداية التعيين', _dateLabel(item.validFrom)),
            if (item.validTo != null)
              _DetailLine('نهاية التعيين', _dateLabel(item.validTo!)),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String code) {
    final normalized = code.trim().toLowerCase().replaceAll('-', '_');
    const labels = <String, String>{
      'weather_observer': 'راصد جوي',
      'weather_observer_role': 'راصد جوي',
      'observer': 'راصد جوي',
      'station_observer': 'راصد جوي',
      'weather_observer_role': 'راصد جوي',
      'observer_role': 'راصد جوي',
      'station_manager': 'رئيس محطة',
      'station_head': 'رئيس محطة',
      'head_of_station': 'رئيس محطة',
      'stationmanager': 'رئيس محطة',
      'chief_station': 'رئيس محطة',
      'station_chief': 'رئيس محطة',
      'supervisor': 'مشرف',
      'reviewer': 'مدقق',
      'station_reviewer': 'مدقق محطة',
      'station_auditor': 'مدقق محطة',
      'review_station': 'مدقق محطة',
      'climate_manager': 'مدير المناخ',
      'climate_director': 'مدير المناخ',
      'general_manager': 'مدير عام',
      'general_director': 'مدير عام',
      'programmer': 'مبرمج',
      'communications_technician': 'فني اتصالات',
      'communications_tech': 'فني اتصالات',
      'station_technician': 'فني محطات',
      'station_tech': 'فني محطات',
      'admin': 'مدير النظام',
      'system_admin': 'مدير النظام',
      'system_administrator': 'مدير النظام',
      'systemadministrator': 'مدير النظام',
    };
    return labels[normalized] ?? code;
  }

  String _dateLabel(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          SizedBox(width: 112, child: Text(label,
              style: const TextStyle(color: Color(0xFF71808B), fontSize: 12))),
          Expanded(child: Text(value,
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600))),
        ]),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard(this.icon, this.title, this.message);
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFF8FAFB),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Icon(icon, size: 34, color: const Color(0xFF718A9A)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF657786),
                    fontSize: 12, height: 1.6)),
          ]),
        ),
      );
}
