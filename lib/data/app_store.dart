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
/// Everything the UI shows is derived from three lists: clients, their
/// appointments, and the money they have paid. Screens only ever talk to
/// this class, never to [CloudStore] or [SampleData] directly.
///
/// ## How visits and money relate
///
/// They don't, directly — and that is the point. An appointment is booked
/// against a client, not against a package she may not have bought yet;
/// the real order of events is *book, come, then pay*. Money is a running
/// balance: every four visits she attends costs one package, and whatever
/// she has handed over is set against that. So being one package behind,
/// or two, or half of one, is just a number — there is no package record
/// left in an awkward state waiting to be reconciled.
class AppStore extends ChangeNotifier {
  /// In-memory only — no cloud, nothing persists or syncs. Used by tests
  /// and by demo mode.
  AppStore({SampleSeed? seed})
      : _cloud = null,
        _auth = null {
    final data = seed ?? SampleData.build();
    _clients = [...data.clients];
    _visits = [...data.visits];
    _payments = [...data.payments];
  }

  /// Backed by Firestore, scoped to one signed-in account. Starts empty
  /// — a real account gets her real data, not the sample roster — and
  /// fills in as soon as the first snapshot arrives from whichever
  /// device(s) she's already used. [auth] is only kept so [signOut] has
  /// something to call.
  AppStore.forUser(FirebaseFirestore firestore, String uid, {FirebaseAuth? auth})
      : _cloud = CloudStore(firestore, uid),
        _auth = auth {
    _clients = [];
    _visits = [];
    _payments = [];
    _subscribeToCloud();
  }

  /// The one package sold: ٤ زيارات for ١٠٠ ₪.
  ///
  /// A rate, not a record — see [packagesUsed]. Changing it changes what
  /// future arithmetic charges; it does not rewrite what is already owed,
  /// because what is already owed is recomputed from this too. Worth
  /// knowing before anyone edits the number.
  static const packageRate = PackageRate(visitCount: 4, price: 100);

  /// Null in tests and other in-memory-only instances; writes and the
  /// live subscriptions are skipped wherever this is null.
  final CloudStore? _cloud;

  final FirebaseAuth? _auth;

  /// A no-op in tests, where there's no account to sign out of. AuthGate
  /// is listening for the resulting auth-state change and takes it from
  /// there — this store doesn't navigate anywhere itself.
  void signOut() => _auth?.signOut();

