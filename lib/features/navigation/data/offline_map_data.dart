import 'package:latlong2/latlong.dart';

import '../../routing/data/offline_routing_engine.dart';
import '../domain/entities/route_info.dart';

/// یک بخش جاده (برای رندرِ برداریِ نقشه‌ی آفلاین).
/// [roadClass] 0 = شریانی (پهن) ، 1 = محلی (باریک).
class RoadSeg {
  final LatLng a;
  final LatLng b;
  final int roadClass;
  const RoadSeg(this.a, this.b, this.roadClass);
}

/// پیرامونِ (footprint) یک ساختمان + ارتفاع نسبی برای رندرِ سه‌بعدی.
class Building {
  final List<LatLng> footprint;
  final double height; // نسبی 0.4 .. 1.6
  const Building(this.footprint, this.height);
}

/// شهرِ آفلاین: گرافِ جاده‌ای (برای مسیریابی A*) + بخش‌های جاده و ساختمان‌ها
/// (برای رندرِ برداریِ نقشه). هیچ داده‌ای از شبکه گرفته نمی‌شود.
class OfflineCity {
  final List<GraphNode> nodes;
  final Map<int, List<GraphEdge>> adjacency;
  final List<RoadSeg> roads;
  final List<Building> buildings;
  final LatLng center;

  const OfflineCity({
    required this.nodes,
    required this.adjacency,
    required this.roads,
    required this.buildings,
    required this.center,
  });
}

// ---- پیکربندی گرید شهر (نمونه‌ی تهران) ----
const int _rows = 28;
const int _cols = 32;
const double _lat0 = 35.6600;
const double _lon0 = 51.3000;
const double _dLat = 0.0042; // ~460m
const double _dLon = 0.0048;

/// هَش قطعی برای تولیدِ پایدارِ جیتر/ساختمان (بدون تصادفی‌بودنِ اجرا‌به‌اجرا).
int _hash(int x) {
  x = (x ^ 61) ^ (x >> 16);
  x = x + (x << 3);
  x = x ^ (x >> 4);
  x = x * 0x27d4eb2d;
  x = x ^ (x >> 15);
  return x & 0x7fffffff;
}

double _jit(int id, double amp) => (((_hash(id) % 1000) / 1000.0) - 0.5) * amp;

bool _arterialRow(int r) => r % 4 == 0;
bool _arterialCol(int c) => c % 4 == 0;

const Set<TravelMode> _allModes = {
  TravelMode.car,
  TravelMode.truck,
  TravelMode.motorcycle,
  TravelMode.bicycle,
  TravelMode.pedestrian,
};

/// ساختِ شهرِ نمونه‌ی کاملاً آفلاین (گرید خیابانی با شریان‌ها، محلی‌ها و ساختمان‌ها).
OfflineCity buildTehranSampleCity() {
  const dist = Distance();
  final nodes = <GraphNode>[];
  final pos = <int, LatLng>{};

  for (var r = 0; r < _rows; r++) {
    for (var c = 0; c < _cols; c++) {
      final id = r * _cols + c;
      final ll = LatLng(
        _lat0 + r * _dLat + _jit(id, _dLat * 0.30),
        _lon0 + c * _dLon + _jit(id * 7 + 1, _dLon * 0.30),
      );
      pos[id] = ll;
      nodes.add(GraphNode(id, ll));
    }
  }

  final adj = <int, List<GraphEdge>>{};
  final roads = <RoadSeg>[];

  void addEdge(int a, int b, double speed) {
    final d = dist.as(LengthUnit.Meter, pos[a]!, pos[b]!);
    (adj[a] ??= []).add(GraphEdge(
        to: b, distanceMeters: d, speedKmh: speed, allowedModes: _allModes));
    (adj[b] ??= []).add(GraphEdge(
        to: a, distanceMeters: d, speedKmh: speed, allowedModes: _allModes));
  }

  for (var r = 0; r < _rows; r++) {
    for (var c = 0; c < _cols; c++) {
      final id = r * _cols + c;
      if (c < _cols - 1) {
        final rt = id + 1;
        final art = _arterialRow(r);
        addEdge(id, rt, art ? 55 : 30);
        roads.add(RoadSeg(pos[id]!, pos[rt]!, art ? 0 : 1));
      }
      if (r < _rows - 1) {
        final dn = id + _cols;
        final art = _arterialCol(c);
        addEdge(id, dn, art ? 55 : 30);
        roads.add(RoadSeg(pos[id]!, pos[dn]!, art ? 0 : 1));
      }
    }
  }

  // ---- ساختمان‌ها (درونِ هر بلوک، با درون‌رفتگی و ارتفاع قطعی) ----
  LatLng lerp2(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  final buildings = <Building>[];
  for (var r = 0; r < _rows - 1; r++) {
    for (var c = 0; c < _cols - 1; c++) {
      final id = r * _cols + c;
      final p00 = pos[id]!;
      final p10 = pos[id + 1]!;
      final p01 = pos[id + _cols]!;
      final p11 = pos[id + _cols + 1]!;

      LatLng bil(double u, double v) {
        final top = lerp2(p00, p10, u);
        final bot = lerp2(p01, p11, u);
        return lerp2(top, bot, v);
      }

      final h = _hash(id * 13 + 5);
      final count = (h % 3 == 0) ? 2 : 1;
      for (var k = 0; k < count; k++) {
        final hk = _hash(id * 31 + k * 17 + 3);
        final f0 = 0.20 + (hk % 18) / 100.0; // 0.20..0.38
        final f1 = 0.60 + ((hk >> 5) % 20) / 100.0; // 0.60..0.80
        final foot = <LatLng>[
          bil(f0, f0),
          bil(f1, f0),
          bil(f1, f1),
          bil(f0, f1),
        ];
        final height = 0.4 + (hk % 100) / 100.0 * 1.2; // 0.4..1.6
        buildings.add(Building(foot, height));
      }
    }
  }

  return OfflineCity(
    nodes: nodes,
    adjacency: adj,
    roads: roads,
    buildings: buildings,
    center: LatLng(_lat0 + (_rows / 2) * _dLat, _lon0 + (_cols / 2) * _dLon),
  );
}
