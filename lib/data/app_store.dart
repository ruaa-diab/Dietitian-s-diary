import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/formatting.dart';
import 'app_database.dart';
import 'sample_data.dart';

/// Application state, held in memory and — outside of tests — mirrored
/// to an on-device SQLite database so it survives closing the app.
///
/// Everything the UI shows is derived from these three lists; screens
/// only ever talk to this class, never to [AppDatabase] or [SampleData]
/// directly, so persistence lives entirely in this file.
class AppStore extends ChangeNotifier {
  /// In-memory only — no database, nothing persists. Used by tests and by
  /// anything that wants a disposable, deterministic store.
  AppStore({SampleSeed? seed}) : _db = null {
    final data = seed ?? SampleData.build();
    _clients = [...data.clients];
    _packages = [...data.packages];
    _visits = [...data.visits];
  }

  AppStore._withDatabase({
    required Database db,
    required List<Client> clients,
    required List<ClientPackage> packages,
    required List<Visit> visits,
  }) : _db = db {
    _clients = clients;
    _packages = packages;
    _visits = visits;
  }

  /// Opens the on-device database, seeding it once on the very first
  /// launch, and loads the store from it. Every mutation from here on
  /// writes through, so data survives closing the app.
  static Future<AppStore> load({String? databasePath}) async {
    final db = await AppDatabase.open(path: databasePath);
    if (await AppDatabase.isEmpty(db)) {
      final seed = SampleData.build();
      await AppDatabase.seed(
        db,
        clients: seed.clients,
        packages: seed.packages,
        visits: seed.visits,
      );
    }
    final data = await AppDatabase.readAll(db);
    return AppStore._withDatabase(
      db: db,
      clients: data.clients,
      packages: data.packages,
      visits: data.visits,
    );
  }

  /// Null in tests and other in-memory-only instances; writes are skipped
  /// wherever this is null rather than persisted.
  final Database? _db;

  /// The package shapes offered on the "باقة جديدة" screen.
  static const packageOptions = <PackageOption>[
    PackageOption(visitCount: 4, price: 100),
    PackageOption(visitCount: 8, price: 190),
  ];

  late List<Client> _clients;
  late List<ClientPackage> _packages;
  late List<Visit> _visits;

  int _idCounter = 0;