  StreamSubscription<List<Client>>? _clientsSub;
  StreamSubscription<List<Visit>>? _visitsSub;
  StreamSubscription<List<Payment>>? _paymentsSub;
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
    _visitsSub = cloud.watchVisits().listen((visits) {
      _visits = visits;
      notifyListeners();
    }, onError: _logError);
    _paymentsSub = cloud.watchPayments().listen((payments) {
      _payments = payments;
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
  late List<Visit> _visits;
  late List<Payment> _payments;

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
    _visitsSub?.cancel();
    _paymentsSub?.cancel();
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

  // ── Reading ──────────────────────────────────────────────────────────

  /// Set when marking a visit finishes a client's four, so the Today
  /// screen can raise the celebration. The UI clears it once shown.
  String? pendingCelebrationClientId;

  List<Client> get clients => List.unmodifiable(_clients);
  List<Visit> get visits => List.unmodifiable(_visits);
  List<Payment> get payments => List.unmodifiable(_payments);

  DateTime get now => DateTime.now();

  Client client(String id) => _clients.firstWhere((c) => c.id == id);

  Client? clientOrNull(String id) {
    for (final c in _clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  Visit visit(String id) => _visits.firstWhere((v) => v.id == id);

  Visit? visitOrNull(String id) {
    for (final v in _visits) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Every appointment a client has, most recent first — the record her
  /// file shows, day by day.
  List<Visit> visitsForClient(String clientId) =>
      _visits.where((v) => v.clientId == clientId).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  /// Her attended visits, oldest first — the order they count in.
  List<Visit> _attendedFor(String clientId) =>
      _visits.where((v) => v.clientId == clientId && v.status == VisitStatus.attended).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  /// Every payment a client has made, most recent first.
  List<Payment> paymentsFor(String clientId) =>
      _payments.where((p) => p.clientId == clientId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Her most recent payment, or null if nothing has been recorded here.
  /// Money carried in as [Client.priorPaid] has no date and so is not a
  /// candidate — "آخر دفعة" means one this app watched happen.
  Payment? lastPaymentFor(String clientId) => paymentsFor(clientId).firstOrNull;

  // ── Counting visits ──────────────────────────────────────────────────

  /// Visits she has actually attended, including any carried in with her.
  /// The only number the money is derived from: a لم تحضر is recorded and
  /// stays visible, but it costs her nothing.
  int attendedCount(String clientId) {
    final client = clientOrNull(clientId);
    return (client?.priorVisits ?? 0) + _attendedFor(clientId).length;
  }

  int noShowCount(String clientId) =>
      _visits.where((v) => v.clientId == clientId && v.status == VisitStatus.noShow).length;

  int get _perPackage => packageRate.visitCount;

  /// How many packages her attendance has consumed — the first visit
  /// starts a package, the fifth starts the second one.
  int packagesUsed(String clientId) => (attendedCount(clientId) / _perPackage).ceil();

  /// Which visit of the current package her most recent one was: 1–4, or
  /// 0 before she has attended anything.
  int visitInPackage(String clientId) {
    final attended = attendedCount(clientId);
    return attended == 0 ? 0 : ((attended - 1) % _perPackage) + 1;
  }

  /// Visits left in the package she is part-way through. Zero means she
  /// has just used the fourth — the next visit starts a new package, and
  /// a new ١٠٠ ₪.
  int remainingVisits(String clientId) {
    final attended = attendedCount(clientId);
    return attended == 0 ? _perPackage : _perPackage - visitInPackage(clientId);
  }

  /// Kept for the screens that read it as "how many left".
  int remainingForClient(String clientId) => remainingVisits(clientId);

  /// She has finished a package and not started the next: the moment to
  /// ask for the next ١٠٠ ₪.
  bool clientNeedsRenewal(String clientId) =>
      attendedCount(clientId) > 0 && remainingVisits(clientId) == 0;

  /// Which visit of its package this one is — "الزيارة ٣ من ٤".
  ///
  /// Counted by attendance in date order, so a missed appointment leaves
  /// the count where it was and the next one she attends keeps the number
  /// the missed one would have had. Null for a no-show, which occupies no
  /// number at all.
  int? visitNumber(Visit visit) {
    switch (visit.status) {
      case VisitStatus.noShow:
        return null;
      case VisitStatus.attended:
        final attended = _attendedFor(visit.clientId);
        final position = attended.indexWhere((v) => v.id == visit.id);
        if (position < 0) return null;
        final prior = clientOrNull(visit.clientId)?.priorVisits ?? 0;
        return ((prior + position) % _perPackage) + 1;
      case VisitStatus.scheduled:
        // The number it would take if she attends it.
        return (attendedCount(visit.clientId) % _perPackage) + 1;
    }
  }

  // ── The schedule ─────────────────────────────────────────────────────

  List<Visit> visitsOn(DateTime day) {
    final result = _visits.where((v) => ArabicDates.isSameDay(v.scheduledAt, day)).toList();
    result.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return result;
  }

  /// Today's visits with the pending ones first, so whoever is still to
  /// be marked is at the top.
  List<Visit> get todayVisits {
    final all = visitsOn(now);
    return [
      ...all.where((v) => !v.isResolved),
      ...all.where((v) => v.isResolved),
    ];
  }

  /// Days in [month] that have at least one appointment — the dots on
  /// the calendar grid.
  Set<int> scheduledDaysIn(DateTime month) => {
        for (final visit in _visits)
          if (visit.scheduledAt.year == month.year && visit.scheduledAt.month == month.month)
            visit.scheduledAt.day,
      };

  /// Appointments still to happen, soonest first.
  List<Visit> get upcomingVisits {
    final today = DateTime(now.year, now.month, now.day);
    return _visits.where((v) => !v.isResolved && !v.scheduledAt.isBefore(today)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  // ── Money ────────────────────────────────────────────────────────────

  /// What her visits have cost so far: one package per four attended.
  double amountChargedFor(String clientId) => packagesUsed(clientId) * packageRate.price;

  /// Everything she has handed over, including anything carried in.
  double amountPaidFor(String clientId) {
    final client = clientOrNull(clientId);
    return (client?.priorPaid ?? 0) +
        _payments.where((p) => p.clientId == clientId).fold(0.0, (total, p) => total + p.amount);
  }

  /// What she owes. Paying ahead shows as nothing owed rather than a
  /// negative — a credit is real, but "−٥٠ ₪ مستحق" reads as a bug.
  double balanceDueFor(String clientId) {
    final due = amountChargedFor(clientId) - amountPaidFor(clientId);
    return due <= 0 ? 0 : due;
  }

  /// How many packages behind she is — 0, 1, or occasionally 2.
  int packagesOwedBy(String clientId) =>
      (balanceDueFor(clientId) / packageRate.price).ceil();

  /// Clients carrying a balance, largest first.
  List<Client> get outstandingClients => _clients.where((c) => balanceDueFor(c.id) > 0).toList()
    ..sort((a, b) => balanceDueFor(b.id).compareTo(balanceDueFor(a.id)));

  double get totalOutstanding =>
      _clients.fold(0.0, (total, c) => total + balanceDueFor(c.id));

  /// Only dated payments count toward a month's revenue; money carried in
  /// with a client predates the records and belongs to no month here.
  double revenueForMonth(DateTime month) => _payments
      .where((p) => p.date.year == month.year && p.date.month == month.month)
      .fold(0.0, (total, p) => total + p.amount);

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

  /// Clients who have just used their fourth visit, most recently first.
  List<Client> get needsRenewal {
    final result = _clients.where((c) => clientNeedsRenewal(c.id)).toList();
    result.sort((a, b) {
      final aLast = _attendedFor(a.id).lastOrNull?.scheduledAt ?? a.startDate;
      final bLast = _attendedFor(b.id).lastOrNull?.scheduledAt ?? b.startDate;
      return bLast.compareTo(aLast);
    });
    return result;
  }

  /// Whoever the payment screen should offer first: the client owing the
  /// most.
  Client? get paymentCandidate => outstandingClients.firstOrNull;

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
  // confirm it once Firestore's own local cache reflects the change.

  /// Adds a client, optionally one who is already part-way through:
  /// [priorVisits] she has attended and [priorPaid] she has handed over
  /// before any of it was being recorded here.
  Client addClient({
    required String name,
    required String phone,
    int age = 0,
    int priorVisits = 0,
    double priorPaid = 0,
  }) {
    final client = Client(
      id: _nextId('client'),
      name: name.trim(),
      phone: phone.trim(),
      age: age,
      startDate: now,
      priorVisits: priorVisits < 0 ? 0 : priorVisits,
      priorPaid: priorPaid < 0 ? 0 : priorPaid,
    );
    _clients.add(client);
    _persist((cloud) => cloud.upsertClient(client));
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
    int? priorVisits,
    double? priorPaid,
  }) {
    final index = _clients.indexWhere((c) => c.id == id);
    if (index < 0) return;
    _clients[index] = _clients[index].copyWith(
      name: name?.trim(),
      phone: phone?.trim(),
      age: age,
      priorVisits: priorVisits == null ? null : (priorVisits < 0 ? 0 : priorVisits),
      priorPaid: priorPaid == null ? null : (priorPaid < 0 ? 0 : priorPaid),
    );
    _persist((cloud) => cloud.upsertClient(_clients[index]));
    notifyListeners();
  }

  /// Removes a client and everything of hers — her appointments and her
  /// payments. Leaving those behind would keep her money in the
  /// dashboard's totals and her appointments on the schedule.
  void deleteClient(String id) {
    final visitIds = _visits.where((v) => v.clientId == id).map((v) => v.id).toList();
    final paymentIds = _payments.where((p) => p.clientId == id).map((p) => p.id).toList();

    _clients.removeWhere((c) => c.id == id);
    _visits.removeWhere((v) => v.clientId == id);
    _payments.removeWhere((p) => p.clientId == id);
    if (pendingCelebrationClientId == id) pendingCelebrationClientId = null;

    _persist((cloud) => cloud.deleteClient(
          clientId: id,
          visitIds: visitIds,
          paymentIds: paymentIds,
        ));
    notifyListeners();
  }

  /// Books an appointment — or records one that already happened, by
  /// passing a [status] and a date in the past. Nothing has to be bought
  /// first: an appointment belongs to the client, not to a package.
  Visit scheduleVisit({
    required String clientId,
    required DateTime at,
    VisitStatus status = VisitStatus.scheduled,
  }) {
    final visit = Visit(
      id: _nextId('visit'),
      clientId: clientId,
      scheduledAt: at,
      status: status,
    );
    _visits.add(visit);
    _persist((cloud) => cloud.upsertVisit(visit));
    notifyListeners();
    return visit;
  }

  /// Moves or re-files an appointment: a new time, a new day, a different
  /// client, a corrected outcome, or any combination.
  void updateVisit(
    String visitId, {
    DateTime? at,
    String? clientId,
    VisitStatus? status,
  }) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    _visits[index] = _visits[index].copyWith(
      scheduledAt: at,
      clientId: clientId,
      status: status,
    );
    _persist((cloud) => cloud.upsertVisit(_visits[index]));
    notifyListeners();
  }

  /// Cancels an appointment outright — booked by mistake, or it will
  /// never happen. If it was marked حضرت, that visit stops counting and
  /// her balance falls by the same arithmetic that raised it.
  void deleteVisit(String visitId) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits.removeAt(index);
    if (pendingCelebrationClientId == visit.clientId &&
        !clientNeedsRenewal(visit.clientId)) {
      pendingCelebrationClientId = null;
    }
    _persist((cloud) => cloud.deleteVisit(visitId));
    notifyListeners();
  }

  /// Records an outcome. Attending the fourth visit of a package queues
  /// the celebration.
  ///
  /// [celebrate] is off when the change is a *correction* — fixing a
  /// wrongly-marked attendance from the client file, where a party popper
  /// over a bookkeeping fix would be beside the point.
  void markVisit(String visitId, VisitStatus status, {bool celebrate = true}) {
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index < 0) return;
    final visit = _visits[index];
    if (visit.status == status) return;
    _visits[index] = visit.copyWith(status: status);

    if (celebrate &&
        status == VisitStatus.attended &&
        clientNeedsRenewal(visit.clientId)) {
      pendingCelebrationClientId = visit.clientId;
    } else if (!clientNeedsRenewal(visit.clientId) &&
        pendingCelebrationClientId == visit.clientId) {
      pendingCelebrationClientId = null;
    }

    _persist((cloud) => cloud.upsertVisit(_visits[index]));
    notifyListeners();
  }

  /// Puts a visit back to "not recorded yet".
  void undoVisit(String visitId) =>
      markVisit(visitId, VisitStatus.scheduled, celebrate: false);

  void consumeCelebration() {
    pendingCelebrationClientId = null;
  }

  /// Records money received. Not capped: she can pay two packages' worth
  /// at once, or hand over more than she owes and carry the credit.
  Payment recordPayment({
    required String clientId,
    required double amount,
    required PaymentMethod method,
    DateTime? date,
  }) {
    final payment = Payment(
      id: _nextId('pay'),
      clientId: clientId,
      amount: amount <= 0 ? 0 : amount,
      method: method,
      date: date ?? now,
    );
    _payments.add(payment);
    _persist((cloud) => cloud.upsertPayment(payment));
    notifyListeners();
    return payment;
  }

  /// Corrects a payment — a wrong amount, a wrong method, a wrong date.
  void updatePayment(
    String paymentId, {
    double? amount,
    PaymentMethod? method,
    DateTime? date,
  }) {
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index < 0) return;
    _payments[index] = _payments[index].copyWith(
      amount: amount == null ? null : (amount <= 0 ? 0 : amount),
      method: method,
      date: date,
    );
    _persist((cloud) => cloud.upsertPayment(_payments[index]));
    notifyListeners();
  }

  /// Removes a payment recorded by mistake. The balance goes straight
  /// back up by what it was worth, and the month's revenue back down.
  void deletePayment(String paymentId) {
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index < 0) return;
    _payments.removeAt(index);
    _persist((cloud) => cloud.deletePayment(paymentId));
    notifyListeners();
  }
}

/// The filter chips on العميلات.
enum ClientFilter {
  all('الكل'),
  needsRenewal('تحتاج تجديد'),
  balanceDue('رصيد مستحق');

  const ClientFilter(this.label);
  final String label;
}
