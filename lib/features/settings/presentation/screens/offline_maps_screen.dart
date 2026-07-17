import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/offline_map_download_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_notification_banner.dart';
import '../../../../core/widgets/common_widgets.dart';

/// صفحهٔ دانلود نقشهٔ آفلاین — کشورها + **استان‌های ایران**.
class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen> {
  final Map<String, double> _progress = {};
  final Map<String, bool> _downloaded = {};
  String? _downloadingId;
  String _tab = 'province'; // province | country

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final service = ref.read(offlineMapDownloadServiceProvider);
    for (final region in downloadableRegions) {
      final done = await service.isDownloaded(region);
      if (!mounted) return;
      setState(() => _downloaded[region.id] = done);
    }
  }

  Future<void> _startDownload(DownloadableRegion region) async {
    final service = ref.read(offlineMapDownloadServiceProvider);
    final notifier = ref.read(appNotificationProvider.notifier);
    setState(() {
      _downloadingId = region.id;
      _progress[region.id] = 0;
    });
    notifier.show(
      'در حال دانلود نقشهٔ ${region.name}...',
      type: AppNotifyType.loading,
    );
    try {
      await for (final p in service.download(region)) {
        if (!mounted) return;
        setState(() => _progress[region.id] = p);
      }
      if (!mounted) return;
      setState(() {
        _downloadingId = null;
        _downloaded[region.id] = true;
      });
      notifier.show(
        'نقشهٔ ${region.name} برای استفادهٔ آفلاین ذخیره شد',
        type: AppNotifyType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadingId = null);
      notifier.show(
        'دانلود نقشهٔ ${region.name} ناموفق بود',
        type: AppNotifyType.error,
      );
    }
  }

  Future<void> _removeDownload(DownloadableRegion region) async {
    final service = ref.read(offlineMapDownloadServiceProvider);
    await service.remove(region);
    if (!mounted) return;
    setState(() => _downloaded[region.id] = false);
    ref.read(appNotificationProvider.notifier).show(
          'نقشهٔ ${region.name} حذف شد',
          type: AppNotifyType.info,
        );
  }

  List<DownloadableRegion> get _visible {
    if (_tab == 'province') {
      return downloadableRegions.where((r) => r.level == 'province').toList();
    }
    return downloadableRegions.where((r) => r.level == 'country').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دانلود نقشهٔ آفلاین')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'کاشی نقشه را بر اساس استان یا کشور دانلود کنید. گراف مسیریابی آفلاین استان‌ها در assets/maps (ir_*_graph.json) bundled است تا بدون اینترنت '
            'نمایش داده شود. مسیریابی آفلاین از گراف جاده استفاده می‌کند '
            '(نمونه تهران همراه اپ است؛ برای دقت سراسری بستهٔ گراف جدا نصب شود).',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryDark,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TabChip(
                  label: 'استان‌های ایران',
                  selected: _tab == 'province',
                  onTap: () => setState(() => _tab = 'province'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TabChip(
                  label: 'کشورها',
                  selected: _tab == 'country',
                  onTap: () => setState(() => _tab = 'country'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(
            _tab == 'province' ? 'استان‌ها' : 'کشورها',
          ),
          ..._visible.map(_regionTile),
        ],
      ),
    );
  }

  Widget _regionTile(DownloadableRegion region) {
    final downloading = _downloadingId == region.id;
    final progress = _progress[region.id] ?? 0;
    final done = _downloaded[region.id] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  done
                      ? Icons.offline_pin_rounded
                      : Icons.map_rounded,
                  color: done ? AppColors.primary : AppColors.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        done
                            ? 'دانلود شده · آمادهٔ آفلاین'
                            : 'حدود ${region.approxSizeMb.toStringAsFixed(0)} مگابایت',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (downloading)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: progress > 0 ? progress : null,
                      color: AppColors.primary,
                    ),
                  )
                else if (done)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                    onPressed: () => _removeDownload(region),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_rounded,
                        color: AppColors.primary),
                    onPressed: () => _startDownload(region),
                  ),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 6,
                  backgroundColor: AppColors.borderDark,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}٪',
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withOpacity(0.18)
          : AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withOpacity(0.6)
                  : AppColors.borderDark,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
