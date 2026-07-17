import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/vehicle_download_service.dart';
import '../../data/vehicle_registry.dart';

/// صفحه‌ی «دانلود خودرو» — سه خودروی سه‌بعدیِ GLB از لینکِ رایگان، داخلِ اپ.
///
/// هر خودرو را می‌توان دانلود، پیش‌نمایشِ سه‌بعدی و به‌عنوانِ نشانگرِ فعال انتخاب کرد.
class VehicleDownloadScreen extends ConsumerStatefulWidget {
  const VehicleDownloadScreen({super.key});

  @override
  ConsumerState<VehicleDownloadScreen> createState() =>
      _VehicleDownloadScreenState();
}

class _VehicleDownloadScreenState extends ConsumerState<VehicleDownloadScreen> {
  final Map<String, VehicleDownloadState> _states = {};
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final svc = ref.read(vehicleDownloadServiceProvider);
    _selectedId = svc.selectedVehicleId?.isEmpty == true
        ? null
        : svc.selectedVehicleId;
    for (final m in VehicleRegistry.models) {
      final path = await svc.installedPath(m);
      _states[m.id] = VehicleDownloadState(
        installed: path != null,
        filePath: path,
        progress: path != null ? 1 : 0,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _download(VehicleModel model) async {
    final svc = ref.read(vehicleDownloadServiceProvider);
    setState(() => _states[model.id] =
        const VehicleDownloadState(downloading: true, progress: 0));
    try {
      final path = await svc.download(model, onProgress: (p) {
        if (mounted) {
          setState(() => _states[model.id] =
              VehicleDownloadState(downloading: true, progress: p));
        }
      });
      if (mounted) {
        setState(() => _states[model.id] = VehicleDownloadState(
            installed: true, progress: 1, filePath: path));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _states[model.id] = const VehicleDownloadState());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در دانلود: $e')),
        );
      }
    }
  }

  Future<void> _delete(VehicleModel model) async {
    final svc = ref.read(vehicleDownloadServiceProvider);
    await svc.delete(model);
    await _refresh();
  }

  void _select(VehicleModel model) {
    final svc = ref.read(vehicleDownloadServiceProvider);
    final newId = _selectedId == model.id ? null : model.id;
    svc.selectVehicle(newId);
    setState(() => _selectedId = newId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دانلود خودرو')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: const Text(
              'خودروهای سه‌بعدی (فرمت GLB) را دانلود کنید تا به‌جای پیکانِ پیش‌فرض '
              'روی نقشه نمایش داده شوند. مدل‌ها فقط یک‌بار دانلود می‌شوند و پس از آن '
              'کاملاً آفلاین در دسترس‌اند.',
              style: TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
          for (final model in VehicleRegistry.models) _vehicleCard(model),
        ],
      ),
    );
  }

  Widget _vehicleCard(VehicleModel model) {
    final st = _states[model.id] ?? const VehicleDownloadState();
    final selected = _selectedId == model.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.borderDark,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // پیش‌نمایشِ سه‌بعدی (پس از دانلود) یا نمادِ خودرو.
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: st.installed && st.filePath != null
                  ? Flutter3DViewer(
                      src: st.filePath!,
                      progressBarColor: AppColors.primary,
                    )
                  : Container(
                      color: Colors.black.withOpacity(0.25),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.directions_car_rounded,
                        size: 64,
                        color: AppColors.primary.withOpacity(0.4),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.nameFa,
                              style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${model.format.toUpperCase()} · ${model.sizeLabel}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('فعال',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (st.downloading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: st.progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('در حال دانلود... ${(st.progress * 100).round()}%',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  )
                else if (st.installed)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: selected
                                ? Colors.white.withOpacity(0.12)
                                : AppColors.primary,
                          ),
                          onPressed: () => _select(model),
                          icon: Icon(selected
                              ? Icons.check_circle_rounded
                              : Icons.check_rounded),
                          label: Text(selected ? 'انتخاب‌شده' : 'انتخاب'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _delete(model),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger),
                        tooltip: 'حذف',
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _download(model),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('دانلود'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
