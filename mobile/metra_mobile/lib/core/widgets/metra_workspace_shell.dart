import 'package:flutter/material.dart';
import 'metra_ui.dart';

/// Shared shell for multi-section scientific and operational workspaces.
class MetraWorkspaceShell extends StatelessWidget {
  const MetraWorkspaceShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.banner,
    required this.sectionLabels,
    required this.sectionIcons,
    required this.section,
    required this.onSectionChanged,
    required this.body,
    this.bannerTone = MetraBannerTone.warning,
  });

  final String title;
  final String subtitle;
  final String banner;
  final MetraBannerTone bannerTone;
  final List<String> sectionLabels;
  final List<IconData> sectionIcons;
  final int section;
  final ValueChanged<int> onSectionChanged;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    assert(sectionLabels.length == sectionIcons.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        MetraPageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 8),
        MetraStatusBanner(tone: bannerTone, message: banner),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < sectionLabels.length; i++)
                ButtonSegment(
                  value: i,
                  label: Text(sectionLabels[i]),
                  icon: Icon(sectionIcons[i]),
                ),
            ],
            selected: {section},
            onSelectionChanged: (v) => onSectionChanged(v.first),
          ),
        ),
        const SizedBox(height: 14),
        body,
      ],
    );
  }
}

/// Catalog tile used across reports and dashboards without inventing data.
class MetraCatalogTile extends StatelessWidget {
  const MetraCatalogTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.status = 'جاهز للواجهة · ينتظر مصدر بيانات معتمد',
    this.onOpen,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: metraBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: metraNavy,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: metraMuted, height: 1.45)),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(fontSize: 12, color: metraMuted)),
            if (onOpen != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetraChecklistCard extends StatelessWidget {
  const MetraChecklistCard({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MetraSectionCard(
      title: title,
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline, color: metraBlue, size: 20),
              title: Text(item, style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    );
  }
}
