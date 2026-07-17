import 'package:latlong2/latlong.dart';
import '../domain/entities/place.dart';

/// داده‌های نمونه‌ی محلی (بذر اولیه‌ی SQLite) مطابق تصاویر مرجع.
/// Seed data mirroring the reference screenshots (Tehran POIs & favorites).
class SampleData {
  SampleData._();

  static const LatLng tehran = LatLng(35.7219, 51.3347);

  /// مکان‌های پیشنهادی نزدیک (صفحه‌ی جستجو).
  static const List<Place> nearbyPlaces = [
    Place(
      id: 'p1',
      title: 'کافه رستوران ایوان',
      subtitle: 'ولنجک، خیابان افشار',
      location: LatLng(35.8060, 51.4090),
      category: PlaceCategory.cafe,
      distanceKm: 1.2,
    ),
    Place(
      id: 'p2',
      title: 'مرکز خرید ارگ تجریش',
      subtitle: 'تجریش، خیابان ولیعصر',
      location: LatLng(35.8046, 51.4265),
      category: PlaceCategory.shopping,
      distanceKm: 1.8,
    ),
    Place(
      id: 'p3',
      title: 'پارک ملت',
      subtitle: 'تهران، خیابان اسفندیار',
      location: LatLng(35.7776, 51.4103),
      category: PlaceCategory.park,
      distanceKm: 2.3,
    ),
    Place(
      id: 'p4',
      title: 'پمپ بنزین جایگاه ۱۵۴',
      subtitle: 'نیایش، بزرگراه شهید همت',
      location: LatLng(35.7590, 51.3890),
      category: PlaceCategory.fuel,
      distanceKm: 2.7,
    ),
  ];

  /// نتایج جستجوی «برج میلاد» (صفحه‌ی نتایج).
  static const List<Place> miladResults = [
    Place(
      id: 'm1',
      title: 'برج میلاد تهران',
      subtitle: 'تهران، بزرگراه شهید همت، برج میلاد',
      location: LatLng(35.7448, 51.3753),
      category: PlaceCategory.other,
      distanceKm: 4.8,
    ),
    Place(
      id: 'm2',
      title: 'رستوران گردان برج میلاد',
      subtitle: 'تهران، برج میلاد، طبقه ۷',
      location: LatLng(35.7448, 51.3753),
      category: PlaceCategory.restaurant,
      distanceKm: 4.8,
    ),
    Place(
      id: 'm3',
      title: 'پارکینگ برج میلاد',
      subtitle: 'تهران، برج میلاد',
      location: LatLng(35.7445, 51.3760),
      category: PlaceCategory.parking,
      distanceKm: 4.7,
    ),
    Place(
      id: 'm4',
      title: 'هتل برج میلاد',
      subtitle: 'تهران، بزرگراه شهید همت',
      location: LatLng(35.7440, 51.3770),
      category: PlaceCategory.hotel,
      distanceKm: 4.9,
    ),
  ];

  /// جستجوهای اخیر.
  static const List<Place> recentSearches = [
    Place(
        id: 'r1',
        title: 'تجریش، تهران',
        subtitle: 'تهران، ایران',
        location: LatLng(35.8046, 51.4265)),
    Place(
        id: 'r2',
        title: 'فرودگاه بین‌المللی امام خمینی',
        subtitle: 'تهران، ایران',
        location: LatLng(35.4161, 51.1522)),
    Place(
        id: 'r3',
        title: 'بام لند',
        subtitle: 'تهران، بزرگراه شهید همت',
        location: LatLng(35.7930, 51.3120)),
  ];

  /// دسته‌های علاقه‌مندی (صفحه‌ی علاقه‌مندی‌ها).
  static const List<FavoriteCategory> favoriteCategories = [
    FavoriteCategory(id: 'c1', name: 'خانه', icon: PlaceCategory.home, placeCount: 3),
    FavoriteCategory(id: 'c2', name: 'محل کار', icon: PlaceCategory.work, placeCount: 2),
    FavoriteCategory(id: 'c3', name: 'خانواده', icon: PlaceCategory.family, placeCount: 4),
    FavoriteCategory(id: 'c4', name: 'دوستان', icon: PlaceCategory.friends, placeCount: 3),
    FavoriteCategory(id: 'c5', name: 'سفر و تفریح', icon: PlaceCategory.travel, placeCount: 6),
    FavoriteCategory(id: 'c6', name: 'سایر', icon: PlaceCategory.other, placeCount: 12),
  ];

  /// مکان‌های علاقه‌مندی ذخیره‌شده.
  static const List<Place> favoritePlaces = [
    Place(
        id: 'f1',
        title: 'خانه',
        subtitle: 'تهران، خیابان ولیعصر، پلاک ۲۴',
        location: LatLng(35.7550, 51.4100),
        category: PlaceCategory.home,
        isFavorite: true),
    Place(
        id: 'f2',
        title: 'ویلا شمال',
        subtitle: 'مازندران، نوشهر، سیستگان',
        location: LatLng(36.6480, 51.4960),
        category: PlaceCategory.travel,
        isFavorite: true),
    Place(
        id: 'f3',
        title: 'خانه پدری',
        subtitle: 'اصفهان، خیابان آمادگاه، کوچه ۱۲',
        location: LatLng(32.6539, 51.6660),
        category: PlaceCategory.family,
        isFavorite: true),
  ];
}
