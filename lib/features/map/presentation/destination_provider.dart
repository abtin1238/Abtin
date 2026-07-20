import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// مقصد انتخاب‌شده — یا با لمس روی نقشه تنظیم می‌شود، یا از دیپ‌لینک ورودی.
/// موتور مسیریابی واقعی (Valhalla) در فاز بعد به این متصل می‌شود؛ فعلاً فقط
/// مارکر مقصد و کارت اطلاعات نمایش داده می‌شود.
class SelectedDestination {
  final LatLng point;
  final String? label;
  const SelectedDestination(this.point, {this.label});
}

final selectedDestinationProvider = StateProvider<SelectedDestination?>((ref) => null);
