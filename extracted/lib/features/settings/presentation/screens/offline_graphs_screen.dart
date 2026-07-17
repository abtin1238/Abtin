import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_notification_banner.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../maps/data/graph_registry.dart';

/// انتخاب گراف مسیریابی آفلاین (استان).
class OfflineGraphsScreen extends ConsumerStatefulWidget {
  const OfflineGraphsScreen({super.key});

  @override
  ConsumerState<OfflineGraphsScreen> createState() =>
      _OfflineGraphsScreenState();
}

class _OfflineGraphsScreenState extends ConsumerState<OfflineGraphsScreen> {
  String? _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    try {
      _active = ref.read(routingServiceProvider).activeGraphId;
    } catch (_) {
      _active = GraphRegistry.defaultPackage.id;
    }
  }

  Future<void> _activate(OfflineGraphPackage pkg) async {
    setState(() => _busy = true);
    final n = ref.read(appNotificationProvider.notifier);
    try {
      await ref.read(routingServiceProvider).loadProvinceGraph(pkg.id);
      if (!mounted) return;
      setState(() => _active = pkg.id);
      n.show('گراف «${pkg.nameFa}» فعال شد', type: AppNotifyType.success);
    } catch (e) {
      n.show('فعال‌سازی گراف ناموفق: $e', type: AppNotifyType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = GraphRegistry.packages;
    return Scaffold(
      appBar: AppBar(title: const Text('گراف مسیریابی آفلاین')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'گراف جاده برای مسیریابی A* کاملاً آفلاین است. '
            'تهران متراکم پیش‌فرض است؛ برای استان‌های دیگر گراف همان استان را فعال کنید.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryDark,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('بسته‌های bundled'),
          ...packages.map((pkg) {
            final selected = _active == pkg.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: _busy ? null : () => _activate(pkg),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.hub_rounded,
                      color: selected ? AppColors.primary : AppColors.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.nameFa,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            pkg.id,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Text(
                        'فعال',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      const Icon(Icons.chevron_left_rounded,
                          color: Colors.white38),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
