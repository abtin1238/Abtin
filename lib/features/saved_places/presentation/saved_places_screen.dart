import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/thumb_back_button.dart';
import '../../gps/presentation/gps_providers.dart';
import 'saved_places_providers.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(savedPlacesListProvider);

    return Scaffold(
      appBar: const PageHeader(title: 'علاقه‌مندی‌ها', backRoute: '/settings'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.subAccentB,
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add_location_alt_rounded),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF1E1B42), Color(0xFF0B0A1E)],
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: GlassPanel(
                child: placesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.subAccentA)),
                  error: (e, st) => Center(
                    child: Text('خطا در خواندن دیتابیس: $e', style: const TextStyle(color: Colors.white70)),
                  ),
                  data: (places) {
                    if (places.isEmpty) {
                      return const Center(
                        child: Text('هنوز مکانی ذخیره نکرده‌اید', style: TextStyle(color: AppColors.textSecondary)),
                      );
                    }
                    return ListView.separated(
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final place = places[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.subGlassBgSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.subGlassBorder),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B81)),
                                onPressed: () => ref.read(savedPlacesRepositoryProvider).remove(place.id),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(place.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (place.address != null) ...[
                                      const SizedBox(height: 2),
                                      Text(place.address!,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.star_rounded, color: AppColors.subAccentB, size: 18),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const BottomNav(currentPage: NavKey.settings),
            const ThumbBackButton(backRoute: '/settings'),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1836),
        title: const Text('افزودن موقعیت فعلی', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'مثلاً خانه، محل کار...',
            hintStyle: TextStyle(color: Color(0xFF8B929B)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final pos = ref.read(vehiclePositionProvider).valueOrNull;
              if (pos == null) {
                Navigator.pop(ctx);
                return;
              }
              await ref.read(savedPlacesRepositoryProvider).add(
                    name: name,
                    latitude: pos.lat,
                    longitude: pos.lng,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ذخیره موقعیت فعلی من'),
          ),
        ],
      ),
    );
  }
}
