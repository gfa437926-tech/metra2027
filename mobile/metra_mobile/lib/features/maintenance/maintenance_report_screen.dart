import 'package:flutter/material.dart';

/// Local-first maintenance intake form. It deliberately does not claim to save
/// remotely until the approved maintenance API and database contract exist.
class MaintenanceReportScreen extends StatefulWidget {
  const MaintenanceReportScreen({super.key});
  @override
  State<MaintenanceReportScreen> createState() => _MaintenanceReportScreenState();
}

class _MaintenanceReportScreenState extends State<MaintenanceReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equipment = TextEditingController();
  final _description = TextEditingController();
  String _category = 'أجهزة الرصد';
  String _severity = 'High';
  bool _blocking = false;
  bool _draftReady = false;

  @override
  void dispose() {
    _equipment.dispose();
    _description.dispose();
    super.dispose();
  }

  void _prepareDraft() {
    if (!_formKey.currentState!.validate()) return;
    if (_blocking && _severity == 'Low') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العطل الذي يوقف العمل يجب أن يكون متوسطاً أو أعلى.')),
      );
      return;
    }
    setState(() => _draftReady = true);
  }

  void _reset() {
    _formKey.currentState?.reset();
    _equipment.clear();
    _description.clear();
    setState(() {
      _category = 'أجهزة الرصد';
      _severity = 'High';
      _blocking = false;
      _draftReady = false;
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          elevation: 0,
          color: const Color(0xFF061B4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.build_circle_outlined, color: Colors.white, size: 34),
              SizedBox(height: 12),
              Text('بلاغ عطل وصيانة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('إدخال تفاصيل العطل وتجهيز البلاغ للمراجعة.', style: TextStyle(color: Color(0xFFD6E8FF))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (_draftReady)
          Card(
            color: const Color(0xFFEAF4FF),
            elevation: 0,
            child: const ListTile(
              leading: Icon(Icons.check_circle_outline, color: Color(0xFF087CF0)),
              title: Text('تم تجهيز البلاغ محلياً'),
              subtitle: Text('لم يُرسل إلى الخادم بعد. يتطلب الإرسال ربط واجهة الصيانة المعتمدة.'),
            ),
          ),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'تصنيف المعدة'),
                  items: const [
                    DropdownMenuItem(value: 'أجهزة الرصد', child: Text('أجهزة الرصد')),
                    DropdownMenuItem(value: 'الاتصالات', child: Text('الاتصالات')),
                    DropdownMenuItem(value: 'الحاسب والشبكة', child: Text('الحاسب والشبكة')),
                    DropdownMenuItem(value: 'الكهرباء والطاقة', child: Text('الكهرباء والطاقة')),
                    DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                  ],
                  onChanged: (value) => setState(() { _category = value ?? _category; _draftReady = false; }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _equipment,
                  decoration: const InputDecoration(labelText: 'اسم الجهاز', hintText: 'مثال: مقياس الحرارة'),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().length < 2)
                    ? 'أدخل اسم الجهاز (محرفان على الأقل).' : null,
                  onChanged: (_) => setState(() => _draftReady = false),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'شدة العطل'),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('منخفض')),
                    DropdownMenuItem(value: 'Medium', child: Text('متوسط')),
                    DropdownMenuItem(value: 'High', child: Text('عالٍ')),
                    DropdownMenuItem(value: 'Critical', child: Text('حرج')),
                  ],
                  onChanged: (value) => setState(() { _severity = value ?? _severity; _draftReady = false; }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('العطل يوقف العمل'),
                  value: _blocking,
                  onChanged: (value) => setState(() { _blocking = value; _draftReady = false; }),
                ),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: const InputDecoration(labelText: 'وصف العطل', hintText: 'صف المشكلة ووقت ظهورها وأثرها على العمل.'),
                  validator: (value) => (value == null || value.trim().length < 10)
                    ? 'الوصف يجب ألا يقل عن 10 محارف.' : null,
                  onChanged: (_) => setState(() => _draftReady = false),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _prepareDraft,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('تحقق وجهّز البلاغ'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('مسح النموذج'),
                ),
              ]),
            ),
          ),
        ),
      ],
    ),
  );
}
