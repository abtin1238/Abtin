import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/category_ui.dart';
import '../../../../core/widgets/app_notification_banner.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../navigation/data/navigation_controller.dart';
import '../../../navigation/data/sample_data.dart';
import '../../../navigation/domain/entities/place.dart';
import '../../../navigation/domain/entities/route_info.dart';

/// صفحه‌ی «مسیرها» — جستجوی مقصدِ **زنده روی نقشه‌ی آنلاین** و پیش‌نمایشِ
/// پیش‌نمایش مسیر آفلاین (مسافت/زمان از A* / نیتیو) پیش از آغاز ناوبری.
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _token = 0;
  List<Place> _suggestions = [];
  bool _searching = false;

  Place? _selectedPlace;
  RouteInfo? _previewRoute;
  bool _loadingPreview = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    setState(() {
      _selectedPlace = null;
      _previewRoute = null;
    });
    if (q.trim().isEmpty) {
      setState(() {
        _searching = false;
        _suggestions = [];
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    final token = ++_token;
    try {
      final nav = ref.read(navigationControllerProvider);
      final geocoding = ref.read(geocodingServiceProvider);
      final results = await geocoding.search(q, near: nav.position ?? defaultMapCenter);
      if (!mounted || token != _token) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (!mounted || token != _token) return;
      ref.read(appNotificationProvider.notifier).show(
            'خطا در جستجوی آنلاین — اتصال اینترنت را بررسی کنید',
            type: AppNotifyType.error,
          );
    }
  }

  Future<void> _selectSuggestion(Place place) async {
    setState(() {
      _selectedPlace = place;
      _searching = false;
      _suggestions = [];
      _loadingPreview = true;
      _previewRoute = null;
    });
    _controller.text = place.title;
    try {
      final nav = ref.read(navigationControllerProvider);
      final origin = nav.position ?? defaultMapCenter;
      final routingService = ref.read(routingServiceProvider);
      final route = await routingService.route(origin, place.location);
      if (!mounted) return;
      setState(() {
        _previewRoute = route;
        _loadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPreview = false);
      ref.read(appNotificationProvider.notifier).show(
            'محاسبه‌ی مسیر برای این مقصد ممکن نشد',
            type: AppNotifyType.error,
          );
    }
  }

  void _startNavigation() {
    final route = _previewRoute;
    if (route == null) return;
    final ok =
        ref.read(navigationControllerProvider.notifier).startRoute(route);
    if (ok) {
      ref.read(bottomNavIndexProvider.notifier).state = 0;
      ref.read(appNotificationProvider.notifier).show(
            'ناوبری آغاز شد',
            type: AppNotifyType.success,
          );
    } else {
      ref.read(appNotificationProvider.notifier).show(
            'شروعِ ناوبری ممکن نشد',
            type: AppNotifyType.error,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.routesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _searchBar(),
          if (_searching) ..._buildSuggestions(),
          if (!_searching && _selectedPlace == null) ..._buildRecent(),
          if (_selectedPlace != null) _buildPreview(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'جستجوی مقصد...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.primary),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSuggestions() {
    return [
      const SectionHeader('نتایج جستجو'),
      ..._suggestions.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _selectSuggestion(p),
              child: Row(
                children: [
                  GlowIcon(CategoryUi.icon(p.category),
                      color: CategoryUi.color(p.category), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(p.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondaryDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
      if (_suggestions.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('نتیجه‌ای یافت نشد',
                style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
        ),
    ];
  }

  List<Widget> _buildRecent() {
    return [
      const SectionHeader('آخرین مقاصد'),
      ...SampleData.recentSearches.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _selectSuggestion(p),
              child: Row(
                children: [
                  GlowIcon(CategoryUi.icon(p.category),
                      color: CategoryUi.color(p.category), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.textMutedDark),
                ],
              ),
            ),
          )),
    ];
  }

  Widget _buildPreview() {
    if (_loadingPreview) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final route = _previewRoute;
    if (route == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('مسیرِ پیشنهادی'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('سریع‌ترین مسیر',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                      icon: Icons.route_rounded, label: route.distanceLabel),
                  const SizedBox(width: 10),
                  _StatChip(
                      icon: Icons.schedule_rounded, label: route.durationLabel),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navSelected,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('شروع مسیریابی',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
