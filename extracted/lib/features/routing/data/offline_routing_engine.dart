import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../navigation/domain/entities/route_info.dart';

/// گره‌ی گراف جاده‌ای (هر تقاطع/نقطه).
class GraphNode {
  final int id;
  final LatLng position;
  const GraphNode(this.id, this.position);
}

/// یال گراف (بخش جاده) با هزینه‌ی حرکت.
class GraphEdge {
  final int to;
  final double distanceMeters;
  final double speedKmh; // سرعت مجاز برای محاسبه‌ی زمان
  final Set<TravelMode> allowedModes;
  const GraphEdge({
    required this.to,
    required this.distanceMeters,
    required this.speedKmh,
    required this.allowedModes,
  });
}

/// موتور مسیریابی کاملاً آفلاین مبتنی بر A*.
///
/// این یک پیاده‌سازی واقعی الگوریتم A* روی گراف جاده‌ای محلی است. گراف را
/// می‌توان از فایل‌های OSM/MBTiles استخراج و در SQLite ذخیره کرد؛ اینجا رابط
/// بارگذاری گراف فراهم است. هیچ ارتباط شبکه‌ای لازم نیست.
class OfflineRoutingEngine {
  final Map<int, GraphNode> _nodes = {};
  final Map<int, List<GraphEdge>> _adjacency = {};

  bool get isLoaded => _nodes.isNotEmpty;
  int get nodeCount => _nodes.length;

  /// بارگذاری گراف در حافظه (از دیتابیس محلی/فایل استخراج‌شده).
  void loadGraph(List<GraphNode> nodes, Map<int, List<GraphEdge>> edges) {
    _nodes.clear();
    _adjacency.clear();
    for (final n in nodes) {
      _nodes[n.id] = n;
    }
    _adjacency.addAll(edges);
  }

  final Distance _distance = const Distance();

  /// نزدیک‌ترین گره‌ی گراف به یک مختصات (Snap-to-road ساده).
  int? _nearestNode(LatLng p) {
    int? best;
    double bestD = double.infinity;
    for (final n in _nodes.values) {
      final d = _distance.as(LengthUnit.Meter, p, n.position);
      if (d < bestD) {
        bestD = d;
        best = n.id;
      }
    }
    return best;
  }

  double _heuristic(int a, int b, double maxSpeedKmh) {
    final d = _distance.as(
        LengthUnit.Meter, _nodes[a]!.position, _nodes[b]!.position);
    return _cost(d, maxSpeedKmh, RoutePreference.fastest);
  }

  double _cost(double meters, double speedKmh, RoutePreference pref) {
    switch (pref) {
      case RoutePreference.shortest:
        return meters;
      case RoutePreference.economic:
        // جریمه‌ی سرعت بالا/پایین برای مصرف بهینه.
        final penalty = (speedKmh - 60).abs() / 60.0;
        return meters * (1 + 0.3 * penalty);
      case RoutePreference.fastest:
        final mps = (speedKmh <= 0 ? 5 : speedKmh) * 1000 / 3600;
        return meters / mps; // زمان بر حسب ثانیه
    }
  }

  /// محاسبه‌ی مسیر بین دو مختصات با A*.
  RouteInfo? calculateRoute(
    LatLng origin,
    LatLng destination, {
    TravelMode mode = TravelMode.car,
    RoutePreference preference = RoutePreference.fastest,
  }) {
    if (!isLoaded) return null;
    final start = _nearestNode(origin);
    final goal = _nearestNode(destination);
    if (start == null || goal == null) return null;

    const maxSpeed = 120.0;
    final open = _PriorityQueue();
    final gScore = <int, double>{start: 0};
    final cameFrom = <int, int>{};
    open.add(_PqItem(start, _heuristic(start, goal, maxSpeed)));

    final closed = <int>{};
    while (!open.isEmpty) {
      final current = open.removeMin().node;
      if (current == goal) {
        return _reconstruct(cameFrom, current, start, mode, preference);
      }
      if (!closed.add(current)) continue;

      for (final edge in _adjacency[current] ?? const <GraphEdge>[]) {
        if (!edge.allowedModes.contains(mode)) continue;
        final tentative = (gScore[current] ?? double.infinity) +
            _cost(edge.distanceMeters, edge.speedKmh, preference);
        if (tentative < (gScore[edge.to] ?? double.infinity)) {
          cameFrom[edge.to] = current;
          gScore[edge.to] = tentative;
          final f = tentative + _heuristic(edge.to, goal, maxSpeed);
          open.add(_PqItem(edge.to, f));
        }
      }
    }
    return null; // مسیری یافت نشد
  }

