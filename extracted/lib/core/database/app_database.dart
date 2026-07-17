import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart';

/// مدل علاقه‌مندی ذخیره‌شده.
class FavoriteRow {
  final String id;
  final String title;
  final String subtitle;
  final double lat;
  final double lon;
  final String category;
  final DateTime createdAt;

  const FavoriteRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
    required this.category,
    required this.createdAt,
  });

  factory FavoriteRow.fromMap(Map<String, Object?> m) => FavoriteRow(
        id: m['id']! as String,
        title: m['title']! as String,
        subtitle: (m['subtitle'] as String?) ?? '',
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        category: (m['category'] as String?) ?? 'other',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0,
        ),
      );
}

/// مدل تاریخچه جستجو.
class SearchHistoryRow {
  final int id;
  final String query;
  final String? placeId;
  final String? title;
  final double? lat;
  final double? lon;
  final DateTime createdAt;

  const SearchHistoryRow({
    required this.id,
    required this.query,
    this.placeId,
    this.title,
    this.lat,
    this.lon,
    required this.createdAt,
  });

  factory SearchHistoryRow.fromMap(Map<String, Object?> m) => SearchHistoryRow(
        id: m['id']! as int,
        query: m['query']! as String,
        placeId: m['place_id'] as String?,
        title: m['title'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lon: (m['lon'] as num?)?.toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0,
        ),
      );
}

/// بسته نقشه آفلاین.
class OfflineMapPackageRow {
  final String id;
  final String nameFa;
  final String nameEn;
  final int version;
  final double centerLat;
  final double centerLon;
  final int sizeBytes;
  final bool isBundled;
  final bool isInstalled;

  const OfflineMapPackageRow({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.version,
    required this.centerLat,
    required this.centerLon,
    required this.sizeBytes,
    required this.isBundled,
    required this.isInstalled,
  });

  factory OfflineMapPackageRow.fromMap(Map<String, Object?> m) =>
      OfflineMapPackageRow(
        id: m['id']! as String,
        nameFa: m['name_fa']! as String,
        nameEn: (m['name_en'] as String?) ?? '',
        version: (m['version'] as int?) ?? 1,
        centerLat: (m['center_lat'] as num).toDouble(),
        centerLon: (m['center_lon'] as num).toDouble(),
        sizeBytes: (m['size_bytes'] as int?) ?? 0,
        isBundled: ((m['is_bundled'] as int?) ?? 0) == 1,
        isInstalled: ((m['is_installed'] as int?) ?? 1) == 1,
      );
}

/// هشدار محلی (دوربین، مدرسه، تونل، ...).
class LocalHazardRow {
  final String id;
  final String type;
  final String title;
  final double lat;
  final double lon;
  final int? speedLimit;
  final double radiusMeters;

  const LocalHazardRow({
    required this.id,
    required this.type,
    required this.title,
    required this.lat,
    required this.lon,
    this.speedLimit,
    required this.radiusMeters,
  });

  factory LocalHazardRow.fromMap(Map<String, Object?> m) => LocalHazardRow(
        id: m['id']! as String,
        type: m['type']! as String,
        title: m['title']! as String,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        speedLimit: m['speed_limit'] as int?,
        radiusMeters: (m['radius_meters'] as num?)?.toDouble() ?? 80,
      );
}

