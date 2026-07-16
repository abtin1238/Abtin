import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/offline_map_download_service.dart';
import '../../../../core/theme/app_colors.dart';

/// نمای نقشه‌ی **آنلاینِ واقعی** (OpenStreetMap) — جایگزینِ کاملِ نقشه‌ی
/// برداریِ فیکِ قبلی. نقشه‌ی زنده و داینامیک است؛ هیچ داده‌ای از پیش
/// ساخته/فیک روی آن رندر نمی‌شود.
///
/// طبقِ درخواست: انتخابِ مقصد روی نقشه فقط با **لمسِ طولانی** انجام می‌شود؛
/// لمسِ ساده هیچ کنشی ندارد (برای جلوگیری از مسیریابیِ ناخواسته).
class OnlineMapView extends StatefulWidget {
  final LatLng camera;
  final double zoom;
  final double headingDeg;
  final List<LatLng> routePolyline;
  final LatLng? destination;
  final Color routeColor;
  final bool isDark;
  final Widget? vehicle;
  final bool followCamera;
  final ValueChanged<LatLng> onLongPressLatLng;
  final MapController? controller;
  final OfflineMapDownloadService? offlineService;

  const OnlineMapView({
    super.key,
    required this.camera,
    required this.onLongPressLatLng,
    this.zoom = 16,
    this.headingDeg = 0,
    this.routePolyline = const [],
    this.destination,
    this.routeColor = AppColors.primary,
    this.isDark = true,
    this.vehicle,
    this.followCamera = false,
    this.controller,
    this.offlineService,
  });

  @override
  State<OnlineMapView> createState() => _OnlineMapViewState();
}

class _OnlineMapViewState extends State<OnlineMapView> {
  late final MapController _controller = widget.controller ?? MapController();
  TileProvider? _offlineTileProvider;
  bool _providerReady = false;

  @override
  void initState() {
    super.initState();
    _loadTileProvider();
  }

  Future<void> _loadTileProvider() async {
    final service = widget.offlineService;
    if (service == null) {
      setState(() => _providerReady = true);
      return;
    }
    try {
      final provider = await service.tileProviderForMap();
      if (!mounted) return;
      setState(() {
        _offlineTileProvider = provider;
        _providerReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _providerReady = true);
    }
  }

  @override
  void didUpdateWidget(covariant OnlineMapView old) {
    super.didUpdateWidget(old);
    if (widget.followCamera &&
        (old.camera != widget.camera || old.headingDeg != widget.headingDeg)) {
      // نقشه در حینِ ناوبری به‌صورت زنده روی خودرو قفل می‌ماند.
      try {
        _controller.moveAndRotate(widget.camera, widget.zoom, -widget.headingDeg);
      } catch (_) {
        // نقشه هنوز آماده نیست (اولین فریم) — نادیده گرفته می‌شود.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.camera,
            initialZoom: widget.zoom,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onLongPress: (tapPos, point) => widget.onLongPressLatLng(point),
          ),
          children: [
            TileLayer(
              urlTemplate: widget.isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.abtin.navigator',
              maxZoom: 19,
              tileProvider: _providerReady && _offlineTileProvider != null
                  ? _offlineTileProvider!
                  : NetworkTileProvider(),
            ),
            if (widget.routePolyline.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePolyline,
                    strokeWidth: 6,
                    color: widget.routeColor,
                    borderStrokeWidth: 2,
                    borderColor: Colors.black.withOpacity(0.35),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.destination != null)
                  Marker(
                    point: widget.destination!,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.danger,
                      size: 40,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                if (widget.vehicle != null)
                  Marker(
                    point: widget.camera,
                    width: 70,
                    height: 70,
                    child: widget.vehicle!,
                  ),
              ],
            ),
          ],
        ),
        // ---- اسنادِ منبعِ نقشه (الزامیِ OpenStreetMap) ----
        Positioned(
          left: 8,
          bottom: 4,
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              fontSize: 9,
              color: (widget.isDark ? Colors.white : Colors.black)
                  .withOpacity(0.45),
            ),
          ),
        ),
      ],
    );
  }
}
