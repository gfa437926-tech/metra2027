// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Account and user management workspace.
/// Registration approval, roles, station assignment and activity log are presented
/// as operational UI. Real writes remain subject to server authorization.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MetraPageHeader(
          title: 'إدارة الحسابات والمستخدمين',
          subtitle:
              'التسجيل، الموافقات، الأدوار، تعيين المحطات، التفعيل/التعطيل وسجل النشاط. كل عملية تخضع لصلاحيات الخادم.',
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: metraNavy,
          tabs: const [
            Tab(text: 'المستخدمون'),
            Tab(text: 'طلبات التسجيل'),
            Tab(text: 'الأدوار والصلاحيات'),
            Tab(text: 'سجل النشاط'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _UsersTab(),
              _RegistrationTab(),
              _RolesTab(),
              _ActivityTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'قائمة المستخدمين تُحمّل من الدليل المعتمد. التعديل والتفعيل/التعطيل وتعيين المحطات يتطلب صلاحيات إدارة صريحة.',
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'المستخدمون',
          trailing: FilledButton.tonal(
            onPressed: () {},
            child: const Text('تحديث'),
          ),
          child: const MetraEmptyState(
            icon: Icons.people_outline,
            title: 'لا توجد بيانات مستخدمين معروضة',
            message:
                'عند ربط عقود إدارة المستخدمين ستظهر هنا الحسابات وحالاتها وأدوارها والمحطات المعيّنة.',
          ),
        ),
      ],
    );
  }
}

class _RegistrationTab extends StatelessWidget {
  const _RegistrationTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'مسار الموافقة على مرحلتين موجود في العقود الخلفية. الواجهة تعرض الطلبات وحالاتها دون كتابة مباشرة على قاعدة البيانات من العميل.',
        ),
        SizedBox(height: 12),
        MetraSectionCard(
          title: 'طلبات التسجيل والموافقة',
          child: MetraEmptyState(
            icon: Icons.how_to_reg_outlined,
            title: 'لا توجد طلبات معروضة',
            message:
                'عند توفر بيانات الطلبات ستظهر هنا حالة الانتظار والموافقة وربط المحطات.',
          ),
        ),
      ],
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        MetraSectionCard(
          title: 'الأدوار والصلاحيات',
          child: MetraEmptyState(
            icon: Icons.security_outlined,
            title: 'مصفوفة الصلاحيات',
            message:
                'تُعرض الأدوار والصلاحيات من مصدر الخادم المعتمد فقط. لا تُستنتج صلاحيات من الواجهة.',
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        MetraSectionCard(
          title: 'سجل نشاط المستخدم',
          child: MetraEmptyState(
            icon: Icons.history,
            title: 'السجل فارغ',
            message: 'يُعرض سجل النشاط عند ربط مصدر التدقيق المعتمد.',
          ),
        ),
      ],
    );
  }
}