  /// Stamped with the current time so ids stay unique across restarts —
  /// a plain counter would restart at 0 each launch and collide with ids
  /// already written to the database in an earlier session.
  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_idCounter}';

  /// Chains database writes so they land in the order the mutations
  /// happened — a mutation like [markVisit] can issue two in a row (the
  /// visit, then the package it closes), and running them out of order
  /// or concurrently against sqflite is not something to risk.
  Future<void> _pendingWrites = Future<void>.value();

  /// Queues a database write when this store is backed by one; a no-op
  /// for the in-memory-only stores tests use. Errors are logged rather
  /// than surfaced — the in-memory state (and the UI) is already correct
  /// either way, so a failed write means this one change won't survive a
  /// restart, not that the action failed.
  void _persist(Future<void> Function(Database db) write) {
    final db = _db;
    if (db == null) return;
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        await write(db);
      } catch (error) {
        debugPrint('AppStore: failed to persist a change: $error');
      }
    });
  }

  /// Waits for every write issued so far to finish. Production never
  /// awaits this — the UI never blocks on a write — but it gives tests a
  /// real point to synchronize on instead of a guessed delay before
  /// closing the database.
  @visibleForTesting
  Future<void> flushPersistence() => _pendingWrites;

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  /// Set when marking a visit completes a package, so the Today screen can
  /// raise the celebration sheet. The UI clears it once shown.
  ClientPackage? pendingCelebration;

  List<Client> get clients => List.unmodifiable(_clients);
  List<ClientPackage> get packages => List.unmodifiable(_packages);
  List<Visit> get visits => List.unmodifiable(_visits);

  DateTime get now => DateTime.now();

  // ── Lookups ──────────────────────────────────────────────────────────

  Client client(String id) => _clients.firstWhere((c) => c.id == id);

  Client? clientOrNull(String id) {
    for (final c in _clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  ClientPackage package(String id) => _packages.firstWhere((p) => p.id == id);

  Visit visit(String id) => _visits.firstWhere((v) => v.id == id);

  /// Packages for a client, newest first.
  List<ClientPackage> packagesFor(String clientId) =>
      _packages.where((p) => p.clientId == clientId).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  /// The running package, if any — a package with no end date.
  ClientPackage? activePackage(String clientId) {
    for (final p in packagesFor(clientId)) {
      if (p.isActive) return p;
    }
    return null;
  }

  ClientPackage? latestPackage(String clientId) {
    final all = packagesFor(clientId);
    return all.isEmpty ? null : all.first;
  }

  /// Visits of a package in schedule order.
  List<Visit> visitsForPackage(String packageId) =>
      _visits.where((v) => v.packageId == packageId).toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  int attendedCount(String packageId) => _visits
      .where((v) => v.packageId == packageId && v.status == VisitStatus.attended)
      .length;

  int resolvedCount(String packageId) =>
      _visits.where((v) => v.packageId == packageId && v.isResolved).length;

  /// Visits still to be used up — what the "N متبقية" badge counts.
  int remainingVisits(String packageId) {
    final pkg = package(packageId);
    return (pkg.visitCount - resolvedCount(packageId)).clamp(0, pkg.visitCount);
  }

  /// Remaining visits across a client's running package; 0 when idle.
  int remainingForClient(String clientId) {
    final active = activePackage(clientId);
    return active == null ? 0 : remainingVisits(active.id);
  }

  bool isPackageComplete(String packageId) =>
      resolvedCount(packageId) >= package(packageId).visitCount;

  // ── Today ────────────────────────────────────────────────────────────

  List<Visit> visitsOn(DateTime day) {
    final result =
        _visits.where((v) => ArabicDates.isSameDay(v.scheduledAt, day)).toList();
    result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return result;
  }

  /// Today's visits with the pending ones first, matching the mockup where
  /// resolved visits collapse to the bottom of the list.
  List<Visit> get todayVisits {
    final all = visitsOn(now);
    final pending = all.where((v) => !v.isResolved).toList();
    final resolved = all.where((v) => v.isResolved).toList();
    return [...pending, ...resolved];
  }

  // ── Money ────────────────────────────────────────────────────────────

  /// Packages still carrying a balance, most recent first.
  List<ClientPackage> get outstandingPackages =>
      _packages.where((p) => !p.isPaid).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  double get totalOutstanding =>
      outstandingPackages.fold(0.0, (sum, p) => sum + p.balanceDue);

  double balanceDueFor(String clientId) => _packages
      .where((p) => p.clientId == clientId)
      .fold(0.0, (sum, p) => sum + p.balanceDue);

  double revenueForMonth(DateTime month) {
    var total = 0.0;
    for (final pkg in _packages) {
      for (final payment in pkg.payments) {
        if (payment.date.year == month.year && payment.date.month == month.month) {
          total += payment.amount;
        }
      }
    }
    return total;
  }

  /// The six months ending with the current one, oldest first — the mini
  /// bar chart on the dashboard.
  List<({DateTime month, double revenue})> get revenueTrend {
    final anchor = DateTime(now.year, now.month);
    return List.generate(6, (i) {
      final month = DateTime(anchor.year, anchor.month - (5 - i));
      return (month: month, revenue: revenueForMonth(month));
    });
  }

  /// Percent change of this month's revenue against last month's, or
  /// `null` when last month had no revenue to compare against.
  double? get revenueChangePercent {
    final thisMonth = revenueForMonth(now);
    final previous = revenueForMonth(DateTime(now.year, now.month - 1));
    if (previous <= 0) return null;
    return (thisMonth - previous) / previous * 100;
  }

  // ── Renewals ─────────────────────────────────────────────────────────

  /// Clients whose latest package has finished and has not been renewed.
  List<({Client client, ClientPackage package})> get needsRenewal {
    final result = <({Client client, ClientPackage package})>[];
    for (final c in _clients) {
      final latest = latestPackage(c.id);
      if (latest == null || latest.isActive) continue;
      result.add((client: c, package: latest));
    }
    result.sort((a, b) => (b.package.endDate ?? b.package.startDate)
        .compareTo(a.package.endDate ?? a.package.startDate));
    return result;
  }

  bool clientNeedsRenewal(String clientId) {
    final latest = latestPackage(clientId);
    return latest != null && !latest.isActive;
  }

  /// The client the "باقة جديدة" screen should preselect: whoever most
  /// recently finished a package.
  Client? get renewalCandidate {
    final pending = needsRenewal;
    return pending.isEmpty ? null : pending.first.client;
  }

  // ── Search & filters ─────────────────────────────────────────────────

  List<Client> searchClients(String query, ClientFilter filter) {
    final needle = query.trim();
    return _clients.where((c) {
      if (needle.isNotEmpty && !c.name.contains(needle) && !c.phone.contains(needle)) {
        return false;
      }
      return switch (filter) {
        ClientFilter.all => true,
        ClientFilter.needsRenewal => clientNeedsRenewal(c.id),
        ClientFilter.balanceDue => balanceDueFor(c.id) > 0,
      };
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  int countFor(ClientFilter filter) => searchClients('', filter).length;

  // ── Mutations ────────────────────────────────────────────────────────

  /// Records a visit outcome. Completing the last visit of a package
  /// closes the package and queues the celebration.
  void markVisit(String visitId, VisitStatus status) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits[index];
    _visits[index] = visit.copyWith(status: status);
    _persist((db) => AppDatabase.updateVisit(db, _visits[index]));

    if (isPackageComplete(visit.packageId)) {
      final pkgIndex = _packages.indexWhere((p) => p.id == visit.packageId);
      if (pkgIndex >= 0 && _packages[pkgIndex].isActive) {
        _packages[pkgIndex] = _packages[pkgIndex].copyWith(endDate: now);
        pendingCelebration = _packages[pkgIndex];
        _persist((db) => AppDatabase.updatePackage(db, _packages[pkgIndex]));
      }
    }
    notifyListeners();
  }

  /// Undoes a حضرت / لم تحضر decision, reopening the package if that
  /// decision was the one that closed it.
  void undoVisit(String visitId) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits[index];
    _visits[index] = visit.copyWith(status: VisitStatus.scheduled);
    _persist((db) => AppDatabase.updateVisit(db, _visits[index]));

    final pkgIndex = _packages.indexWhere((p) => p.id == visit.packageId);
    if (pkgIndex >= 0 && !_packages[pkgIndex].isActive) {
      _packages[pkgIndex] = _packages[pkgIndex].copyWith(clearEndDate: true);
      _persist((db) => AppDatabase.updatePackage(db, _packages[pkgIndex]));
    }
    if (pendingCelebration?.id == visit.packageId) pendingCelebration = null;
    notifyListeners();
  }

  void consumeCelebration() {
    pendingCelebration = null;
  }

  void recordPayment({
    required String packageId,
    required double amount,
    required PaymentMethod method,
    DateTime? date,
  }) {
    if (amount <= 0) return;
    final index = _packages.indexWhere((p) => p.id == packageId);
    if (index < 0) return;
    final pkg = _packages[index];
    final capped = amount.clamp(0.0, pkg.balanceDue);
    final payment = Payment(
      id: _nextId('pay'),
      packageId: packageId,
      amount: capped.toDouble(),
      method: method,
      date: date ?? now,
    );
    _packages[index] = pkg.copyWith(payments: [...pkg.payments, payment]);
    _persist((db) => AppDatabase.insertPayment(db, payment));
    notifyListeners();
  }

  /// Sells a package: creates the package, its scheduled visits (weekly
  /// from today) and any up-front payment.
  ClientPackage sellPackage({
    required String clientId,
    required PackageOption option,
    required PaymentIntent intent,
    required double amountReceived,
    required PaymentMethod method,
  }) {
    final start = now;
    final packageId = _nextId('pkg');

    final payments = <Payment>[];
    final received = switch (intent) {
      PaymentIntent.paidInFull => option.price,
      PaymentIntent.partial => amountReceived.clamp(0.0, option.price).toDouble(),
      PaymentIntent.later => 0.0,
    };
    if (received > 0) {
      payments.add(Payment(
        id: _nextId('pay'),
        packageId: packageId,
        amount: received,
        method: method,
        date: start,
      ));
    }

    final pkg = ClientPackage(
      id: packageId,
      clientId: clientId,
      visitCount: option.visitCount,
      price: option.price,
      startDate: start,
      payments: payments,
    );
    _packages.add(pkg);
    _persist((db) => AppDatabase.insertPackage(db, pkg));

    final newVisits = <Visit>[];
    for (var i = 0; i < option.visitCount; i++) {
      final at = DateTime(start.year, start.month, start.day + i * 7, 10, 0);
      newVisits.add(Visit(
        id: _nextId('visit'),
        clientId: clientId,
        packageId: packageId,
        index: i + 1,
        scheduledAt: at,
      ));
    }
    _visits.addAll(newVisits);
    _persist((db) => AppDatabase.insertVisits(db, newVisits));

    notifyListeners();
    return pkg;
  }

  Client addClient({
    required String name,
    required String phone,
    required int age,
  }) {
    final client = Client(
      id: _nextId('client'),
      name: name,
      phone: phone,
      age: age,
      startDate: now,
    );
    _clients.add(client);
    _persist((db) => AppDatabase.insertClient(db, client));
    notifyListeners();
    return client;
  }

  /// Adds a one-off appointment against the client's running package.
  void scheduleVisit({required String clientId, required DateTime at}) {
    final active = activePackage(clientId);
    if (active == null) return;
    final existing = visitsForPackage(active.id);
    final visit = Visit(
      id: _nextId('visit'),
      clientId: clientId,
      packageId: active.id,
      index: existing.length + 1,
      scheduledAt: at,
    );
    _visits.add(visit);
    _persist((db) => AppDatabase.insertVisit(db, visit));
    notifyListeners();
  }
}

/// The three chips above the client list.
enum ClientFilter {
  all('الكل'),
  needsRenewal('تحتاج تجديد'),
  balanceDue('رصيد مستحق');

  const ClientFilter(this.label);
  final String label;
}
