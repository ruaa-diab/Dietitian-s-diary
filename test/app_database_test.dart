// Runs the real SQLite code path against the native sqlite3 library via
// sqflite_common_ffi, rather than the Android platform channel sqflite
// normally uses — this is the standard way to test sqflite-backed code
// without a device. Everything under test here is the same code
// production runs; only how the database is opened differs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taghdiya/data/app_database.dart';
import 'package:taghdiya/data/app_store.dart';
import 'package:taghdiya/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('taghdiya_db_test');
    dbPath = '${tempDir.path}/test.db';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('AppDatabase', () {
    test('a fresh database is empty', () async {
      final db = await AppDatabase.open(path: dbPath);
      addTearDown(db.close);
      expect(await AppDatabase.isEmpty(db), isTrue);
    });

    test('a package round-trips with its payments attached', () async {
      final db = await AppDatabase.open(path: dbPath);
      addTearDown(db.close);

      final client = Client(
        id: 'c1',
        name: 'سلمى يوسف',
        phone: '0541234567',
        age: 30,
        startDate: DateTime(2026, 1, 1),
      );
      final package = ClientPackage(
        id: 'p1',
        clientId: 'c1',
        visitCount: 4,
        price: 100,
        startDate: DateTime(2026, 1, 1),
        payments: [
          Payment(
            id: 'pay1',
            packageId: 'p1',
            amount: 60,
            method: PaymentMethod.bit,
            date: DateTime(2026, 1, 1),
          ),
        ],
      );

      await AppDatabase.seed(db, clients: [client], packages: [package], visits: const []);
      final data = await AppDatabase.readAll(db);

      expect(data.clients.single.name, 'سلمى يوسف');
      expect(data.packages.single.payments.single.amount, 60);
      expect(data.packages.single.payments.single.method, PaymentMethod.bit);
      expect(data.packages.single.balanceDue, 40);
    });

    test('closing and reopening the database keeps everything written',
        () async {
      final first = await AppDatabase.open(path: dbPath);
      final client = Client(
        id: 'c1',
        name: 'دعاء شاهين',
        phone: '0538812704',
        age: 38,
        startDate: DateTime(2026, 1, 1),
      );
      await AppDatabase.insertClient(first, client);
      await first.close();

      final second = await AppDatabase.open(path: dbPath);
      addTearDown(second.close);
      final data = await AppDatabase.readAll(second);

      expect(data.clients.single.id, 'c1');
      expect(data.clients.single.name, 'دعاء شاهين');
    });

    test('updating a package persists the change across a reopen', () async {
      final first = await AppDatabase.open(path: dbPath);
      final client = Client(
        id: 'c1',
        name: 'نور خالد',
        phone: '0541234567',
        age: 34,
        startDate: DateTime(2026, 1, 1),
      );
      final package = ClientPackage(
        id: 'p1',
        clientId: 'c1',
        visitCount: 4,
        price: 100,
        startDate: DateTime(2026, 1, 1),
      );
      await AppDatabase.seed(first, clients: [client], packages: [package], visits: const []);

      final closed = package.copyWith(endDate: DateTime(2026, 1, 20));
      await AppDatabase.updatePackage(first, closed);
      await first.close();

      final second = await AppDatabase.open(path: dbPath);
      addTearDown(second.close);
      final data = await AppDatabase.readAll(second);

      expect(data.packages.single.isActive, isFalse);
      expect(data.packages.single.endDate, DateTime(2026, 1, 20));
    });
  });

  group('AppStore.load', () {
    test('the very first load seeds the database', () async {
      final store = await AppStore.load(databasePath: dbPath);
      addTearDown(store.dispose);

      expect(store.clients.length, 24);
      expect(store.clientOrNull('c-nour'), isNotNull);
    });

    test('a change made in one session is there in the next', () async {
      final first = await AppStore.load(databasePath: dbPath);
      final added = first.addClient(name: 'مريم فاضل', phone: '0551112233', age: 27);
      await first.flushPersistence();
      first.dispose();

      final second = await AppStore.load(databasePath: dbPath);
      addTearDown(second.dispose);

      expect(second.clientOrNull(added.id)?.name, 'مريم فاضل');
      // The seed itself isn't repeated on the second load.
      expect(second.clients.length, 25);
    });

    test('a recorded payment survives a reload', () async {
      final first = await AppStore.load(databasePath: dbPath);
      final pkg = first.packagesFor('c-nour').firstWhere((p) => !p.isPaid);
      first.recordPayment(packageId: pkg.id, amount: 60, method: PaymentMethod.transfer);
      await first.flushPersistence();
      first.dispose();

      final second = await AppStore.load(databasePath: dbPath);
      addTearDown(second.dispose);

      expect(second.package(pkg.id).balanceDue, pkg.balanceDue - 60);
      expect(second.package(pkg.id).payments.any((p) => p.amount == 60), isTrue);
    });

    test('marking a visit attended survives a reload', () async {
      final first = await AppStore.load(databasePath: dbPath);
      final visit = first.todayVisits.firstWhere((v) => !v.isResolved);
      first.markVisit(visit.id, VisitStatus.attended);
      await first.flushPersistence();
      first.dispose();

      final second = await AppStore.load(databasePath: dbPath);
      addTearDown(second.dispose);

      expect(second.visit(visit.id).status, VisitStatus.attended);
    });
  });
}
