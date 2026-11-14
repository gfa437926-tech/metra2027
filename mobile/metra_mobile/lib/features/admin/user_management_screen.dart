// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

/// Account and user management workspace bound to live .NET read endpoints.
/// Writes remain server-authorized; this screen does not invent directory data.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  String? _authorityId;

  Future<List<MetraJsonRow>>? _authorities;
  Future<List<MetraJsonRow>>? _stationUsers;
  Future<List<MetraJsonRow>>? _registrationRoles;
  Future<Map<String, dynamic>>? _registrationStatus;

  Future<List<MetraJsonRow>>? _membershipQueue;
  Future<List<MetraJsonRow>>? _permissionGrantQueue;
  Future<List<MetraJsonRow>>? _activeMemberships;
  Future<List<MetraJsonRow>>? _activePermissionGrants;

  Future<List<MetraJsonRow>>? _membershipRoles;
  Future<List<MetraJsonRow>>? _permissionOptions;
  Future<List<MetraJsonRow>>? _accessAudit;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _reloadAll();
  }

  @override
  void didUpdateWidget(covariant UserManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _reloadStationUsers();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _reloadStationUsers();

    _authorities = widget.api.getAuthorities().then((rows) {
      if (_authorityId == null && rows.isNotEmpty) {
        final firstId = rows.first.stringValue('id') ??
            rows.first.stringValue('authority_id', 'authorityId');

        if (firstId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            setState(() {
              _authorityId = firstId;
              _reloadAuthorityBound();
            });
          });
        }
      }

      return rows;
    });

    if (_authorityId != null) {
      _reloadAuthorityBound();
    }

    _registrationRoles = widget.api.getRegistrationRoles();
    _registrationStatus = widget.api.getMyRegistrationStatus();

    setState(() {});
  }

  void _reloadStationUsers() {
    final stationId = widget.stationId;

    _stationUsers =
        stationId == null ? null : widget.api.getStationUsers(stationId);
  }

  void _reloadAuthorityBound() {
    final authorityId = _authorityId;

    if (authorityId == null) {
      _membershipQueue = null;
      _permissionGrantQueue = null;
      _activeMemberships = null;
      _activePermissionGrants = null;
      _membershipRoles = null;
      _permissionOptions = null;
      _accessAudit = null;
      return;
    }

    _membershipQueue = widget.api.getAuthorityAccessQueue(
      authorityId,
      kind: 'membership',
    );

    _permissionGrantQueue = widget.api.getAuthorityAccessQueue(
      authorityId,
      kind: 'permission_grant',
    );

    _activeMemberships = widget.api.getAuthorityAccessQueue(
      authorityId,
      kind: 'membership_active',
    );

    _activePermissionGrants = widget.api.getAuthorityAccessQueue(
      authorityId,
      kind: 'permission_grant_active',
    );

    _membershipRoles = widget.api.getAuthorityMembershipRoles(authorityId);
    _permissionOptions = widget.api.getAuthorityPermissionOptions(authorityId);
    _accessAudit = widget.api.getAuthorityAccessAudit(authorityId);
  }

  String _errorMessage(Object error) {
    if (error is MetraApiException) {
      return switch (error.statusCode) {
        401 => 'يلزم تسجيل الدخول مجدداً.',
        403 => 'ليست لديك صلاحية لعرض هذه البيانات.',
        503 => 'الخدمة غير متاحة حالياً (إعداد الخادم أو قاعدة البيانات).',
        _ => 'تعذر التحميل (${error.statusCode}: ${error.code}).',
      };
    }

    return 'تعذر التحميل. تحقق من الاتصال ثم أعد المحاولة.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MetraPageHeader(
          title: 'إدارة الحسابات والمستخدمين',
          subtitle:
              'البيانات تُحمّل من واجهات .NET المعتمدة. لا تُعرض بيانات وهمية كأنها تشغيلية.',
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: metraNavy,
          tabs: const [
            Tab(text: 'مستخدمو المحطة'),
            Tab(text: 'التسجيل'),
            Tab(text: 'الجهة والصلاحيات'),
            Tab(text: 'سجل الوصول'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _StationUsersTab(
                stationId: widget.stationId,
                future: _stationUsers,
                onRefresh: () => setState(_reloadStationUsers),
                errorMessage: _errorMessage,
              ),
              _RegistrationTab(
                rolesFuture: _registrationRoles,
                statusFuture: _registrationStatus,
                onRefresh: () => setState(() {
                  _registrationRoles = widget.api.getRegistrationRoles();
                  _registrationStatus = widget.api.getMyRegistrationStatus();
                }),
                errorMessage: _errorMessage,
              ),
              _AuthorityTab(
                authoritiesFuture: _authorities,
                authorityId: _authorityId,
                membershipRolesFuture: _membershipRoles,
                permissionOptionsFuture: _permissionOptions,
                membershipQueueFuture: _membershipQueue,
                permissionGrantQueueFuture: _permissionGrantQueue,
                activeMembershipsFuture: _activeMemberships,
                activePermissionGrantsFuture: _activePermissionGrants,
                onSelectAuthority: (id) => setState(() {
                  _authorityId = id;
                  _reloadAuthorityBound();
                }),
                onRefresh: () => setState(_reloadAll),
                errorMessage: _errorMessage,
              ),
              _AccessAuditTab(
                authorityId: _authorityId,
                future: _accessAudit,
                onRefresh: () => setState(_reloadAuthorityBound),
                errorMessage: _errorMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StationUsersTab extends StatelessWidget {
  const _StationUsersTab({
    required this.stationId,
    required this.future,
    required this.onRefresh,
    required this.errorMessage,
  });

  final String? stationId;
  final Future<List<MetraJsonRow>>? future;
  final VoidCallback onRefresh;
  final String Function(Object error) errorMessage;

  @override
  Widget build(BuildContext context) {
    if (stationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: MetraEmptyState(
          icon: Icons.location_off_outlined,
          title: 'اختر محطة أولاً',
          message:
              'مستخدمو المحطة يُحمّلون من /api/v1/stations/{id}/users بعد اختيار محطة من الدليل.',
        ),
      );
    }

    return _LiveListPane(
      future: future,
      onRefresh: onRefresh,
      errorMessage: errorMessage,
      emptyTitle: 'لا يوجد مستخدمون لهذه المحطة',
      emptyMessage: 'أعاد الخادم قائمة فارغة ضمن صلاحياتك.',
      banner:
          'مصدر حي: مستخدمو المحطة. أي رفض 403/503 يعكس سياسة الخادم وليس بيانات محلية.',
    );
  }
}

class _RegistrationTab extends StatelessWidget {
  const _RegistrationTab({
    required this.rolesFuture,
    required this.statusFuture,
    required this.onRefresh,
    required this.errorMessage,
  });

  final Future<List<MetraJsonRow>>? rolesFuture;
  final Future<Map<String, dynamic>>? statusFuture;
  final VoidCallback onRefresh;
  final String Function(Object error) errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'حالة التسجيل وأدوار الطلب تُجلب من .NET. تقديم طلب جديد يبقى خاضعاً لعقود الخادم.',
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'حالتي في التسجيل',
          trailing: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: statusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  errorMessage(snapshot.error!),
                  style: const TextStyle(color: metraMuted),
                );
              }

              final data = snapshot.data ?? const {};

              if (data.isEmpty) {
                return const Text(
                  'لا توجد حالة تسجيل معروضة.',
                  style: TextStyle(color: metraMuted),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(color: metraNavy),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'الأدوار القابلة للطلب',
          child: FutureBuilder<List<MetraJsonRow>>(
            future: rolesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  errorMessage(snapshot.error!),
                  style: const TextStyle(color: metraMuted),
                );
              }

              final rows = snapshot.data ?? const [];

              if (rows.isEmpty) {
                return const MetraEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'لا توجد أدوار قابلة للطلب',
                  message: 'الخادم لم يُرجع أدواراً requestable نشطة.',
                );
              }

              return Column(
                children: rows
                    .map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.displayTitle()),
                        subtitle: Text(row.displaySubtitle() ?? ''),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuthorityTab extends StatelessWidget {
  const _AuthorityTab({
    required this.authoritiesFuture,
    required this.authorityId,
    required this.membershipRolesFuture,
    required this.permissionOptionsFuture,
    required this.membershipQueueFuture,
    required this.permissionGrantQueueFuture,
    required this.activeMembershipsFuture,
    required this.activePermissionGrantsFuture,
    required this.onSelectAuthority,
    required this.onRefresh,
    required this.errorMessage,
  });

  final Future<List<MetraJsonRow>>? authoritiesFuture;
  final String? authorityId;
  final Future<List<MetraJsonRow>>? membershipRolesFuture;
  final Future<List<MetraJsonRow>>? permissionOptionsFuture;

  final Future<List<MetraJsonRow>>? membershipQueueFuture;
  final Future<List<MetraJsonRow>>? permissionGrantQueueFuture;
  final Future<List<MetraJsonRow>>? activeMembershipsFuture;
  final Future<List<MetraJsonRow>>? activePermissionGrantsFuture;

  final ValueChanged<String> onSelectAuthority;
  final VoidCallback onRefresh;
  final String Function(Object error) errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'كتالوج الجهات وطوابير الوصول تُحمّل من مسارات Authority access في .NET.',
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'الجهات',
          trailing: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          child: FutureBuilder<List<MetraJsonRow>>(
            future: authoritiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  errorMessage(snapshot.error!),
                  style: const TextStyle(color: metraMuted),
                );
              }

              final rows = snapshot.data ?? const [];

              if (rows.isEmpty) {
                return const MetraEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'لا توجد جهات',
                  message: 'كتالوج الجهات فارغ أو غير متاح ضمن صلاحياتك.',
                );
              }

              return Column(
                children: rows.map((row) {
                  final id = row.stringValue('id') ??
                      row.stringValue('authority_id', 'authorityId');

                  final selected = id != null && id == authorityId;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: selected,
                    title: Text(row.displayTitle()),
                    subtitle: Text(row.displaySubtitle() ?? id ?? ''),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: metraBlue)
                        : const Icon(Icons.chevron_left),
                    onTap: id == null ? null : () => onSelectAuthority(id),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'أدوار العضوية',
          child: _MiniLiveList(
            future: membershipRolesFuture,
            errorMessage: errorMessage,
            empty: 'اختر جهة لعرض أدوار العضوية.',
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'خيارات الصلاحيات',
          child: _MiniLiveList(
            future: permissionOptionsFuture,
            errorMessage: errorMessage,
            empty: 'اختر جهة لعرض خيارات الصلاحيات.',
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'طلبات العضوية قيد المراجعة',
          child: _MiniLiveList(
            future: membershipQueueFuture,
            errorMessage: errorMessage,
            empty: 'لا توجد طلبات عضوية قيد المراجعة أو لم يتم اختيار جهة.',
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'طلبات منح الصلاحيات قيد المراجعة',
          child: _MiniLiveList(
            future: permissionGrantQueueFuture,
            errorMessage: errorMessage,
            empty:
                'لا توجد طلبات منح صلاحيات قيد المراجعة أو لم يتم اختيار جهة.',
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'العضويات المعتمدة',
          child: _MiniLiveList(
            future: activeMembershipsFuture,
            errorMessage: errorMessage,
            empty: 'لا توجد عضويات معتمدة أو لم يتم اختيار جهة.',
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'منح الصلاحيات المعتمدة',
          child: _MiniLiveList(
            future: activePermissionGrantsFuture,
            errorMessage: errorMessage,
            empty: 'لا توجد منح صلاحيات معتمدة أو لم يتم اختيار جهة.',
          ),
        ),
      ],
    );
  }
}

class _AccessAuditTab extends StatelessWidget {
  const _AccessAuditTab({
    required this.authorityId,
    required this.future,
    required this.onRefresh,
    required this.errorMessage,
  });

  final String? authorityId;
  final Future<List<MetraJsonRow>>? future;
  final VoidCallback onRefresh;
  final String Function(Object error) errorMessage;

  @override
  Widget build(BuildContext context) {
    if (authorityId == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: MetraEmptyState(
          icon: Icons.history,
          title: 'اختر جهة أولاً',
          message: 'سجل وصول الجهة يُحمّل بعد اختيار جهة من تبويب الصلاحيات.',
        ),
      );
    }

    return _LiveListPane(
      future: future,
      onRefresh: onRefresh,
      errorMessage: errorMessage,
      emptyTitle: 'لا توجد أحداث وصول',
      emptyMessage: 'الخادم أعاد سجلاً فارغاً لهذه الجهة.',
      banner: 'مصدر حي: سجل وصول الجهة من .NET.',
    );
  }
}

class _LiveListPane extends StatelessWidget {
  const _LiveListPane({
    required this.future,
    required this.onRefresh,
    required this.errorMessage,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.banner,
  });

  final Future<List<MetraJsonRow>>? future;
  final VoidCallback onRefresh;
  final String Function(Object error) errorMessage;
  final String emptyTitle;
  final String emptyMessage;
  final String banner;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MetraStatusBanner(
          tone: MetraBannerTone.info,
          message: banner,
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'النتائج',
          trailing: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          child: FutureBuilder<List<MetraJsonRow>>(
            future: future,
            builder: (context, snapshot) {
              if (future == null ||
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage(snapshot.error!),
                      style: const TextStyle(color: metraMuted),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: onRefresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                );
              }

              final rows = snapshot.data ?? const [];

              if (rows.isEmpty) {
                return MetraEmptyState(
                  icon: Icons.inbox_outlined,
                  title: emptyTitle,
                  message: emptyMessage,
                );
              }

              return Column(
                children: rows
                    .map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.displayTitle()),
                        subtitle: Text(row.displaySubtitle() ?? ''),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniLiveList extends StatelessWidget {
  const _MiniLiveList({
    required this.future,
    required this.errorMessage,
    required this.empty,
  });

  final Future<List<MetraJsonRow>>? future;
  final String Function(Object error) errorMessage;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return Text(
        empty,
        style: const TextStyle(color: metraMuted),
      );
    }

    return FutureBuilder<List<MetraJsonRow>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text(
            errorMessage(snapshot.error!),
            style: const TextStyle(color: metraMuted),
          );
        }

        final rows = snapshot.data ?? const [];

        if (rows.isEmpty) {
          return Text(
            empty,
            style: const TextStyle(color: metraMuted),
          );
        }

        return Column(
          children: rows
              .map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(row.displayTitle()),
                  subtitle: Text(row.displaySubtitle() ?? ''),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
