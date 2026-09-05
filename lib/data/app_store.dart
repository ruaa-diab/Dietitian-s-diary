import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../utils/formatting.dart';
import 'cloud_store.dart';
import 'practice_profile.dart';
import 'sample_data.dart';

/// Application state, held in memory and — outside of tests — mirrored
/// to Firestore so it survives closing the app and stays the same across
/// every device signed in to the same account.
///
/// Everything the UI shows is derived from these three lists; screens
/// only ever talk to this class, never to [CloudStore] or [SampleData]
/// directly, so persistence and sync live entirely in this file.
class AppStore extends ChangeNotifier {
  /// In-memory only — no cloud, nothing persists or syncs. Used by tests
  /// and by anything that wants a disposable, deterministic store.
  AppStore({SampleSeed? seed})
      : _cloud = null,
        _auth = null {
    final data = seed ?? SampleData.build();
    _clients = [...data.clients];
    _packages = [...data.packages];
    _visits = [...data.visits];
  }

  /// Backed by Firestore, scoped to one signed-in account. Starts empty
  /// — a real account gets her real data, not the sample roster — and
  /// fills in as soon as the first snapshot arrives from whichever
  /// device(s) she's already used. [auth] is only kept so [signOut] has
  /// something to call — this store never checks who's signed in itself.
  AppStore.forUser(FirebaseFirestore firestore, String uid, {FirebaseAuth? auth})
      : _cloud = CloudStore(firestore, uid),
        _auth = auth {
    _clients = [];
    _packages = [];
    _visits = [];
    _subscribeToCloud();
  }

  /// The package shapes offered on the "باقة جديدة" screen.
  ///
  /// There is exactly one: ٤ زيارات for ١٠٠ ₪. Kept as a list rather than
  /// a bare constant because the screen still renders it as a choice of
  /// one, and a second shape would only be another entry here — nothing
  /// downstream assumes the count.
  static const packageOptions = <PackageOption>[
    PackageOption(visitCount: 4, price: 100),
  ];

  /// The package sold unless something says otherwise.
  static PackageOption get defaultPackage => packageOptions.first;

  /// Null in tests and other in-memory-only instances; writes and the
  /// live subscriptions are skipped wherever this is null.
  final CloudStore? _cloud;

  final FirebaseAuth? _auth;

  /// A no-op in tests, where there's no account to sign out of. AuthGate
  /// is listening for the resulting auth-state change and takes it from
  /// there — this store doesn't navigate anywhere itself.
  void signOut() => _auth?.signOut();

  StreamSubscription<List<Client>>? _clientsSub;
  StreamSubscription<List<ClientPackage>>? _packagesSub;
  StreamSubscription<List<Visit>>? _visitsSub;
  StreamSubscription<String?>? _profileSub;

  /// Listens for changes from Firestore — including ones made on another
  /// device — and folds them into the same lists the UI already reads.
  /// A write this store makes itself also arrives back through here,
  /// almost instantly, from Firestore's local cache; that's expected and
  /// harmless, not a special case to guard against.
  void _subscribeToCloud() {
    final cloud = _cloud!;
    _clientsSub = cloud.watchClients().listen((clients) {
      _clients = clients;
      notifyListeners();
    }, onError: _logError);
    _packagesSub = cloud.watchPackages().listen((packages) {
      _packages = packages;
      notifyListeners();
    }, onError: _logError);
    _visitsSub = cloud.watchVisits().listen((visits) {
      _visits = visits;
      notifyListeners();
    }, onError: _logError);
    // Null until she has actually renamed herself, which is the common
    // case — the default from PracticeProfile stands in until then.
    _profileSub = cloud.watchDietitianName().listen((name) {
      _dietitianName = name ?? PracticeProfile.dietitianName;
      notifyListeners();
    }, onError: _logError);
  }

  static void _logError(Object error) {
    debugPrint('AppStore: sync error: $error');
  }

  late List<Client> _clients;
  late List<ClientPackage> _packages;
  late List<Visit> _visits;

  int _idCounter = 0;

