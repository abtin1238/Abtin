import 'dart:math' as math;
import 'dart:typed_data';

/// یک یال جهت‌دار در گراف جاده‌ها (از یک گره به گره‌ی دیگر).
class RoadEdge {
  final int to; // اندیس گره‌ی مقصد
  final double distanceM; // طول یال به متر
  final int nameIndex; // اندیس نام خیابان در جدول رشته‌ها (-1 = بدون نام)

  const RoadEdge({required this.to, required this.distanceM, required this.nameIndex});
}

/// گراف جاده‌ها برای مسیریابی آفلاین — کاملاً در حافظه نگه‌داشته می‌شود.
///
/// این ساختار عمداً ساده و فشرده است (بدون هیچ وابستگی خارجی مثل sqlite)
/// چون هدف این است که خواندنش از دیسک سریع و بدون نیاز به build_runner/کد
/// تولیدی باشد. برای هر استان یک نمونه جدا از این گراف بارگذاری می‌شود.
class RoadGraph {
  final Float64List lats;
  final Float64List lngs;
  final List<List<RoadEdge>> adjacency; // adjacency[i] = یال‌های خروجی از گره i
  final List<String> roadNames;

  // ایندکس فضایی ساده (Grid) برای پیدا کردن نزدیک‌ترین گره به یک مختصات،
  // بدون نیاز به پیمایش خطی کل گراف در هر جست‌وجو.
  static const double _cellSizeDeg = 0.01; // حدود ۱ کیلومتر
  late final Map<int, List<int>> _grid = _buildGrid();

  RoadGraph({
    required this.lats,
    required this.lngs,
    required this.adjacency,
    required this.roadNames,
  });

  int get nodeCount => lats.length;

  int _cellKey(double lat, double lng) {
    final cx = (lng / _cellSizeDeg).floor();
    final cy = (lat / _cellSizeDeg).floor();
    // ترکیب دو مختصات شبکه در یک عدد صحیح یکتا (کافی برای محدوده‌ی مختصات ایران)
    return (cx + 100000) * 1000000 + (cy + 100000);
  }

  Map<int, List<int>> _buildGrid() {
    final map = <int, List<int>>{};
    for (var i = 0; i < lats.length; i++) {
      final key = _cellKey(lats[i], lngs[i]);
      map.putIfAbsent(key, () => []).add(i);
    }
    return map;
  }

  static double haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final la1 = lat1 * math.pi / 180;
    final la2 = lat2 * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// نزدیک‌ترین گره‌ی گراف به یک مختصات دلخواه (مثلاً موقعیت GPS کاربر یا
  /// مقصد انتخابی) را پیدا می‌کند. با گسترش تدریجی شعاع جست‌وجو در شبکه‌ی
  /// grid تا رسیدن به حداقل یک کاندید، سریع‌تر از پیمایش کل گراف است.
  /// اگر گراف در محدوده‌ی معقولی (پیش‌فرض ۲ کیلومتر) هیچ گره‌ای نداشته باشد
  /// null برمی‌گرداند (یعنی این استان/گراف برای این مختصات پوشش ندارد).
  int? nearestNode(double lat, double lng, {double maxRadiusM = 2000}) {
    if (lats.isEmpty) return null;
    final cx = (lng / _cellSizeDeg).floor();
    final cy = (lat / _cellSizeDeg).floor();
    final maxRing = (maxRadiusM / (_cellSizeDeg * 111000)).ceil() + 1;

    int? best;
    var bestDist = double.infinity;
    for (var ring = 0; ring <= maxRing; ring++) {
      for (var dx = -ring; dx <= ring; dx++) {
        for (var dy = -ring; dy <= ring; dy++) {
          if (ring > 0 && dx.abs() != ring && dy.abs() != ring) continue;
          final key = (cx + dx + 100000) * 1000000 + (cy + dy + 100000);
          final candidates = _grid[key];
          if (candidates == null) continue;
          for (final idx in candidates) {
            final d = haversineM(lat, lng, lats[idx], lngs[idx]);
            if (d < bestDist) {
              bestDist = d;
              best = idx;
            }
          }
        }
      }
      // اگر همین حالا یک کاندید پیدا کردیم و یک حلقه‌ی اضافه هم چک شد، کافی است
      if (best != null && bestDist <= ring * _cellSizeDeg * 111000) break;
    }
    if (best == null || bestDist > maxRadiusM) return null;
    return best;
  }

