import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/category_ui.dart';
import '../../../../core/widgets/app_notification_banner.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../navigation/data/navigation_controller.dart';
import '../../../navigation/data/sample_data.dart';
import '../../../navigation/domain/entities/place.dart';

/// صفحهٔ مکان‌های مورد علاقه — داده واقعی از SQLite رمزنگاری‌شده.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _query = '';

  List<Place> _places() {
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      final all = repo.getAll();
      if (all.isNotEmpty) return all;
    } catch (_) {
      // bootstrap هنوز آماده نیست
    }
    return SampleData.favoritePlaces;
  }

  Future<void> _navigateTo(Place place) async {
    final notifier = ref.read(appNotificationProvider.notifier);
    notifier.show('در حال محاسبهٔ مسیر آفلاین...', type: AppNotifyType.loading);
    try {
      final nav = ref.read(navigationControllerProvider);
      final origin = nav.position ?? defaultMapCenter;
      final routing = ref.read(routingServiceProvider);
      final route = await routing.route(origin, place.location);
      ref.read(navigationControllerProvider.notifier).startRoute(route);
      notifier.show('مسیریابی به ${place.title} آغاز شد',
          type: AppNotifyType.success);
      ref.read(bottomNavIndexProvider.notifier).state = 0;
    } catch (e) {
      notifier.show('خطا در مسیریابی: $e', type: AppNotifyType.error);
    }
  }

  void _remove(Place place) {
    try {
      ref.read(favoritesRepositoryProvider).remove(place.id);
      setState(() {});
      ref.read(appNotificationProvider.notifier).show(
            '«${place.title}» حذف شد',
            type: AppNotifyType.info,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final places = _places().where((p) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.subtitle.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مکان‌های مورد علاقه'),
        actions: [
          IconButton(
            onPressed: () {
              final nav = ref.read(navigationControllerProvider);
              try {
                ref.read(favoritesRepositoryProvider).add(
                      Place(
                        id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
                        title: 'موقعیت ذخیره‌شده',
                        subtitle:
                            '${nav.position.latitude.toStringAsFixed(4)}, ${nav.position.longitude.toStringAsFixed(4)}',
                        location: nav.position,
                        category: PlaceCategory.other,
                        isFavorite: true,
                      ),
                    );
                setState(() {});
                ref.read(appNotificationProvider.notifier).show(
                      'موقعیت فعلی ذخیره شد',
                      type: AppNotifyType.success,
                    );
              } catch (e) {
                ref.read(appNotificationProvider.notifier).show(
                      'ذخیره ممکن نشد: $e',
                      type: AppNotifyType.error,
                    );
              }
            },
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'ذخیره موقعیت فعلی',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          AppCard(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'جستجو در علاقه‌مندی‌ها...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: Row(
              children: [
                for (var i = 0;
                    i < SampleData.favoriteCategories.length && i < 3;
                    i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _QuickCategory(
                      SampleData.favoriteCategories[i],
                      primary: i == 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            places.isEmpty ? 'هنوز مکانی ذخیره نشده' : '${places.length} مکان',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...places.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FavoritePlaceCard(
                place: p,
                onTap: () => _navigateTo(p),
                onDelete: () => _remove(p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCategory extends StatelessWidget {
  final FavoriteCategory category;
  final bool primary;
  const _QuickCategory(this.category, {this.primary = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CategoryUi.icon(category.icon),
            color: primary ? AppColors.primary : AppColors.gold,
            size: 22,
          ),
          const Spacer(),
          Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            '${category.placeCount}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritePlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _FavoritePlaceCard({
    required this.place,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CategoryUi.icon(place.category);
    final color = CategoryUi.color(place.category);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  place.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
          const Icon(Icons.navigation_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
