import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// جدول مکان‌های ذخیره‌شده (خانه، محل کار، علاقه‌مندی‌ها و...).
/// نکته: هیچ داده‌ی فیک/mock در این جدول قرار نمی‌گیرد؛ فقط مکان‌هایی که
/// کاربر از نقشه یا نتایج جستجوی OSM ذخیره می‌کند.
class SavedPlaces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();
  // category: 'home' | 'work' | 'favorite' | 'recent'
  TextColumn get category => text().withDefault(const Constant('favorite'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// جدول تاریخچه‌ی مسیرهای طی‌شده (برای فاز Routing، از الان آماده شده).
class RouteHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get startLat => real()();
  RealColumn get startLng => real()();
  RealColumn get endLat => real()();
  RealColumn get endLng => real()();
  TextColumn get endLabel => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [SavedPlaces, RouteHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'abtin_navigator.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