  // ===== سریالایز کردن به یک فایل باینری فشرده =====
  // فرمت: magic(4B) 'AOG1' | nodeCount(u32) | edgeCount(u32) | nameCount(u32)
  //       سپس nodeCount*[lat(f64) lng(f64)]
  //       سپس edgeCount*[from(u32) to(u32) dist(f32) nameIdx(i32)]
  //       سپس برای هر نام: len(u16) + utf8 bytes
  Uint8List encode() {
    final edges = <List<int>>[]; // [from, to] برای شمارش/نوشتن با دیتا جدا
    var edgeCount = 0;
    for (final list in adjacency) {
      edgeCount += list.length;
    }

    final nameBytes = roadNames.map((s) => s.codeUnits.isEmpty ? <int>[] : _utf8(s)).toList();
    var nameSection = 0;
    for (final b in nameBytes) {
      nameSection += 2 + b.length;
    }

    final headerSize = 4 + 4 + 4 + 4;
    final nodeSection = nodeCount * (8 + 8);
    final edgeSection = edgeCount * (4 + 4 + 4 + 4);
    final total = headerSize + nodeSection + edgeSection + nameSection;

    final buf = ByteData(total);
    var off = 0;
    buf.setUint8(off, 0x41); // 'A'
    buf.setUint8(off + 1, 0x4F); // 'O'
    buf.setUint8(off + 2, 0x47); // 'G'
    buf.setUint8(off + 3, 0x31); // '1'
    off += 4;
    buf.setUint32(off, nodeCount, Endian.little);
    off += 4;
    buf.setUint32(off, edgeCount, Endian.little);
    off += 4;
    buf.setUint32(off, roadNames.length, Endian.little);
    off += 4;

    for (var i = 0; i < nodeCount; i++) {
      buf.setFloat64(off, lats[i], Endian.little);
      off += 8;
      buf.setFloat64(off, lngs[i], Endian.little);
      off += 8;
    }

    for (var from = 0; from < adjacency.length; from++) {
      for (final e in adjacency[from]) {
        buf.setUint32(off, from, Endian.little);
        off += 4;
        buf.setUint32(off, e.to, Endian.little);
        off += 4;
        buf.setFloat32(off, e.distanceM, Endian.little);
        off += 4;
        buf.setInt32(off, e.nameIndex, Endian.little);
        off += 4;
      }
    }

    for (final b in nameBytes) {
      buf.setUint16(off, b.length, Endian.little);
      off += 2;
      for (final byte in b) {
        buf.setUint8(off, byte);
        off += 1;
      }
    }

    return buf.buffer.asUint8List();
  }

  static List<int> _utf8(String s) => s.runes.expand((r) {
        // یک انکودر UTF-8 دستی و ساده (بدون وابستگی به dart:convert.utf8 که
        // برای این حجم کوچک رشته کافی و سریع‌تر از import اضافه است)
        if (r < 0x80) return [r];
        if (r < 0x800) {
          return [0xC0 | (r >> 6), 0x80 | (r & 0x3F)];
        }
        if (r < 0x10000) {
          return [0xE0 | (r >> 12), 0x80 | ((r >> 6) & 0x3F), 0x80 | (r & 0x3F)];
        }
        return [
          0xF0 | (r >> 18),
          0x80 | ((r >> 12) & 0x3F),
          0x80 | ((r >> 6) & 0x3F),
          0x80 | (r & 0x3F),
        ];
      }).toList();

  static RoadGraph decode(Uint8List bytes) {
    final buf = ByteData.sublistView(bytes);
    var off = 0;
    if (buf.getUint8(0) != 0x41 || buf.getUint8(1) != 0x4F || buf.getUint8(2) != 0x47) {
      throw const FormatException('فایل گراف مسیریابی نامعتبر است (magic mismatch)');
    }
    off += 4;
    final nodeCount = buf.getUint32(off, Endian.little);
    off += 4;
    final edgeCount = buf.getUint32(off, Endian.little);
    off += 4;
    final nameCount = buf.getUint32(off, Endian.little);
    off += 4;

    final lats = Float64List(nodeCount);
    final lngs = Float64List(nodeCount);
    for (var i = 0; i < nodeCount; i++) {
      lats[i] = buf.getFloat64(off, Endian.little);
      off += 8;
      lngs[i] = buf.getFloat64(off, Endian.little);
      off += 8;
    }

    final adjacency = List.generate(nodeCount, (_) => <RoadEdge>[]);
    for (var i = 0; i < edgeCount; i++) {
      final from = buf.getUint32(off, Endian.little);
      off += 4;
      final to = buf.getUint32(off, Endian.little);
      off += 4;
      final dist = buf.getFloat32(off, Endian.little);
      off += 4;
      final nameIdx = buf.getInt32(off, Endian.little);
      off += 4;
      adjacency[from].add(RoadEdge(to: to, distanceM: dist, nameIndex: nameIdx));
    }

    final names = <String>[];
    for (var i = 0; i < nameCount; i++) {
      final len = buf.getUint16(off, Endian.little);
      off += 2;
      final strBytes = bytes.sublist(off, off + len);
      names.add(String.fromCharCodes(strBytes.isEmpty ? const [] : _decodeUtf8(strBytes)));
      off += len;
    }

    return RoadGraph(lats: lats, lngs: lngs, adjacency: adjacency, roadNames: names);
  }

  static List<int> _decodeUtf8(List<int> bytes) {
    // خروجی این تابع باید runes باشد تا String.fromCharCodes رشته‌ی درست
    // بسازد؛ چون رشته‌های نام خیابان معمولاً کوتاه‌اند، یک دیکودر ساده کافی
    // است (پوشش کامل UTF-8 تا ۴ بایتی).
    final runes = <int>[];
    var i = 0;
    while (i < bytes.length) {
      final b0 = bytes[i];
      if (b0 < 0x80) {
        runes.add(b0);
        i += 1;
      } else if (b0 & 0xE0 == 0xC0) {
        runes.add(((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else if (b0 & 0xF0 == 0xE0) {
        runes.add(((b0 & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
        i += 3;
      } else {
        runes.add(((b0 & 0x07) << 18) |
            ((bytes[i + 1] & 0x3F) << 12) |
            ((bytes[i + 2] & 0x3F) << 6) |
            (bytes[i + 3] & 0x3F));
        i += 4;
      }
    }
    return runes;
  }
}
