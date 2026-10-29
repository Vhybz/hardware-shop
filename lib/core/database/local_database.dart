import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

part 'local_database.g.dart';

// 1. Define the Sync Queue Table
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  TextColumn get data => text()(); // JSON representation
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. Define standard local tables
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get branchCode => text().nullable()();
  TextColumn get name => text()();
  RealColumn get retailPrice => real()();
  RealColumn get wholesalePrice => real()();
  TextColumn get category => text()();
  RealColumn get stockQuantity => real()();
  TextColumn get unit => text()();
  TextColumn get size => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [SyncQueue, LocalProducts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    if (kIsWeb) {
      final result = await WasmDatabase.open(
        databaseName: 'adom_mmoroso_db',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    }
    
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
