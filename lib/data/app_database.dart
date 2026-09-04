import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// The on-device SQLite store.
///
/// One table per model, ids kept as the primary key so a row round-trips
/// to the same [Client]/[ClientPackage]/[Visit]/[Payment] it came from.
/// Dates are stored as epoch milliseconds; enums as their `.name`.
abstract final class AppDatabase {
  static const _fileName = 'taghdiya.db';

  /// [path] lets callers point at a specific file — tests use it to open
  /// the same on-disk database twice in a row, proving a write in one
  /// session is still there in the next. Production never passes it, so
  /// it falls back to the platform's real databases directory.
  static Future<Database> open({String? path}) async {
    final resolvedPath = path ?? p.join(await getDatabasesPath(), _fileName);
    return openDatabase(resolvedPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE clients (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          age INTEGER NOT NULL,
          start_date INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE packages (
          id TEXT PRIMARY KEY,
          client_id TEXT NOT NULL,
          visit_count INTEGER NOT NULL,
          price REAL NOT NULL,
          start_date INTEGER NOT NULL,
          end_date INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE payments (
          id TEXT PRIMARY KEY,
          package_id TEXT NOT NULL,
          amount REAL NOT NULL,
          method TEXT NOT NULL,
          date INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE visits (
          id TEXT PRIMARY KEY,
          client_id TEXT NOT NULL,
          package_id TEXT NOT NULL,
          seq INTEGER NOT NULL,
          scheduled_at INTEGER NOT NULL,
          status TEXT NOT NULL
        )
      ''');
    });
  }

  static Future<bool> isEmpty(Database db) async {
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM clients'),
    );
    return (result ?? 0) == 0;
  }

  /// Everything the store needs, assembled in one read: packages come
  /// back with their payments already attached.
  static Future<({
    List<Client> clients,
    List<ClientPackage> packages,
    List<Visit> visits,
  })> readAll(Database db) async {
    final clientRows = await db.query('clients');
    final packageRows = await db.query('packages');
    final paymentRows = await db.query('payments');
    final visitRows = await db.query('visits');

    final paymentsByPackage = <String, List<Payment>>{};
    for (final row in paymentRows) {
      final payment = _paymentFromRow(row);
      paymentsByPackage.putIfAbsent(payment.packageId, () => []).add(payment);
    }

    return (
      clients: clientRows.map(_clientFromRow).toList(),
      packages: packageRows
          .map((row) => _packageFromRow(row, paymentsByPackage[row['id']] ?? const []))
          .toList(),
      visits: visitRows.map(_visitFromRow).toList(),
    );
  }

  /// Writes a freshly generated seed in one go, for the very first launch.
  static Future<void> seed(Database db, {
    required List<Client> clients,
    required List<ClientPackage> packages,
    required List<Visit> visits,
  }) async {
    final batch = db.batch();
    for (final client in clients) {
      batch.insert('clients', _clientToRow(client));
    }
    for (final package in packages) {
      batch.insert('packages', _packageToRow(package));
      for (final payment in package.payments) {
        batch.insert('payments', _paymentToRow(payment));
      }
    }
    for (final visit in visits) {
      batch.insert('visits', _visitToRow(visit));
    }
    await batch.commit(noResult: true);
  }

  static Future<void> insertClient(Database db, Client client) =>
      db.insert('clients', _clientToRow(client));

  static Future<void> insertPackage(Database db, ClientPackage package) async {
    final batch = db.batch();
    batch.insert('packages', _packageToRow(package));
    for (final payment in package.payments) {
      batch.insert('payments', _paymentToRow(payment));
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updatePackage(Database db, ClientPackage package) =>
      db.update('packages', _packageToRow(package), where: 'id = ?', whereArgs: [package.id]);

  static Future<void> insertPayment(Database db, Payment payment) =>
      db.insert('payments', _paymentToRow(payment));

  static Future<void> insertVisit(Database db, Visit visit) =>
      db.insert('visits', _visitToRow(visit));

  static Future<void> insertVisits(Database db, List<Visit> visits) async {
    final batch = db.batch();
    for (final visit in visits) {
      batch.insert('visits', _visitToRow(visit));
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateVisit(Database db, Visit visit) =>
      db.update('visits', _visitToRow(visit), where: 'id = ?', whereArgs: [visit.id]);

  // ── Row <-> model ────────────────────────────────────────────────────

  static Client _clientFromRow(Map<String, Object?> row) => Client(
        id: row['id']! as String,
        name: row['name']! as String,
        phone: row['phone']! as String,
        age: row['age']! as int,
        startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date']! as int),
      );

  static Map<String, Object?> _clientToRow(Client client) => {
        'id': client.id,
        'name': client.name,
        'phone': client.phone,
        'age': client.age,
        'start_date': client.startDate.millisecondsSinceEpoch,
      };

  static ClientPackage _packageFromRow(Map<String, Object?> row, List<Payment> payments) =>
      ClientPackage(
        id: row['id']! as String,
        clientId: row['client_id']! as String,
        visitCount: row['visit_count']! as int,
        price: (row['price']! as num).toDouble(),
        startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date']! as int),
        endDate: row['end_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['end_date']! as int),
        payments: payments,
      );

  static Map<String, Object?> _packageToRow(ClientPackage package) => {
        'id': package.id,
        'client_id': package.clientId,
        'visit_count': package.visitCount,
        'price': package.price,
        'start_date': package.startDate.millisecondsSinceEpoch,
        'end_date': package.endDate?.millisecondsSinceEpoch,
      };

  static Payment _paymentFromRow(Map<String, Object?> row) => Payment(
        id: row['id']! as String,
        packageId: row['package_id']! as String,
        amount: (row['amount']! as num).toDouble(),
        method: PaymentMethod.values.byName(row['method']! as String),
        date: DateTime.fromMillisecondsSinceEpoch(row['date']! as int),
      );

  static Map<String, Object?> _paymentToRow(Payment payment) => {
        'id': payment.id,
        'package_id': payment.packageId,
        'amount': payment.amount,
        'method': payment.method.name,
        'date': payment.date.millisecondsSinceEpoch,
      };

  static Visit _visitFromRow(Map<String, Object?> row) => Visit(
        id: row['id']! as String,
        clientId: row['client_id']! as String,
        packageId: row['package_id']! as String,
        index: row['seq']! as int,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(row['scheduled_at']! as int),
        status: VisitStatus.values.byName(row['status']! as String),
      );

  static Map<String, Object?> _visitToRow(Visit visit) => {
        'id': visit.id,
        'client_id': visit.clientId,
        'package_id': visit.packageId,
        'seq': visit.index,
        'scheduled_at': visit.scheduledAt.millisecondsSinceEpoch,
        'status': visit.status.name,
      };
}
