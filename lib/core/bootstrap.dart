import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'security/secure_key_store.dart';
import 'services/routing_service.dart';
import 'services/tts_service.dart';

/// وضعیت راه‌اندازی اولیه اپ (دیتابیس + موتور مسیریابی + TTS).
class AppBootstrap {
  AppBootstrap({
    required this.database,
    required this.routingService,
    required this.ttsService,
  });

  final AppDatabase database;
  final RoutingService routingService;
  final TtsService ttsService;

  static Future<AppBootstrap> init() async {
    final passphrase = await SecureKeyStore.getOrCreatePassphrase();
    AppDatabase db;
    try {
      db = await AppDatabase.open(passphrase: passphrase);
    } catch (e, st) {
      debugPrint('SQLCipher open failed, falling back to memory: $e\n$st');
      db = await AppDatabase.openInMemory();
    }

    final routing = RoutingService();
    await routing.ensureOfflineGraphLoaded();

    final tts = TtsService();
    try {
      await tts.init();
    } catch (_) {}

    return AppBootstrap(
      database: db,
      routingService: routing,
      ttsService: tts,
    );
  }

  void dispose() {
    database.close();
  }
}

/// Provider سراسری bootstrap (override در main).
final appBootstrapProvider = Provider<AppBootstrap>((ref) {
  throw UnimplementedError('appBootstrapProvider must be overridden in main');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return ref.watch(appBootstrapProvider).database;
});

final bootstrapTtsProvider = Provider<TtsService>((ref) {
  return ref.watch(appBootstrapProvider).ttsService;
});