  RouteInfo _reconstruct(Map<int, int> cameFrom, int current, int start,
      TravelMode mode, RoutePreference pref) {
    final path = <int>[current];
    while (current != start) {
      current = cameFrom[current]!;
      path.add(current);
    }
    final ordered = path.reversed.toList();

    final polyline = <LatLng>[];
    double totalMeters = 0;
    double totalSeconds = 0;
    final steps = <ManeuverStep>[];

    for (var i = 0; i < ordered.length; i++) {
      final node = _nodes[ordered[i]]!;
      polyline.add(node.position);
      if (i > 0) {
        final prev = _nodes[ordered[i - 1]]!;
        final seg = _distance.as(LengthUnit.Meter, prev.position, node.position);
        totalMeters += seg;
        final edge = (_adjacency[ordered[i - 1]] ?? [])
            .firstWhere((e) => e.to == ordered[i],
                orElse: () => GraphEdge(
                    to: ordered[i],
                    distanceMeters: seg,
                    speedKmh: 50,
                    allowedModes: {mode}));
        totalSeconds += seg / (edge.speedKmh * 1000 / 3600);
      }
    }

    // ساخت دستورهای مانور از تغییر زاویه بین بخش‌ها.
    for (var i = 1; i < polyline.length - 1; i++) {
      final type = _maneuverBetween(polyline[i - 1], polyline[i], polyline[i + 1]);
      if (type != ManeuverType.straight) {
        steps.add(ManeuverStep(
          instruction: _instructionText(type),
          distanceMeters:
              _distance.as(LengthUnit.Meter, polyline[i - 1], polyline[i]),
          type: type,
          point: polyline[i],
        ));
      }
    }
    steps.add(ManeuverStep(
      instruction: 'به مقصد رسیدید',
      distanceMeters: 0,
      type: ManeuverType.arrive,
      point: polyline.last,
    ));

    return RouteInfo(
      polyline: polyline,
      steps: steps,
      distanceMeters: totalMeters,
      duration: Duration(seconds: totalSeconds.round()),
      mode: mode,
      preference: pref,
    );
  }

  ManeuverType _maneuverBetween(LatLng a, LatLng b, LatLng c) {
    final b1 = _bearing(a, b);
    final b2 = _bearing(b, c);
    var diff = (b2 - b1 + 540) % 360 - 180; // -180..180
    if (diff > 40) return ManeuverType.turnRight;
    if (diff > 15) return ManeuverType.slightRight;
    if (diff < -40) return ManeuverType.turnLeft;
    if (diff < -15) return ManeuverType.slightLeft;
    return ManeuverType.straight;
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad, lat2 = b.latitudeInRad;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  String _instructionText(ManeuverType t) {
    switch (t) {
      case ManeuverType.turnRight:
        return 'به راست بپیچید';
      case ManeuverType.turnLeft:
        return 'به چپ بپیچید';
      case ManeuverType.slightRight:
        return 'کمی به راست';
      case ManeuverType.slightLeft:
        return 'کمی به چپ';
      case ManeuverType.uTurn:
        return 'دور بزنید';
      case ManeuverType.roundabout:
        return 'وارد میدان شوید';
      case ManeuverType.arrive:
        return 'به مقصد رسیدید';
      case ManeuverType.depart:
        return 'حرکت کنید';
      case ManeuverType.straight:
        return 'مستقیم ادامه دهید';
    }
  }
}

// ---- Min-heap priority queue for A* ----
class _PqItem {
  final int node;
  final double priority;
  const _PqItem(this.node, this.priority);
}

class _PriorityQueue {
  final List<_PqItem> _heap = [];
  bool get isEmpty => _heap.isEmpty;

  void add(_PqItem item) {
    _heap.add(item);
    var i = _heap.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_heap[parent].priority <= _heap[i].priority) break;
      final tmp = _heap[parent];
      _heap[parent] = _heap[i];
      _heap[i] = tmp;
      i = parent;
    }
  }

  _PqItem removeMin() {
    final min = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var smallest = i;
        if (l < _heap.length &&
            _heap[l].priority < _heap[smallest].priority) smallest = l;
        if (r < _heap.length &&
            _heap[r].priority < _heap[smallest].priority) smallest = r;
        if (smallest == i) break;
        final tmp = _heap[smallest];
        _heap[smallest] = _heap[i];
        _heap[i] = tmp;
        i = smallest;
      }
    }
    return min;
  }
}
