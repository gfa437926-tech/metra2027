import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Specialist module form presentation. It may collect a local preview, but
/// never submits or persists values until an approved field contract and API exist.
class SpecialistUnitShellScreen extends StatefulWidget {
  const SpecialistUnitShellScreen({
    super.key,
    required this.title,
    required this.unitCode,
    required this.description,
    this.api,
    this.requiredBeforeBinding = const <String>[],
    this.plannedFields = const <String>[],
  });

  final String title;
  final String unitCode;
  final String description;
  final MetraApiClient? api;
  final List<String> requiredBeforeBinding;
  /// Labels taken from the current working requirements; no ranges or rules inferred.
  final List<String> plannedFields;

  @override
  State<SpecialistUnitShellScreen> createState() => _SpecialistUnitShellScreenState();
}

class _SpecialistUnitShellScreenState extends State<SpecialistUnitShellScreen> {
  late Future<List<StationDirectoryItem>>? _stations;
  final Map<String, TextEditingController> _controllers = {};
  String? _stationId;
  DateTime? _reportDate;
  String? _previewMessage;

  static const _navy = Color(0xFF061B4A);

  @override
  void initState() {
    super.initState();
    _stations = widget.api?.getAllStationDirectory();
    for (final field in widget.plannedFields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _reportDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'تاريخ التقرير (UTC)',
    );
    if (value != null) setState(() => _reportDate = value);
  }

  void _preview() {
    final station = _stationId;
    if (station == null) {
      setState(() => _previewMessage = 'اختر محطة معتمدة أولاً.');
      return;
    }
    final entered = _controllers.values.where((c) => c.text.trim().isNotEmpty).length;
    setState(() => _previewMessage =
      'معاينة محلية فقط: المحطة محددة، وتم إدخال $entered من ${_controllers.length} حقول. لم يتم الحفظ أو الإرسال.');
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            color: const Color(0xFFEEF6FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
                  const SizedBox(height: 8),
                  Text(widget.description, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 10),
                  Text('رمز الوحدة: ${widget.unitCode}', style: const TextStyle(fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFF7E8),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'واجهة إعداد ومعاينة فقط. لا يوجد عقد حقول نهائي أو API حفظ معتمد لهذه الوحدة. لن تُعرض قيم تجريبية على أنها بيانات حقيقية ولن يُرسل أي نموذج.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('سياق المحطة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _stationSelector(),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(_reportDate == null ? 'تحديد تاريخ التقرير UTC' : _dateLabel(_reportDate!)),
          ),
          if (widget.plannedFields.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('حقول الوحدة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final field in widget.plannedFields) ...[
              TextField(
                controller: _controllers[field],
                decoration: InputDecoration(
                  labelText: field,
                  border: const OutlineInputBorder(),
                  helperText: 'المجال والوحدة والتحقق النهائي قيد اعتماد العقد',
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.preview_outlined),
              label: const Text('معاينة محلية دون حفظ'),
            ),
            if (_previewMessage != null) ...[
              const SizedBox(height: 8),
              Text(_previewMessage!, style: const TextStyle(color: Color(0xFF1D5F46))),
            ],
          ] else ...[
            const SizedBox(height: 14),
            const Text('فلاتر الاستعلام', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Text('ستظهر فلاتر المتغير والفترة والتجميع بعد اعتماد تعريفات التقارير المناخية.'),
          ],
          const SizedBox(height: 18),
          const Text('متطلبات الربط', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...widget.requiredBeforeBinding.map((item) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.radio_button_unchecked, size: 18),
            title: Text(item),
          )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline),
            label: const Text('الحفظ والإرسال غير متاحين حتى اعتماد API'),
          ),
        ],
      ),
    ),
  );

  Widget _stationSelector() {
    if (_stations == null) {
      return const Text('دليل المحطات غير مهيأ في هذه الجلسة.');
    }
    return FutureBuilder<List<StationDirectoryItem>>(
      future: _stations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return const Text('تعذر تحميل المحطات المعتمدة.');
        }
        final rows = (snapshot.data ?? const <StationDirectoryItem>[])
          .where((s) => s.approvalStatus == 'approved' && s.operationalStatus == 'active' && !s.isDemo)
          .toList(growable: false);
        return DropdownButtonFormField<String>(
          initialValue: rows.any((s) => s.id == _stationId) ? _stationId : null,
          decoration: const InputDecoration(labelText: 'المحطة', border: OutlineInputBorder()),
          items: rows.map((s) => DropdownMenuItem<String>(
            value: s.id,
            child: Text('${s.nameArabic} — ${s.localCode}'),
          )).toList(),
          onChanged: (value) => setState(() {
            _stationId = value;
            _previewMessage = null;
          }),
        );
      },
    );
  }

  String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} UTC';
}
