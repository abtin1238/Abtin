/// فهرست بسته‌های گراف آفلاین قابل بارگذاری.
class OfflineGraphPackage {
  final String id;
  final String nameFa;
  final String assetPath;
  final String? poiAssetPath;
  final double centerLat;
  final double centerLon;

  const OfflineGraphPackage({
    required this.id,
    required this.nameFa,
    required this.assetPath,
    this.poiAssetPath,
    required this.centerLat,
    required this.centerLon,
  });
}

/// رجیستری گراف‌های bundled (تهران متراکم + استان‌ها).
class GraphRegistry {
  static const packages = <OfflineGraphPackage>[
    // پیش‌فرض: تهران متراکم v2
    OfflineGraphPackage(
      id: 'tehran-metro-v2',
      nameFa: 'تهران (گراف متراکم v2)',
      assetPath: 'assets/maps/tehran_sample_graph.json',
      poiAssetPath: 'assets/maps/tehran_sample_pois.json',
      centerLat: 35.7219,
      centerLon: 51.4056,
    ),
    OfflineGraphPackage(
      id: 'ir_tehran',
      nameFa: 'تهران (استانی)',
      assetPath: 'assets/maps/ir_tehran_graph.json',
      poiAssetPath: 'assets/maps/ir_tehran_pois.json',
      centerLat: 35.70,
      centerLon: 51.45,
    ),
    OfflineGraphPackage(
      id: 'ir_alborz',
      nameFa: 'البرز',
      assetPath: 'assets/maps/ir_alborz_graph.json',
      poiAssetPath: 'assets/maps/ir_alborz_pois.json',
      centerLat: 36.00,
      centerLon: 50.80,
    ),
    OfflineGraphPackage(
      id: 'ir_isfahan',
      nameFa: 'اصفهان',
      assetPath: 'assets/maps/ir_isfahan_graph.json',
      poiAssetPath: 'assets/maps/ir_isfahan_pois.json',
      centerLat: 32.65,
      centerLon: 51.70,
    ),
    OfflineGraphPackage(
      id: 'ir_fars',
      nameFa: 'فارس',
      assetPath: 'assets/maps/ir_fars_graph.json',
      poiAssetPath: 'assets/maps/ir_fars_pois.json',
      centerLat: 29.65,
      centerLon: 52.55,
    ),
    OfflineGraphPackage(
      id: 'ir_khorasan_razavi',
      nameFa: 'خراسان رضوی',
      assetPath: 'assets/maps/ir_khorasan_razavi_graph.json',
      poiAssetPath: 'assets/maps/ir_khorasan_razavi_pois.json',
      centerLat: 36.30,
      centerLon: 59.55,
    ),
    OfflineGraphPackage(
      id: 'ir_azarbaijan_sharghi',
      nameFa: 'آذربایجان شرقی',
      assetPath: 'assets/maps/ir_azarbaijan_sharghi_graph.json',
      poiAssetPath: 'assets/maps/ir_azarbaijan_sharghi_pois.json',
      centerLat: 38.10,
      centerLon: 46.30,
    ),
    OfflineGraphPackage(
      id: 'ir_gilan',
      nameFa: 'گیلان',
      assetPath: 'assets/maps/ir_gilan_graph.json',
      poiAssetPath: 'assets/maps/ir_gilan_pois.json',
      centerLat: 37.30,
      centerLon: 49.60,
    ),
    OfflineGraphPackage(
      id: 'ir_mazandaran',
      nameFa: 'مازندران',
      assetPath: 'assets/maps/ir_mazandaran_graph.json',
      poiAssetPath: 'assets/maps/ir_mazandaran_pois.json',
      centerLat: 36.60,
      centerLon: 52.50,
    ),
    OfflineGraphPackage(
      id: 'ir_khuzestan',
      nameFa: 'خوزستان',
      assetPath: 'assets/maps/ir_khuzestan_graph.json',
      poiAssetPath: 'assets/maps/ir_khuzestan_pois.json',
      centerLat: 31.35,
      centerLon: 48.70,
    ),
    OfflineGraphPackage(
      id: 'ir_kerman',
      nameFa: 'کرمان',
      assetPath: 'assets/maps/ir_kerman_graph.json',
      poiAssetPath: 'assets/maps/ir_kerman_pois.json',
      centerLat: 30.32,
      centerLon: 57.05,
    ),
    OfflineGraphPackage(
      id: 'ir_qom',
      nameFa: 'قم',
      assetPath: 'assets/maps/ir_qom_graph.json',
      poiAssetPath: 'assets/maps/ir_qom_pois.json',
      centerLat: 34.65,
      centerLon: 50.88,
    ),
    OfflineGraphPackage(
      id: 'ir_yazd',
      nameFa: 'یزد',
      assetPath: 'assets/maps/ir_yazd_graph.json',
      poiAssetPath: 'assets/maps/ir_yazd_pois.json',
      centerLat: 31.90,
      centerLon: 54.37,
    ),
  ];

  static OfflineGraphPackage get defaultPackage => packages.first;

  static OfflineGraphPackage? byId(String id) {
    for (final p in packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<OfflineGraphPackage> get provinces =>
      packages.where((p) => p.id.startsWith('ir_')).toList();
}
