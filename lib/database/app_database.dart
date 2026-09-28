import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/environment_record.dart';
import '../services/pig_farm_seed_data_generator.dart';

class AppDatabase {
  AppDatabase._(this.database);

  static const databaseName = 'smart_pigfarm_v2.db';
  static const databaseVersion = 1;
  static const seedVersion = 1;
  static const environmentSeedVersion = 2;

  final Database database;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final resolvedPath = databasePath ??
        path.join(await selectedFactory.getDatabasesPath(), databaseName);
    final db = await selectedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return AppDatabase._(db);
  }

  Future<bool> get isSeeded => _isSeedVersionCurrent(
        key: 'seed_version',
        version: seedVersion,
      );

  Future<bool> get isEnvironmentSeeded => _isSeedVersionCurrent(
        key: 'environment_seed_version',
        version: environmentSeedVersion,
      );

  Future<bool> _isSeedVersionCurrent({
    required String key,
    required int version,
  }) async {
    final rows = await database.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == version.toString();
  }

  Future<void> seed(PigFarmSeedData data) async {
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      batch.delete('health_alerts');
      batch.delete('immunization_records');
      batch.delete('pig_daily_stats');
      batch.delete('environment_records');
      batch.delete('pigs');

      for (final pig in data.pigs) {
        batch.insert('pigs', pig.toMap());
      }
      for (final stat in data.dailyStats) {
        batch.insert('pig_daily_stats', stat.toMap());
      }
      for (final alert in data.healthAlerts) {
        batch.insert('health_alerts', alert.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final record in data.immunizations) {
        batch.insert('immunization_records', record.toMap());
      }
      for (final record in data.environmentRecords) {
        batch.insert('environment_records', record.toMap());
      }
      batch.insert(
        'app_meta',
        {'key': 'seed_version', 'value': seedVersion.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_meta',
        {
          'key': 'environment_seed_version',
          'value': environmentSeedVersion.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  Future<void> seedEnvironment(
    List<EnvironmentRecord> environmentRecords,
  ) async {
    await database.transaction((transaction) async {
      final batch = transaction.batch();
      batch.delete('environment_records');
      for (final record in environmentRecords) {
        batch.insert('environment_records', record.toMap());
      }
      batch.insert(
        'app_meta',
        {
          'key': 'environment_seed_version',
          'value': environmentSeedVersion.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  Future<void> close() => database.close();

  static Future<void> _createSchema(Database database, int version) async {
    final batch = database.batch();
    batch.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE pigs (
        id TEXT PRIMARY KEY,
        ear_tag TEXT NOT NULL UNIQUE,
        pig_house_id TEXT NOT NULL,
        batch_no TEXT NOT NULL,
        sex TEXT NOT NULL,
        birth_date INTEGER NOT NULL,
        current_status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE pig_daily_stats (
        pig_id TEXT NOT NULL,
        date INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        feed_amount_kg REAL NOT NULL,
        feeding_duration_minutes INTEGER NOT NULL,
        activity_distance_meters REAL NOT NULL,
        activity_duration_minutes INTEGER NOT NULL,
        rest_duration_minutes INTEGER NOT NULL,
        health_score INTEGER NOT NULL,
        risk_level TEXT NOT NULL,
        PRIMARY KEY (pig_id, date),
        FOREIGN KEY (pig_id) REFERENCES pigs(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE health_alerts (
        id TEXT PRIMARY KEY,
        pig_id TEXT NOT NULL,
        pig_house_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        alert_type TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        current_value REAL NOT NULL,
        baseline_value REAL NOT NULL,
        deviation_percent REAL NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (pig_id) REFERENCES pigs(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE immunization_records (
        id TEXT PRIMARY KEY,
        pig_id TEXT NOT NULL,
        batch_no TEXT NOT NULL,
        vaccine_name TEXT NOT NULL,
        immunized_at INTEGER NOT NULL,
        next_due_at INTEGER,
        operator_name TEXT NOT NULL,
        note TEXT NOT NULL,
        FOREIGN KEY (pig_id) REFERENCES pigs(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE environment_records (
        id TEXT PRIMARY KEY,
        pig_house_id TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        light REAL NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_pigs_house ON pigs(pig_house_id)');
    batch.execute('CREATE INDEX idx_pig_stats_date ON pig_daily_stats(date)');
    batch.execute(
        'CREATE INDEX idx_pig_stats_risk ON pig_daily_stats(risk_level, date)');
    batch.execute(
        'CREATE INDEX idx_alerts_pig_time ON health_alerts(pig_id, created_at DESC)');
    batch.execute(
        'CREATE INDEX idx_alerts_filter ON health_alerts(severity, status, created_at DESC)');
    batch.execute(
      'CREATE INDEX idx_environment_house_time '
      'ON environment_records(pig_house_id, recorded_at)',
    );
    await batch.commit(noResult: true);
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    // Future versions add ordered migrations here. Version 1 is the V2 base.
  }
}
