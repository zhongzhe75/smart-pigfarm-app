import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:smart_pigfarm_app/database/app_database.dart';
import 'package:smart_pigfarm_app/repositories/repository_factory_sqlite.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('migrates only stale environment seed data once', () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('pigfarm-environment-migration-');
    final databasePath = path.join(temporaryDirectory.path, 'migration.db');
    final appDatabase = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await appDatabase.close();
      await temporaryDirectory.delete(recursive: true);
    });

    final endDate = DateTime.utc(2026, 9, 17);
    final generator = PigFarmSeedDataGenerator();
    await appDatabase.seed(generator.generate(endDate: endDate));
    expect(await appDatabase.isEnvironmentSeeded, isTrue);

    await appDatabase.database.delete(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['environment_seed_version'],
    );
    await appDatabase.database.update(
      'environment_records',
      {'temperature': 32.0},
    );

    final pigsBefore = await appDatabase.database.query('pigs', orderBy: 'id');
    final pigHistoryBefore = await appDatabase.database.query(
      'pig_daily_stats',
      where: 'pig_id = ?',
      whereArgs: ['PIG-037'],
      orderBy: 'date',
    );
    final alertsBefore =
        await appDatabase.database.query('health_alerts', orderBy: 'id');
    final immunizationsBefore =
        await appDatabase.database.query('immunization_records', orderBy: 'id');

    await ensurePlatformSeedData(
      appDatabase,
      generator: generator,
      endDate: endDate,
    );

    final environment = await appDatabase.database.query(
      'environment_records',
      orderBy: 'id',
    );
    final temperatures = environment
        .map((row) => (row['temperature']! as num).toDouble())
        .toList();
    expect(environment, hasLength(1080));
    expect(temperatures, everyElement(inInclusiveRange(24.6, 25.8)));
    expect(await appDatabase.isEnvironmentSeeded, isTrue);
    expect(AppDatabase.seedVersion, 1);
    expect(await appDatabase.database.query('pigs', orderBy: 'id'), pigsBefore);
    expect(
      await appDatabase.database.query(
        'pig_daily_stats',
        where: 'pig_id = ?',
        whereArgs: ['PIG-037'],
        orderBy: 'date',
      ),
      pigHistoryBefore,
    );
    expect(
      await appDatabase.database.query('health_alerts', orderBy: 'id'),
      alertsBefore,
    );
    expect(
      await appDatabase.database.query('immunization_records', orderBy: 'id'),
      immunizationsBefore,
    );

    final firstEnvironmentId = environment.first['id']! as String;
    await appDatabase.database.update(
      'environment_records',
      {'temperature': 25.79},
      where: 'id = ?',
      whereArgs: [firstEnvironmentId],
    );
    await ensurePlatformSeedData(
      appDatabase,
      generator: generator,
      endDate: endDate,
    );
    final retainedRecord = await appDatabase.database.query(
      'environment_records',
      where: 'id = ?',
      whereArgs: [firstEnvironmentId],
      limit: 1,
    );
    expect(retainedRecord.single['temperature'], 25.79);
  });
}
