// Drift database for HueTap. Schema is taken verbatim from SPEC §6.3.
//
// Storage location: `<appSupportDir>/huetap.db` on Android, which resolves to
// `/data/data/<pkg>/files/huetap.db` — matching SPEC §6.10's Android Backup
// rules (this file is *included* in auto-backup; bridge credentials in
// `no_backup/` are not).
//
// All tables from §6.3 are created at schema v1 even though the Phase 1
// prototype only writes to `Bridges`. Creating everything up front avoids
// needing a migration to add the other tables in later phases.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DataClassName('Bridge')
class Bridges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ip => text()();
  TextColumn get bridgeId => text().unique()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get pairedAt => dateTime()();
  DateTimeColumn get lastReachable => dateTime().nullable()();
}

@DataClassName('Scene')
class Scenes extends Table {
  TextColumn get id => text()();
  IntColumn get bridgeRowId => integer().references(Bridges, #id)();
  TextColumn get name => text()();
  TextColumn get roomId => text().nullable()();
  TextColumn get roomName => text().nullable()();
  TextColumn get zoneId => text().nullable()();
  TextColumn get zoneName => text().nullable()();
  BoolColumn get orphaned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSynced => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id, bridgeRowId};
}

@DataClassName('CardBinding')
class CardBindings extends Table {
  TextColumn get uuid => text()();
  TextColumn get label => text()();
  IntColumn get bridgeRowId => integer().references(Bridges, #id)();
  TextColumn get sceneId => text()();
  BoolColumn get revoked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastTapped => dateTime().nullable()();
  IntColumn get tapCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {uuid};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (scene_id, bridge_row_id) REFERENCES scenes (id, bridge_row_id)',
  ];
}

@DataClassName('TapLog')
class TapLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bridgeRowId => integer().nullable().references(Bridges, #id)();
  TextColumn get cardUuid => text().nullable()();
  TextColumn get cardLabel => text().nullable()();
  TextColumn get sceneId => text().nullable()();
  TextColumn get sceneName => text().nullable()();
  BoolColumn get success => boolean()();
  TextColumn get errorType => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

@DataClassName('Settings')
class SettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get crashReportingEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get language => text().withDefault(const Constant('en'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DriftDatabase(tables: [Bridges, Scenes, CardBindings, TapLogs, SettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for tests — pass a pre-built executor (typically an
  /// in-memory NativeDatabase).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Seed the singleton settings row. CHECK (id = 1) forbids anything else.
      await into(settingsTable).insert(const SettingsTableCompanion());
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    // Android uses POSIX separators; hardcoded `/` is safe for this Android-
    // only app (see SPEC §1 "Platform: Android only").
    final file = File('${dir.path}/huetap.db');
    return NativeDatabase.createInBackground(file);
  });
}
