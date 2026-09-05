import 'package:flutter_test/flutter_test.dart';
import 'package:taghdiya/data/app_store.dart';
import 'package:taghdiya/data/sample_data.dart';
import 'package:taghdiya/models/models.dart';
import 'package:taghdiya/utils/formatting.dart';

void main() {
  late AppStore store;

  setUp(() => store = AppStore());

  group('sample data', () {
    test('seeds the roster the mockups describe', () {
      expect(store.clients.length, 24);
      expect(
        store.clients.map((c) => c.name),
        containsAll(<String>[
          'نور خالد',
          'هبة منصور',
          'ريم عبد الله',
          'سلمى يوسف',
          'لمى صبري',
          'أمل حجازي',
          'دعاء شاهين',
        ]),
      );
    });

    test('today holds the four featured visits, pending ones first', () {
      final today = store.todayVisits;
      expect(today.length, 4);
      expect(today.take(2).every((v) => !v.isResolved), isTrue);
      expect(today.skip(2).every((v) => v.isResolved), isTrue);
    });

    test('outstanding balances total ٣٠٠ ₪ across three clients', () {
      expect(store.totalOutstanding, 300);
      expect(store.outstandingClients.map((c) => c.name),
          containsAll(<String>['نور خالد', 'لمى صبري', 'أمل حجازي']));
      expect(store.outstandingClients.length, 3);
    });

    test('renewals list clients who have just used their fourth visit', () {
      final names = store.needsRenewal.map((c) => c.name);
      expect(names, containsAll(<String>['سلمى يوسف', 'دعاء شاهين']));
      for (final client in store.needsRenewal) {
        expect(store.remainingVisits(client.id), 0);
        expect(store.attendedCount(client.id), greaterThan(0));
      }
    });

    test('revenue trend covers six months ending this month', () {
      final trend = store.revenueTrend;
      final now = DateTime.now();
      expect(trend.length, 6);
      expect(trend.last.month.month, now.month);
      expect(trend.last.month.year, now.year);
      expect(trend.every((m) => m.revenue > 0), isTrue);
    });

    test('no generated client steals a slot on today', () {
      for (final visit in store.todayVisits) {
        expect(visit.clientId.startsWith('c-other'), isFalse);
      }
    });
  });

  group('counting visits', () {
    Visit nourVisitToday() => store.todayVisits.firstWhere((v) => v.clientId == 'c-nour');

    test('every four attended visits costs one package', () {
      // نور has been three times and paid nothing.
      expect(store.attendedCount('c-nour'), 3);
      expect(store.packagesUsed('c-nour'), 1);
      expect(store.amountChargedFor('c-nour'), 100);
      expect(store.balanceDueFor('c-nour'), 100);
      expect(store.visitInPackage('c-nour'), 3);
      expect(store.remainingVisits('c-nour'), 1);
    });

    test('the fifth visit starts a second package, and a second ١٠٠ ₪', () {
      // لمى has been five times and paid for one package.
      expect(store.attendedCount('c-lama'), 5);
      expect(store.packagesUsed('c-lama'), 2);
      expect(store.amountChargedFor('c-lama'), 200);
      expect(store.amountPaidFor('c-lama'), 100);
      expect(store.balanceDueFor('c-lama'), 100);
      expect(store.packagesOwedBy('c-lama'), 1);
      // And she is one visit into the new package, not finished with it.
      expect(store.visitInPackage('c-lama'), 1);
      expect(store.remainingVisits('c-lama'), 3);
    });

    test('attending the fourth finishes the package and asks for the next', () {
      final visit = nourVisitToday();
      expect(store.clientNeedsRenewal('c-nour'), isFalse);

      store.markVisit(visit.id, VisitStatus.attended);

      expect(store.attendedCount('c-nour'), 4);
      expect(store.remainingVisits('c-nour'), 0);
      expect(store.clientNeedsRenewal('c-nour'), isTrue);
      expect(store.pendingCelebrationClientId, 'c-nour');
      // Still one package used — the fifth visit is what starts the next.
      expect(store.packagesUsed('c-nour'), 1);
      expect(store.balanceDueFor('c-nour'), 100);
    });

    test('a no-show costs the package nothing', () {
      final visit = nourVisitToday();
      store.markVisit(visit.id, VisitStatus.noShow);

      expect(store.attendedCount('c-nour'), 3);
      expect(store.noShowCount('c-nour'), 1);
      expect(store.remainingVisits('c-nour'), 1);
      expect(store.balanceDueFor('c-nour'), 100);
      expect(store.pendingCelebrationClientId, isNull);
      expect(store.clientNeedsRenewal('c-nour'), isFalse);
    });

    test('a no-show does not advance the visit number', () {
      final visit = nourVisitToday();
      expect(store.visitNumber(visit), 4);

      store.markVisit(visit.id, VisitStatus.noShow);
      expect(store.visitNumber(store.visit(visit.id)), isNull);

      // The next appointment is still the fourth of four.
      final next = store.scheduleVisit(
        clientId: 'c-nour',
        at: DateTime.now().add(const Duration(days: 7)),
      );
      expect(store.visitNumber(next), 4);
    });

    test('correcting an attendance back gives the visit to the package', () {
      final visit = nourVisitToday();
      store.markVisit(visit.id, VisitStatus.attended);
      expect(store.remainingVisits('c-nour'), 0);

      store.markVisit(visit.id, VisitStatus.noShow, celebrate: false);

      expect(store.attendedCount('c-nour'), 3);
      expect(store.remainingVisits('c-nour'), 1);
      expect(store.clientNeedsRenewal('c-nour'), isFalse);
      expect(store.pendingCelebrationClientId, isNull);
    });

    test('a correction never raises the celebration', () {
      final visit = nourVisitToday();
      store.markVisit(visit.id, VisitStatus.attended, celebrate: false);

      expect(store.remainingVisits('c-nour'), 0);
      expect(store.pendingCelebrationClientId, isNull);
    });

    test('undo puts the visit back to unrecorded', () {
      final visit = nourVisitToday();
      store.markVisit(visit.id, VisitStatus.attended);
      store.undoVisit(visit.id);

      expect(store.visit(visit.id).status, VisitStatus.scheduled);
      expect(store.attendedCount('c-nour'), 3);
      expect(store.pendingCelebrationClientId, isNull);
    });
  });

  group('a client who was already coming', () {
    test('prior visits and payments count from the first day', () {
      final client = store.addClient(
        name: 'سناء قدري',
        phone: '0521119876',
        priorVisits: 3,
        priorPaid: 100,
      );

      expect(store.attendedCount(client.id), 3);
      expect(store.visitInPackage(client.id), 3);
      expect(store.remainingVisits(client.id), 1);
      expect(store.balanceDueFor(client.id), 0);

      // Her first visit here is the fourth of the package she is on.
      final visit = store.scheduleVisit(clientId: client.id, at: DateTime.now());
      expect(store.visitNumber(visit), 4);

      store.markVisit(visit.id, VisitStatus.attended);
      expect(store.attendedCount(client.id), 4);
      expect(store.clientNeedsRenewal(client.id), isTrue);
      expect(store.balanceDueFor(client.id), 0);
    });

    test('a history behind on payment shows as owing from the start', () {
      final client = store.addClient(
        name: 'ندى سالم',
        phone: '0529998888',
        priorVisits: 6,
      );

      expect(store.packagesUsed(client.id), 2);
      expect(store.balanceDueFor(client.id), 200);
      expect(store.packagesOwedBy(client.id), 2);
    });

    test('the history is editable afterwards', () {
      final client = store.addClient(name: 'ريما', phone: '0521112222', priorVisits: 2);
      expect(store.attendedCount(client.id), 2);

      store.updateClient(client.id, priorVisits: 3);

      expect(store.attendedCount(client.id), 3);
      expect(store.client(client.id).name, 'ريما');
    });

    test('negative history is refused rather than stored', () {
      final client = store.addClient(
        name: 'هند',
        phone: '0523334444',
        priorVisits: -4,
        priorPaid: -50,
      );
      expect(store.attendedCount(client.id), 0);
      expect(store.amountPaidFor(client.id), 0);
    });
  });

  group('money', () {
    test('a payment reduces the balance and lands in this month revenue', () {
      final before = store.revenueForMonth(DateTime.now());
      expect(store.balanceDueFor('c-nour'), 100);

      store.recordPayment(clientId: 'c-nour', amount: 60, method: PaymentMethod.bit);

      expect(store.balanceDueFor('c-nour'), 40);
      expect(store.totalOutstanding, 240);
      expect(store.revenueForMonth(DateTime.now()), before + 60);
    });

    test('paying more than owed leaves nothing owed, not a negative', () {
      store.recordPayment(clientId: 'c-nour', amount: 500, method: PaymentMethod.cash);

      expect(store.balanceDueFor('c-nour'), 0);
      expect(store.amountPaidFor('c-nour'), 500);
    });

    test('two packages behind can be settled in one payment', () {
      final client = store.addClient(name: 'وفاء', phone: '0525556666', priorVisits: 8);
      expect(store.packagesOwedBy(client.id), 2);

      store.recordPayment(clientId: client.id, amount: 200, method: PaymentMethod.cash);

      expect(store.balanceDueFor(client.id), 0);
      expect(store.packagesOwedBy(client.id), 0);
    });

    test('a payment recorded by mistake can be taken back', () {
      final before = store.revenueForMonth(DateTime.now());
      final payment =
          store.recordPayment(clientId: 'c-nour', amount: 60, method: PaymentMethod.bit);

      store.deletePayment(payment.id);

      expect(store.balanceDueFor('c-nour'), 100);
      expect(store.revenueForMonth(DateTime.now()), before);
      expect(store.paymentsFor('c-nour').map((p) => p.id), isNot(contains(payment.id)));
    });

    test('a payment entered wrong can be corrected', () {
      final payment =
          store.recordPayment(clientId: 'c-nour', amount: 1000, method: PaymentMethod.cash);

      store.updatePayment(payment.id, amount: 100, method: PaymentMethod.transfer);

      expect(store.balanceDueFor('c-nour'), 0);
      expect(store.amountPaidFor('c-nour'), 100);
      expect(store.paymentsFor('c-nour').first.method, PaymentMethod.transfer);
    });

    test('the package rate is ٤ زيارات for ١٠٠ ₪', () {
      expect(AppStore.packageRate.visitCount, 4);
      expect(AppStore.packageRate.price, 100);
    });
  });

  group('the schedule', () {
    test('booking needs nothing bought first', () {
      // سلمى has finished her package and owes nothing — under the old
      // model there was no running package to book against, which was
      // exactly backwards: she books, then the client pays.
      final at = DateTime.now().add(const Duration(days: 2));
      final booked = store.scheduleVisit(clientId: 'c-salma', at: at);

      expect(store.visitsOn(at).map((v) => v.id), contains(booked.id));
      expect(store.visitsForClient('c-salma').map((v) => v.id), contains(booked.id));
    });

    test('a brand-new client can be booked immediately', () {
      final client = store.addClient(name: 'روان', phone: '0527778888');
      final visit = store.scheduleVisit(
        clientId: client.id,
        at: DateTime.now().add(const Duration(days: 1)),
      );

      expect(store.visitsForClient(client.id), hasLength(1));
      expect(store.visitNumber(visit), 1);
      expect(store.balanceDueFor(client.id), 0);
    });

    test('a visit that already happened can be recorded straight in', () {
      // "She came last Tuesday and I never wrote it down."
      final client = store.addClient(name: 'غادة', phone: '0524445555');
      store.scheduleVisit(
        clientId: client.id,
        at: DateTime.now().subtract(const Duration(days: 6)),
        status: VisitStatus.attended,
      );

      expect(store.attendedCount(client.id), 1);
      expect(store.balanceDueFor(client.id), 100);
    });

    test('rescheduling moves the day and the time', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at);
      final moved = DateTime(at.year, at.month, at.day + 4, 14, 45);

      store.updateVisit(booked.id, at: moved);

      expect(store.visit(booked.id).scheduledAt, moved);
      expect(store.visitsOn(moved).map((v) => v.id), contains(booked.id));
    });

    test('an appointment can be handed to a different client', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at);

      store.updateVisit(booked.id, clientId: 'c-heba');

      expect(store.visit(booked.id).clientId, 'c-heba');
      expect(store.visitsForClient('c-nour').map((v) => v.id), isNot(contains(booked.id)));
      expect(store.visitsForClient('c-heba').map((v) => v.id), contains(booked.id));
    });

    test('a recorded attendance can still be edited', () {
      final visit = store.todayVisits.firstWhere((v) => v.clientId == 'c-reem');
      expect(visit.status, VisitStatus.attended);

      final moved = DateTime.now().subtract(const Duration(days: 2));
      store.updateVisit(visit.id, at: moved, status: VisitStatus.noShow);

      expect(store.visit(visit.id).status, VisitStatus.noShow);
      expect(store.visit(visit.id).scheduledAt, moved);
    });

    test('deleting an attended appointment takes the visit back', () {
      final before = store.attendedCount('c-reem');
      final visit = store.todayVisits.firstWhere((v) => v.clientId == 'c-reem');

      store.deleteVisit(visit.id);

      expect(store.visits.map((v) => v.id), isNot(contains(visit.id)));
      expect(store.attendedCount('c-reem'), before - 1);
    });

    test('upcoming appointments skip resolved and past ones', () {
      final upcoming = store.upcomingVisits;
      final today = DateTime.now();

      expect(upcoming.every((v) => !v.isResolved), isTrue);
      for (final visit in upcoming) {
        expect(
          visit.scheduledAt.isBefore(DateTime(today.year, today.month, today.day)),
          isFalse,
        );
      }
      for (var i = 1; i < upcoming.length; i++) {
        expect(upcoming[i].scheduledAt.isBefore(upcoming[i - 1].scheduledAt), isFalse);
      }
    });

    test('scheduled days feed the calendar dots', () {
      final at = DateTime.now().add(const Duration(days: 40));
      store.scheduleVisit(clientId: 'c-nour', at: at);

      expect(store.scheduledDaysIn(at), contains(at.day));
    });
  });

  group('client records', () {
    test('editing changes only the fields given', () {
      final before = store.client('c-nour');

      store.updateClient('c-nour', name: 'نور خالد الأحمد', age: 35);

      final after = store.client('c-nour');
      expect(after.name, 'نور خالد الأحمد');
      expect(after.age, 35);
      expect(after.phone, before.phone);
      expect(after.startDate, before.startDate);
    });

    test('deleting takes her appointments and payments with her', () {
      expect(store.visitsForClient('c-nour'), isNotEmpty);
      final revenueBefore = store.revenueForMonth(DateTime.now());
      final hersThisMonth = store.paymentsFor('c-nour').where((p) {
        final now = DateTime.now();
        return p.date.year == now.year && p.date.month == now.month;
      }).fold(0.0, (total, p) => total + p.amount);

      store.deleteClient('c-nour');

      expect(store.clientOrNull('c-nour'), isNull);
      expect(store.visitsForClient('c-nour'), isEmpty);
      expect(store.paymentsFor('c-nour'), isEmpty);
      expect(store.searchClients('نور', ClientFilter.all), isEmpty);
      // Her money leaves the totals with her.
      expect(store.totalOutstanding, 200);
      expect(store.revenueForMonth(DateTime.now()), revenueBefore - hersThisMonth);
      expect(store.todayVisits.any((v) => v.clientId == 'c-nour'), isFalse);
    });

    test('the visit record runs newest first', () {
      final visits = store.visitsForClient('c-nour');
      expect(visits, isNotEmpty);
      for (var i = 1; i < visits.length; i++) {
        expect(visits[i].scheduledAt.isAfter(visits[i - 1].scheduledAt), isFalse);
      }
    });
  });

  group('the dietitian\'s own name', () {
    test('defaults to hers, and greets her by the given name', () {
      expect(store.dietitianName, 'أ. رنين دياب');
      expect(store.dietitianFirstName, 'رنين');
    });

    test('renaming carries through to the greeting and the byline', () {
      store.updateDietitianName('  د. سارة العلي  ');

      expect(store.dietitianName, 'د. سارة العلي');
      expect(store.dietitianFirstName, 'سارة');
      expect(store.dietitianByline, 'د. سارة العلي · أخصائية تغذية');
    });

    test('an empty name is refused rather than blanking her out', () {
      store.updateDietitianName('   ');
      expect(store.dietitianName, 'أ. رنين دياب');
    });
  });

  group('filters and search', () {
    test('the balance-due filter matches the outstanding clients', () {
      final due = store.searchClients('', ClientFilter.balanceDue).map((c) => c.name);
      expect(due, containsAll(<String>['نور خالد', 'لمى صبري', 'أمل حجازي']));
      expect(due.length, 3);
    });

    test('search matches on name and phone', () {
      expect(store.searchClients('نور', ClientFilter.all).single.name, 'نور خالد');
      expect(store.searchClients('0541234567', ClientFilter.all).single.name, 'نور خالد');
      expect(store.searchClients('لا أحد', ClientFilter.all), isEmpty);
    });
  });

  group('seeding is deterministic for a given day', () {
    test('two builds of the same day agree', () {
      final day = DateTime(2026, 9, 1);
      final a = AppStore(seed: SampleData.build(today: day));
      final b = AppStore(seed: SampleData.build(today: day));

      expect(a.clients.length, b.clients.length);
      expect(a.totalOutstanding, b.totalOutstanding);
      expect(a.revenueForMonth(day), b.revenueForMonth(day));
    });

    test('the featured states hold on any seeded day', () {
      for (final day in [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 15),
        DateTime(2026, 2, 28),
        DateTime(2026, 12, 31),
      ]) {
        final seeded = AppStore(seed: SampleData.build(today: day));
        expect(seeded.totalOutstanding, 300, reason: 'outstanding drifted on $day');
        expect(seeded.attendedCount('c-nour'), 3, reason: 'نور drifted on $day');
        expect(seeded.clientNeedsRenewal('c-salma'), isTrue, reason: 'سلمى drifted on $day');
      }
    });
  });

  group('formatting', () {
    test('localizes digits, decimals and currency', () {
      expect(fmtInt(2400), '٢٤٠٠');
      expect(fmtDecimal(73.8), '٧٣٫٨');
      expect(fmtCurrency(100), '١٠٠ ₪');
      expect(fmtSigned(-4.2), '−٤٫٢');
      expect(fmtSigned(-6), '−٦');
      expect(fmtSigned(1.5), '+١٫٥');
      expect(fmtSignedPercent(18), '+١٨٪');
      expect(fmtPhone('0541234567'), '٠٥٤ ١٢٣ ٤٥٦٧');
    });

    test('Western digits when the toggle is flipped', () {
      AppNumerals.useArabicIndic = false;
      addTearDown(() => AppNumerals.useArabicIndic = true);

      expect(fmtInt(2400), '2400');
      expect(fmtCurrency(100), '100 ₪');
    });

    test('Arabic plurals and dates', () {
      expect(ArabicDates.visits(1), 'زيارة واحدة');
      expect(ArabicDates.visits(2), 'زيارتان');
      expect(ArabicDates.visits(4), '٤ زيارات');
      expect(ArabicDates.visits(12), '١٢ زيارة');
      expect(ArabicDates.packages(1), 'باقة واحدة');
      expect(ArabicDates.packages(2), 'باقتين');
      expect(ArabicDates.days(21), '٢١ يوماً');
      expect(ArabicDates.dayMonth(DateTime(2026, 9, 1)), '١ سبتمبر');
      expect(ArabicDates.monthYear(DateTime(2026, 9, 1)), 'سبتمبر ٢٠٢٦');
      expect(ArabicDates.time(DateTime(2026, 9, 1, 10, 30)), '١٠:٣٠ ص');
      expect(ArabicDates.time(DateTime(2026, 9, 1, 12, 0)), '١٢:٠٠ م');
    });
  });
}
