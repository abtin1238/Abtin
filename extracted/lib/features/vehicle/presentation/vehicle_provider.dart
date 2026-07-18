import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VehicleType { arrow, bmwI8 }

/// انتخاب خودروی کاربر. طبق درخواست: پیش‌فرض = پیکان ساده.
/// اگر کاربر مدل GLB را انتخاب کند، فعلاً (تا پیاده‌سازی لایه Native سه‌بعدی
/// در فاز بعد) یک آیکون دوبعدی جایگزین نمایش داده می‌شود — رندر واقعی glTF
/// روی نقشه نیاز به لایه Native (Filament/SceneView) دارد که در این فاز
/// پیاده‌سازی نشده. این طراحی به‌گونه‌ای است که وقتی آن لایه اضافه شود، فقط
/// کافی‌ست ویجت مارکر جایگزین شود — بقیه‌ی state/UI بدون تغییر می‌ماند.
final selectedVehicleProvider = StateProvider<VehicleType>((ref) => VehicleType.arrow);
