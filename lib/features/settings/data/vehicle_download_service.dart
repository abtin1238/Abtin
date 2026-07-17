import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import 'vehicle_registry.dart';

/// وضعیتِ دانلودِ یک خودرو.
class VehicleDownloadState {
  final bool downloading;
  final double progress; // 0..1
  final bool installed;
  final String? filePath;

  const VehicleDownloadState({
    this.downloading = false,
    this.progress = 0,
    this.installed = false,
    this.filePath,
  });

  VehicleDownloadState copyWith({
    bool? downloading,
    double? progress,
    bool? installed,
    String? filePath,
  }) =>
      VehicleDownloadState(
        downloading: downloading ?? this.downloading,
        progress: progress ?? this.progress,
        installed: installed ?? this.installed,
        filePath: filePath ?? this.filePath,
      );
}

/// سرویسِ دانلود و مدیریتِ خودروهای سه‌بعدی (GLB) — کاملاً محلی پس از دانلود.
///
/// - دانلود از لینکِ مستقیمِ GLB با گزارشِ پیشرفت
/// - ذخیره در پوشه‌ی مستنداتِ برنامه: `.../vehicles/<id>.glb`
/// - پیگیریِ خودروهای نصب‌شده و خودروی انتخاب‌شده در SQLite (app_settings)
class VehicleDownloadService {
  VehicleDownloadService(this._db);
  final AppDatabase? _db;

  static const _selectedKey = 'selected_vehicle_id';
  static const _installedPrefix = 'vehicle_path_';

  Future<Directory> _vehiclesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final vdir = Directory(p.join(dir.path, 'vehicles'));
    if (!await vdir.exists()) {
      await vdir.create(recursive: true);
    }
    return vdir;
  }

  /// مسیرِ فایلِ نصب‌شده (اگر موجود باشد).
  Future<String?> installedPath(VehicleModel model) async {
    final saved = _db?.getSetting('$_installedPrefix${model.id}');
    if (saved != null && await File(saved).exists()) return saved;
    // بازیابیِ خودکار در صورتِ وجودِ فایل روی دیسک.
    final vdir = await _vehiclesDir();
    final f = File(p.join(vdir.path, model.fileName));
    if (await f.exists()) {
      _db?.setSetting('$_installedPrefix${model.id}', f.path);
      return f.path;
    }
    return null;
  }

  Future<bool> isInstalled(VehicleModel model) async =>
      (await installedPath(model)) != null;

  String? get selectedVehicleId => _db?.getSetting(_selectedKey);

  void selectVehicle(String? id) {
    if (id == null) {
      _db?.setSetting(_selectedKey, '');
    } else {
      _db?.setSetting(_selectedKey, id);
    }
  }

  /// دانلودِ مدل با گزارشِ پیشرفت (0..1). مسیرِ فایلِ محلی بازگردانده می‌شود.
  Future<String> download(
    VehicleModel model, {
    void Function(double progress)? onProgress,
  }) async {
    final vdir = await _vehiclesDir();
    final dest = File(p.join(vdir.path, model.fileName));
    final tmp = File('${dest.path}.part');

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(model.url));
      req.headers['User-Agent'] = 'AbtinNavigator/1.0';
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw Exception('دانلود ناموفق (کد ${resp.statusCode})');
      }
      final total = resp.contentLength ?? model.sizeBytes;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
      await sink.flush();
      await sink.close();
      if (await dest.exists()) await dest.delete();
      await tmp.rename(dest.path);
      _db?.setSetting('$_installedPrefix${model.id}', dest.path);
      onProgress?.call(1.0);
      return dest.path;
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      debugPrint('Vehicle download error: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// حذفِ خودروی دانلودشده.
  Future<void> delete(VehicleModel model) async {
    final path = await installedPath(model);
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    _db?.setSetting('$_installedPrefix${model.id}', '');
    if (selectedVehicleId == model.id) selectVehicle(null);
  }
}