/// پایگاه‌داده محلی رمزنگاری‌شده با SQLCipher.
///
/// معماری: لایه Data در Clean Architecture.
/// Migration با `user_version` مدیریت می‌شود.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;
  static const int schemaVersion = 1;

  /// باز کردن دیتابیس رمزنگاری‌شده.
  static Future<AppDatabase> open({String? passphrase}) async {
    // توجه: نباید از نام `open` بدون prefix استفاده شود؛
    // چون با متد استاتیک AppDatabase.open تداخل/سایه می‌اندازد.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
        sqlite3_open.open.overrideFor(
          sqlite3_open.OperatingSystem.android,
          openCipherOnAndroid,
        );
      } catch (e) {
        debugPrint('SQLCipher android open override skipped: $e');
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'abtin_secure.db');
    final key = passphrase ?? 'abtin-offline-nav-v1-secure-key';

    final db = sqlite3.open(path);
    // SQLCipher passphrase — فایل روی دیسک کاملاً رمز است.
    db.execute("PRAGMA key = '$key';");
    db.execute('PRAGMA foreign_keys = ON;');
    try {
      db.execute('PRAGMA cipher_memory_security = ON;');
    } catch (_) {
      // در برخی بیلدهای دسکتاپ ممکن است در دسترس نباشد.
    }

    final appDb = AppDatabase._(db);
    await appDb._migrate();
    return appDb;
  }

  /// دیتابیس در حافظه (برای تست واحد).
  static Future<AppDatabase> openInMemory() async {
    final db = sqlite3.openInMemory();
    final appDb = AppDatabase._(db);
    await appDb._migrate();
    return appDb;
  }

  Future<void> _migrate() async {
    final row = _db.select('PRAGMA user_version');
    final current = row.isEmpty ? 0 : (row.first['user_version'] as int? ?? 0);

    if (current < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS favorites (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          subtitle TEXT NOT NULL DEFAULT '',
          lat REAL NOT NULL,
          lon REAL NOT NULL,
          category TEXT NOT NULL DEFAULT 'other',
          created_at INTEGER NOT NULL
        );
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS search_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          query TEXT NOT NULL,
          place_id TEXT,
          title TEXT,
          lat REAL,
          lon REAL,
          created_at INTEGER NOT NULL
        );
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS offline_map_packages (
          id TEXT PRIMARY KEY NOT NULL,
          name_fa TEXT NOT NULL,
          name_en TEXT NOT NULL DEFAULT '',
          version INTEGER NOT NULL DEFAULT 1,
          center_lat REAL NOT NULL,
          center_lon REAL NOT NULL,
          size_bytes INTEGER NOT NULL DEFAULT 0,
          is_bundled INTEGER NOT NULL DEFAULT 0,
          is_installed INTEGER NOT NULL DEFAULT 1,
          installed_at INTEGER NOT NULL
        );
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        );
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS local_hazards (
          id TEXT PRIMARY KEY NOT NULL,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          lat REAL NOT NULL,
          lon REAL NOT NULL,
          speed_limit INTEGER,
          radius_meters REAL NOT NULL DEFAULT 80
        );
      ''');
      _seedDefaults();
      _db.execute('PRAGMA user_version = 1;');
    }
    // if (current < 2) { ... migration v2 ... }
  }

  void _seedDefaults() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT OR REPLACE INTO offline_map_packages
      (id, name_fa, name_en, version, center_lat, center_lon, size_bytes, is_bundled, is_installed, installed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'tehran-sample',
        'تهران (نمونه آفلاین)',
        'Tehran Sample Offline',
        1,
        35.7562,
        51.4110,
        120000,
        1,
        1,
        now,
      ],
    );

    final hazards = <List<Object?>>[
      ['hz_cam_1', 'speed_camera', 'دوربین سرعت', 35.7200, 51.4050, 60, 90.0],
      ['hz_school_1', 'school', 'محدوده مدرسه', 35.7300, 51.4000, 30, 120.0],
      ['hz_tunnel_1', 'tunnel', 'تونل توحید', 35.7000, 51.3800, null, 200.0],
      ['hz_red_1', 'red_light', 'چراغ قرمز', 35.7150, 51.3950, null, 60.0],
      ['hz_police_1', 'police', 'ایست بازرسی', 35.7400, 51.4100, null, 100.0],
      ['hz_danger_1', 'danger', 'نقطه حادثه‌خیز', 35.7250, 51.3900, null, 80.0],
    ];
    for (final h in hazards) {
      _db.execute(
        '''
        INSERT OR REPLACE INTO local_hazards
        (id, type, title, lat, lon, speed_limit, radius_meters)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        h,
      );
    }
  }

  // ---- Favorites ----
  List<FavoriteRow> allFavorites() {
    final rows = _db.select('SELECT * FROM favorites ORDER BY created_at DESC');
    return rows.map((r) => FavoriteRow.fromMap(r)).toList();
  }

  void upsertFavorite({
    required String id,
    required String title,
    String subtitle = '',
    required double lat,
    required double lon,
    String category = 'other',
  }) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO favorites
      (id, title, subtitle, lat, lon, category, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        title,
        subtitle,
        lat,
        lon,
        category,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  void deleteFavorite(String id) {
    _db.execute('DELETE FROM favorites WHERE id = ?', [id]);
  }

  // ---- Search history ----
  void addSearchHistory({
    required String query,
    String? placeId,
    String? title,
    double? lat,
    double? lon,
  }) {
    _db.execute(
      '''
      INSERT INTO search_history
      (query, place_id, title, lat, lon, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        query,
        placeId,
        title,
        lat,
        lon,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    _db.execute('''
      DELETE FROM search_history WHERE id NOT IN (
        SELECT id FROM search_history ORDER BY created_at DESC LIMIT 100
      )
    ''');
  }

  List<SearchHistoryRow> recentSearches({int limit = 20}) {
    final rows = _db.select(
      'SELECT * FROM search_history ORDER BY created_at DESC LIMIT ?',
      [limit],
    );
    return rows.map((r) => SearchHistoryRow.fromMap(r)).toList();
  }

  // ---- Map packages ----
  List<OfflineMapPackageRow> installedMaps() {
    final rows = _db.select(
      'SELECT * FROM offline_map_packages WHERE is_installed = 1',
    );
    return rows.map((r) => OfflineMapPackageRow.fromMap(r)).toList();
  }

  // ---- Settings ----
  void setSetting(String key, String value) {
    _db.execute(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  String? getSetting(String key) {
    final rows =
        _db.select('SELECT value FROM app_settings WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ---- Hazards ----
  List<LocalHazardRow> allHazards() {
    final rows = _db.select('SELECT * FROM local_hazards');
    return rows.map((r) => LocalHazardRow.fromMap(r)).toList();
  }

  List<LocalHazardRow> nearbyHazards(
    double lat,
    double lon, {
    double radiusKm = 2,
  }) {
    final d = radiusKm / 111.0;
    final rows = _db.select(
      '''
      SELECT * FROM local_hazards
      WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
      ''',
      [lat - d, lat + d, lon - d, lon + d],
    );
    return rows.map((r) => LocalHazardRow.fromMap(r)).toList();
  }

  void close() => _db.dispose();
}
