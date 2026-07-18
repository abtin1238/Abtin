import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../data/saved_places_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final savedPlacesRepositoryProvider = Provider<SavedPlacesRepository>((ref) {
  return SavedPlacesRepository(ref.watch(appDatabaseProvider));
});

final savedPlacesListProvider = StreamProvider((ref) {
  return ref.watch(savedPlacesRepositoryProvider).watchAll();
});
