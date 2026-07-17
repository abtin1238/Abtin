import 'package:latlong2/latlong.dart';

/// دسته‌بندی مکان‌ها (POI) مطابق صفحه‌ی جستجو.
enum PlaceCategory {
  home,
  work,
  restaurant,
  cafe,
  shopping,
  hotel,
  park,
  fuel,
  parking,
  hospital,
  pharmacy,
  bank,
  evCharge,
  family,
  friends,
  travel,
  other,
}

/// موجودیت مکان — لایه‌ی دامنه (Clean Architecture).
class Place {
  final String id;
  final String title;
  final String subtitle;
  final LatLng location;
  final PlaceCategory category;
  final double? distanceKm;
  final bool isFavorite;

  const Place({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    this.category = PlaceCategory.other,
    this.distanceKm,
    this.isFavorite = false,
  });

  Place copyWith({bool? isFavorite}) => Place(
        id: id,
        title: title,
        subtitle: subtitle,
        location: location,
        category: category,
        distanceKm: distanceKm,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}

/// دسته‌ی علاقه‌مندی‌ها (خانه، محل کار، خانواده، ...).
class FavoriteCategory {
  final String id;
  final String name;
  final PlaceCategory icon;
  final int placeCount;

  const FavoriteCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.placeCount,
  });
}
