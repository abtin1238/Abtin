import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../navigation/domain/entities/place.dart';

/// جستجوی کاملاً آفلاین روی POIهای بسته‌شده (تهران + استان‌ها).
class OfflineSearchService {
  OfflineSearchService();

  List<Place>? _cache;

  static const _poiAssets = <String>[
    'assets/maps/tehran_sample_pois.json',
    'assets/maps/ir_tehran_pois.json',
    'assets/maps/ir_alborz_pois.json',
    'assets/maps/ir_isfahan_pois.json',
    'assets/maps/ir_fars_pois.json',
    'assets/maps/ir_khorasan_razavi_pois.json',
    'assets/maps/ir_azarbaijan_sharghi_pois.json',
    'assets/maps/ir_gilan_pois.json',
    'assets/maps/ir_mazandaran_pois.json',
    'assets/maps/ir_khuzestan_pois.json',
    'assets/maps/ir_kerman_pois.json',
    'assets/maps/ir_qom_pois.json',
    'assets/maps/ir_yazd_pois.json',
  ];

  Future<List<Place>> _load() async {
    if (_cache != null) return _cache!;
    final all = <Place>[];
    final seen = <String>{};
    for (final asset in _poiAssets) {
      try {
        final raw = await rootBundle.loadString(asset);
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final id = m['id'] as String;
          if (!seen.add(id)) continue;
          all.add(Place(
            id: id,
            title: m['title'] as String,
            subtitle: (m['subtitle'] as String?) ?? '',
            location: LatLng(
              (m['lat'] as num).toDouble(),
              (m['lon'] as num).toDouble(),
            ),
            category: _cat(m['cat'] as String?),
          ));
        }
      } catch (_) {}
    }
    _cache = all;
    return _cache!;
  }

  PlaceCategory _cat(String? c) {
    switch (c) {
      case 'restaurant':
        return PlaceCategory.restaurant;
      case 'cafe':
        return PlaceCategory.cafe;
      case 'shopping':
        return PlaceCategory.shopping;
      case 'hotel':
        return PlaceCategory.hotel;
      case 'park':
        return PlaceCategory.park;
      case 'fuel':
        return PlaceCategory.fuel;
      case 'parking':
        return PlaceCategory.parking;
      case 'hospital':
        return PlaceCategory.hospital;
      case 'pharmacy':
        return PlaceCategory.pharmacy;
      case 'bank':
        return PlaceCategory.bank;
      case 'evCharge':
        return PlaceCategory.evCharge;
      case 'travel':
        return PlaceCategory.travel;
      default:
        return PlaceCategory.other;
    }
  }

  Future<List<Place>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final all = await _load();
    final lower = q.toLowerCase();
    final dist = const Distance();
    final hits = all.where((p) {
      return p.title.toLowerCase().contains(lower) ||
          p.subtitle.toLowerCase().contains(lower) ||
          p.category.name.toLowerCase().contains(lower);
    }).map((p) {
      if (near == null) return p;
      final km = dist.as(LengthUnit.Kilometer, near, p.location);
      return Place(
        id: p.id,
        title: p.title,
        subtitle: p.subtitle,
        location: p.location,
        category: p.category,
        distanceKm: km,
        isFavorite: p.isFavorite,
      );
    }).toList();
    if (near != null) {
      hits.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    }
    return hits;
  }

  Future<List<Place>> byCategory(PlaceCategory cat, {LatLng? near}) async {
    final all = await _load();
    final dist = const Distance();
    final hits = all.where((p) => p.category == cat).map((p) {
      if (near == null) return p;
      final km = dist.as(LengthUnit.Kilometer, near, p.location);
      return Place(
        id: p.id,
        title: p.title,
        subtitle: p.subtitle,
        location: p.location,
        category: p.category,
        distanceKm: km,
      );
    }).toList();
    if (near != null) {
      hits.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    }
    return hits;
  }

  Future<List<Place>> allPois() => _load();
}
