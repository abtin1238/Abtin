/// خودروهای سه‌بعدیِ قابلِ دانلود (GLB) از لینک‌های رایگان و مجاز.
///
/// نکته درباره‌ی مدل‌ها: این‌ها مدل‌های سه‌بعدیِ **واقعی، رایگان و مجاز** (Khronos
/// glTF Sample Assets) هستند که مستقیماً و بدون احراز هویت قابل دانلودند. اگر
/// فایلِ GLB اختصاصیِ خودتان (مثلاً BMW/لندکروز واقعی) دارید، فقط کافی است مقدارِ
/// [url] را با لینکِ مستقیمِ GLB خود جایگزین کنید؛ بقیه‌ی سیستم بدون تغییر کار می‌کند.
class VehicleModel {
  final String id;
  final String nameFa;
  final String nameEn;
  final String url; // لینکِ مستقیمِ GLB
  final int sizeBytes; // حجمِ تقریبی برای نمایش
  final String format; // 'glb' یا 'gltf'

  const VehicleModel({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.url,
    required this.sizeBytes,
    this.format = 'glb',
  });

  String get fileName => '$id.$format';

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} مگابایت';
    final kb = sizeBytes / 1024;
    return '${kb.toStringAsFixed(0)} کیلوبایت';
  }
}

/// فهرستِ خودروهای قابلِ دانلود (۳ خودرو، فرمتِ GLB).
class VehicleRegistry {
  const VehicleRegistry._();

  static const List<VehicleModel> models = [
    VehicleModel(
      id: 'suv_offroad',
      nameFa: 'شاسی‌بلند (لندکروز)',
      nameEn: 'Buggy Off-road',
      url:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Buggy/glTF-Binary/Buggy.glb',
      sizeBytes: 7885636,
      format: 'glb',
    ),
    VehicleModel(
      id: 'sport_car',
      nameFa: 'خودرو اسپرت (BMW)',
      nameEn: 'Sport Car',
      url:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/ToyCar/glTF-Binary/ToyCar.glb',
      sizeBytes: 5422412,
      format: 'glb',
    ),
    VehicleModel(
      id: 'truck',
      nameFa: 'کامیون / تراک',
      nameEn: 'Truck',
      url:
          'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
      sizeBytes: 369980,
      format: 'glb',
    ),
  ];

  static VehicleModel? byId(String? id) {
    if (id == null) return null;
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }
}