  /// Stamped with the current time so ids stay unique across sessions —
  /// a plain counter would restart at 0 each launch and collide with ids
  /// already written in an earlier session.
  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_idCounter}';

  /// Chains cloud writes so they land in the order the mutations
  /// happened. Errors are logged rather than surfaced — the optimistic
  /// local state (and the UI) is already correct either way, and the
  /// live listener above will reconcile with whatever Firestore actually
  /// ends up holding.
  Future<void> _pendingWrites = Future<void>.value();

  void _persist(Future<void> Function(CloudStore cloud) write) {
    final cloud = _cloud;
    if (cloud == null) return;
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        await write(cloud);
      } catch (error) {
        _logError(error);
      }
    });
  }

  /// Waits for every write issued so far to finish. Production never
  /// awaits this — the UI never blocks on a write — but it gives tests a
  /// real point to synchronize on.
  @visibleForTesting
  Future<void> flushPersistence() => _pendingWrites;

  @override
  void dispose() {
    _clientsSub?.cancel();
    _packagesSub?.cancel();
    _visitsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  // ── The dietitian's own account ──────────────────────────────────────

  String _dietitianName = PracticeProfile.dietitianName;

  /// Her name as she has set it — the default from [PracticeProfile]
  /// until she edits it on حسابي, after which it lives in Firestore
  /// beside her data and follows her to every device.
  String get dietitianName => _dietitianName;

  /// Just the given name, for greeting her directly.
  String get dietitianFirstName => PracticeProfile.firstNameOf(_dietitianName);

  String get dietitianByline => '$_dietitianName · ${PracticeProfile.title}';

  /// The address she signs in with; null in tests, where there is no account.
  String? get accountEmail => _auth?.currentUser?.email;

  void updateDietitianName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _dietitianName) return;
    _dietitianName = trimmed;
    _persist((cloud) => cloud.saveDietitianName(trimmed));
    notifyListeners();
  }

  /// Changes the account password. Firebase requires a recent sign-in for
  /// this, so the current password is re-submitted here rather than
  /// bouncing her out to the login screen and back.
  ///
  /// Throws [FirebaseAuthException] on a wrong current password, a weak
  /// new one, or no connection; the caller turns the code into a message.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth?.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account to change the password of.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
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

  /// Every visit a client has ever had, most recent first — the record
  /// her file shows, day by day, across all her packages.
  List<Visit> visitsForClient(String clientId) =>
      _visits.where((v) => v.clientId == clientId).toList()
        ..sort((a, b) => _byScheduleThenIndex(b, a));

  /// Every payment a client has made, most recent first.
  List<Payment> paymentsFor(String clientId) => [
        for (final pkg in _packages.where((p) => p.clientId == clientId)) ...pkg.payments,
      ]..sort((a, b) => b.date.compareTo(a.date));

  /// Her most recent payment, or null if she has never paid anything.
  Payment? lastPaymentFor(String clientId) => paymentsFor(clientId).firstOrNull;

  /// Removes a payment recorded by mistake — a wrong amount, or one
  /// entered against the wrong client. The balance goes straight back up
  /// by what the payment was worth, and the month's revenue back down.
  void deletePayment({required String packageId, required String paymentId}) {
    final index = _packages.indexWhere((p) => p.id == packageId);
    if (index < 0) return;
    final pkg = _packages[index];
    final remaining = pkg.payments.where((p) => p.id != paymentId).toList();
    if (remaining.length == pkg.payments.length) return;

    _packages[index] = pkg.copyWith(payments: remaining);
    _persist((cloud) => cloud.updatePackage(_packages[index]));
    notifyListeners();
  }

  int attendedCount(String packageId) => _visits
      .where((v) => v.packageId == packageId && v.status == VisitStatus.attended)
      .length;

  int resolvedCount(String packageId) =>
      _visits.where((v) => v.packageId == packageId && v.isResolved).length;

  int noShowCount(String packageId) => _visits
      .where((v) => v.packageId == packageId && v.status == VisitStatus.noShow)
      .length;

  /// Visits still to be used up — what the "N متبقية" badge counts.
  ///
  /// Only a visit she actually attended spends one. A لم تحضر is recorded
  /// and stays visible in her file, but it costs the client nothing: she
  /// paid for four visits and still has four coming.
  int remainingVisits(String packageId) {
    final pkg = package(packageId);
    return (pkg.visitCount - attendedCount(packageId)).clamp(0, pkg.visitCount);
  }

  /// Remaining visits across a client's running package; 0 when idle.
  int remainingForClient(String clientId) {
    final active = activePackage(clientId);
    return active == null ? 0 : remainingVisits(active.id);
  }

  /// A package is done when its visits have all been *attended* — see
  /// [remainingVisits] for why a no-show doesn't count toward it.
  bool isPackageComplete(String packageId) =>
      attendedCount(packageId) >= package(packageId).visitCount;

  /// Which of the package's visits this one is — "الزيارة ٣ من ٤".
  ///
  /// Counted by attendance, not by the slot the visit was booked into: a
  /// missed appointment leaves the count where it was, so the next one
  /// she attends is still the third of four. Returns null for a no-show,
  /// which occupies no number at all.
  int? visitNumber(Visit visit) {
    switch (visit.status) {
      case VisitStatus.noShow:
        return null;
      case VisitStatus.attended:
        final attended = _visits
            .where((v) => v.packageId == visit.packageId && v.status == VisitStatus.attended)
            .toList()
          ..sort(_byScheduleThenIndex);
        return attended.indexWhere((v) => v.id == visit.id) + 1;
      case VisitStatus.scheduled:
        // The number it would take if she attends it.
        return attendedCount(visit.packageId) + 1;
    }
  }

  static int _byScheduleThenIndex(Visit a, Visit b) {
    final byDate = a.scheduledAt.compareTo(b.scheduledAt);
    return byDate != 0 ? byDate : a.index.compareTo(b.index);
  }

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
      outstandingPackages.fold(0.0, (total, p) => total + p.balanceDue);

  double balanceDueFor(String clientId) => _packages
      .where((p) => p.clientId == clientId)
      .fold(0.0, (total, p) => total + p.balanceDue);

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
  //
  // Every mutation updates the in-memory lists immediately, the same way
  // regardless of whether this store is cloud-backed, so the UI never
  // waits on a network round-trip to feel like it responded. In cloud
  // mode the matching write is also queued; the live listener above will
  // confirm it (or, rarely, correct it) once Firestore's own local cache
  // reflects the change — visually a no-op, since it's the same data.

  /// Records a visit outcome. Attending the last visit of a package
  /// closes the package and queues the celebration.
  ///
  /// [celebrate] is off when the change is a *correction* — fixing a
  /// wrongly-marked attendance from the client file, where a party popper
  /// over a bookkeeping fix would be beside the point.
  void markVisit(String visitId, VisitStatus status, {bool celebrate = true}) =>
      _setVisitStatus(visitId, status, celebrate: celebrate);

  /// Undoes a حضرت / لم تحضر decision, putting the visit back to
  /// "not recorded yet" and reopening the package if that decision was
  /// the one that closed it.
  void undoVisit(String visitId) =>
      _setVisitStatus(visitId, VisitStatus.scheduled, celebrate: false);

  /// The one place a visit's outcome changes — marking it, undoing it, or
  /// correcting it later all land here, so the package it belongs to is
  /// opened and closed by the same rule every time. Changing an attended
  /// visit back to a no-show, say, reopens a package that this visit had
  /// closed; nothing needs to remember that it was the one that closed it.
  void _setVisitStatus(String visitId, VisitStatus status, {required bool celebrate}) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits[index];
    if (visit.status == status) return;
    _visits[index] = visit.copyWith(status: status);

    final changedPackage = _reconcilePackage(visit.packageId, celebrate: celebrate);
    _persist((cloud) => cloud.updateVisitAndPackage(_visits[index], changedPackage));
    notifyListeners();
  }

  /// Brings a package's open/closed state back in line with how many of
  /// its visits have actually been attended, and returns it if that
  /// changed anything. Every path that can move the attended count —
  /// marking, correcting, deleting or reassigning a visit — goes through
  /// here, so none of them has to reason about it separately.
  ClientPackage? _reconcilePackage(String packageId, {bool celebrate = false}) {
    final pkgIndex = _packages.indexWhere((p) => p.id == packageId);
    if (pkgIndex < 0) return null;
    final pkg = _packages[pkgIndex];
    final complete = isPackageComplete(pkg.id);

    ClientPackage? changed;
    if (complete && pkg.isActive) {
      _packages[pkgIndex] = pkg.copyWith(endDate: now);
      changed = _packages[pkgIndex];
      if (celebrate) pendingCelebration = changed;
    } else if (!complete && !pkg.isActive) {
      _packages[pkgIndex] = pkg.copyWith(clearEndDate: true);
      changed = _packages[pkgIndex];
    }
    if (!complete && pendingCelebration?.id == pkg.id) pendingCelebration = null;
    return changed;
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
    _persist((cloud) => cloud.updatePackage(_packages[index]));
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
    _persist((cloud) => cloud.insertPackage(pkg));

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
    _persist((cloud) => cloud.insertVisits(newVisits));

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
    _persist((cloud) => cloud.insertClient(client));
    notifyListeners();
    return client;
  }

  /// Corrects a client's details. Only the fields passed change, so
  /// editing a phone number can't quietly blank an age.
  void updateClient(
    String id, {
    String? name,
    String? phone,
    int? age,
  }) {
    final index = _clients.indexWhere((c) => c.id == id);
    if (index < 0) return;
    _clients[index] = _clients[index].copyWith(
      name: name?.trim(),
      phone: phone?.trim(),
      age: age,
    );
    _persist((cloud) => cloud.updateClient(_clients[index]));
    notifyListeners();
  }

  /// Removes a client and everything hanging off her — her packages,
  /// their payments (which live inside the package documents) and every
  /// visit. Leaving those behind would keep her money in the dashboard's
  /// totals and her appointments on the schedule long after she is gone.
  void deleteClient(String id) {
    final packageIds = _packages.where((p) => p.clientId == id).map((p) => p.id).toList();
    final visitIds = _visits.where((v) => v.clientId == id).map((v) => v.id).toList();

    _clients.removeWhere((c) => c.id == id);
    _packages.removeWhere((p) => p.clientId == id);
    _visits.removeWhere((v) => v.clientId == id);
    if (packageIds.contains(pendingCelebration?.id)) pendingCelebration = null;

    _persist((cloud) => cloud.deleteClient(
          clientId: id,
          packageIds: packageIds,
          visitIds: visitIds,
        ));
    notifyListeners();
  }

  // ── The schedule ─────────────────────────────────────────────────────
  //
  // An appointment is a [Visit] against a package the client has already
  // bought, so scheduling one always needs a running package to hang it
  // on — that is what [canSchedule] answers before the sheet lets her
  // pick someone.

  /// Whether an appointment can be booked for this client at all: she
  /// needs a package that is still running.
  bool canSchedule(String clientId) => activePackage(clientId) != null;

  /// Clients an appointment can be booked for, by name.
  List<Client> get schedulableClients =>
      _clients.where((c) => canSchedule(c.id)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Books an appointment against the client's running package. Returns
  /// null — booking nothing — when she has no package to book against.
  Visit? scheduleVisit({required String clientId, required DateTime at}) {
    final active = activePackage(clientId);
    if (active == null) return null;
    final visit = Visit(
      id: _nextId('visit'),
      clientId: clientId,
      packageId: active.id,
      index: _nextIndexIn(active.id),
      scheduledAt: at,
    );
    _visits.add(visit);
    _persist((cloud) => cloud.insertVisit(visit));
    notifyListeners();
    return visit;
  }

  /// Moves an appointment: a new time, a new day, a different client, or
  /// any combination. Returns false when it asked for a client with no
  /// running package to move it to, in which case nothing changes.
  bool rescheduleVisit(String visitId, {DateTime? at, String? clientId}) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return false;
    final visit = _visits[index];

    final movingToNewClient = clientId != null && clientId != visit.clientId;
    ClientPackage? target;
    if (movingToNewClient) {
      target = activePackage(clientId);
      if (target == null) return false;
    }

    _visits[index] = visit.copyWith(
      scheduledAt: at,
      clientId: movingToNewClient ? clientId : null,
      packageId: movingToNewClient ? target!.id : null,
      index: movingToNewClient ? _nextIndexIn(target!.id) : null,
    );
    _persist((cloud) => cloud.updateVisit(_visits[index]));

    // Both packages can change state when an attended visit moves
    // between them: the one it left may reopen, the one it joined may
    // close. Neither is a moment to celebrate — she is fixing a booking.
    final changedTargets = <ClientPackage?>[
      _reconcilePackage(visit.packageId),
      if (movingToNewClient) _reconcilePackage(target!.id),
    ];
    for (final pkg in changedTargets.nonNulls) {
      _persist((cloud) => cloud.updatePackage(pkg));
    }

    notifyListeners();
    return true;
  }

  /// Cancels an appointment outright — she booked it by mistake, or it
  /// will never happen. Deleting one she had marked حضرت gives that
  /// visit back to the package, reopening it if it had been closed.
  void deleteVisit(String visitId) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits.removeAt(index);
    _persist((cloud) => cloud.deleteVisit(visitId));

    final changed = _reconcilePackage(visit.packageId);
    if (changed != null) _persist((cloud) => cloud.updatePackage(changed));
    notifyListeners();
  }

  /// The next free slot number in a package — appointments booked beyond
  /// the ones sold with it keep counting up rather than colliding.
  int _nextIndexIn(String packageId) {
    final existing = visitsForPackage(packageId);
    return existing.isEmpty ? 1 : existing.last.index + 1;
  }

  /// Days in [month] that have at least one appointment — the dots on
  /// the calendar grid.
  Set<int> scheduledDaysIn(DateTime month) => {
        for (final visit in _visits)
          if (visit.scheduledAt.year == month.year &&
              visit.scheduledAt.month == month.month)
            visit.scheduledAt.day,
      };

  /// Appointments still to happen, soonest first — what "القادمة" lists.
  List<Visit> get upcomingVisits {
    final today = DateTime(now.year, now.month, now.day);
    return _visits
        .where((v) => !v.isResolved && !v.scheduledAt.isBefore(today))
        .toList()
      ..sort(_byScheduleThenIndex);
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
