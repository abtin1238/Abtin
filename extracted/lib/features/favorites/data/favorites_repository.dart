import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';
import '../../navigation/domain/entities/place.dart';

/// مخزن علاقه‌مندی‌ها (Repository Pattern) روی SQLite رمزنگاری‌شده.
class FavoritesRepository {
  FavoritesRepository(this._db);
  final AppDatabase _db;

  List<Place> getAll() {
    return _db.allFavorites().map(_toPlace).toList();
  }

  void add(Place place) {
    _db.upsertFavorite(
      id: place.id,
      title: place.title,
      subtitle: place.subtitle,
      lat: place.location.latitude,
      lon: place.location.longitude,
      category: place.category.name,
    );
  }

  void remove(String id) => _db.deleteFavorite(id);

  bool isFavorite(String id) =>
      _db.allFavorites().any((f) => f.id == id);

  Place _toPlace(FavoriteRow r) {
    return Place(
      id: r.id,
      title: r.title,
      subtitle: r.subtitle,
      location: LatLng(r.lat, r.lon),
      category: _parseCat(r.category),
      isFavorite: true,
    );
  }

  PlaceCategory _parseCat(String name) {
    return PlaceCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PlaceCategory.other,
    );
  }
}
