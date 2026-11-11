import 'package:flutter/material.dart';

import 'role_workspace_catalog.dart';

/// Navigation hub for operational role desks. Does not grant permissions;
/// server authorization remains mandatory on every API call.
class RoleWorkspacesScreen extends StatelessWidget {
  const RoleWorkspacesScreen({super.key});

  static const _navy = Color(0xFF061B4A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('مكاتب الأدوار التشغيلية'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFEEF6FF),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'هذه المكاتب تنظّم الوصول إلى الوظائف. الصلاحية الفعلية يحددها الخادم '
                  'حسب الدور والمحطة. لا تُعرض بيانات محطة غير مخوّلة.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...kRoleWorkspaces.map(_RoleCard.new),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard(this.role);
  final RoleWorkspaceDefinition role;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(role.titleAr, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(role.summaryAr, maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (role.availableNow.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('متاح الآن (عند صلاحية الخادم):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...role.availableNow.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                title: Text(item),
              ),
            ),
          ],
          if (role.blockedUntilContract.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text('محجوب حتى اعتماد العقد/API:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...role.blockedUntilContract.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, color: Color(0xFFB45309)),
                title: Text(item),
              ),
            ),
          ],
          if (role.availableNow.isEmpty && role.blockedUntilContract.isNotEmpty)
            const Text(
              'لا واجهة تشغيلية مربوطة بعد — الهيكل للتوجيه فقط.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }
}
