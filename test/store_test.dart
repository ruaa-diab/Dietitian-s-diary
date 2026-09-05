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
      expect(store.outstandingPackages.length, 3);
    });

    test('renewals list only clients whose latest package has closed', () {
      final names = store.needsRenewal.map((r) => r.client.name);
      expect(names, containsAll(<String>['سلمى يوسف', 'دعاء شاهين']));
      for (final entry in store.needsRenewal) {
        expect(entry.package.isActive, isFalse);
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

  group('visit outcomes', () {
    Visit nourFinalVisit() => store.todayVisits.firstWhere(
          (v) => store.client(v.clientId).name == 'نور خالد',
        );

    test('attending the last visit closes the package and celebrates', () {
      final visit = nourFinalVisit();
      final packageId = visit.packageId;
      expect(store.package(packageId).isActive, isTrue);

      store.markVisit(visit.id, VisitStatus.attended);

      expect(store.package(packageId).isActive, isFalse);
      expect(store.pendingCelebration?.id, packageId);
      expect(store.remainingVisits(packageId), 0);
      expect(store.clientNeedsRenewal(visit.clientId), isTrue);
    });

    test('a no-show costs the package nothing', () {
      final visit = nourFinalVisit();
      store.markVisit(visit.id, VisitStatus.noShow);

      // Recorded, and visible in her file — but she paid for four visits
      // and has only had three, so the package is still running and the
      // fourth is still hers.
      expect(store.package(visit.packageId).isActive, isTrue);
      expect(store.attendedCount(visit.packageId), 3);
      expect(store.noShowCount(visit.packageId), 1);
      expect(store.remainingVisits(visit.packageId), 1);
      expect(store.pendingCelebration, isNull);
      expect(store.clientNeedsRenewal(visit.clientId), isFalse);
    });

    test('a no-show does not advance the visit number', () {
      final visit = nourFinalVisit();
      expect(store.visitNumber(visit), 4);

      store.markVisit(visit.id, VisitStatus.noShow);
      expect(store.visitNumber(store.visit(visit.id)), isNull);

      // The next appointment is still the fourth of four.
      store.scheduleVisit(
        clientId: visit.clientId,
        at: DateTime.now().add(const Duration(days: 7)),
      );
      final next = store.visitsForPackage(visit.packageId).last;
      expect(store.visitNumber(next), 4);
    });

    test('correcting an attendance to a no-show reopens the package', () {
      final visit = nourFinalVisit();
      store.markVisit(visit.id, VisitStatus.attended);
      expect(store.package(visit.packageId).isActive, isFalse);

      // "قلت إنها حضرت وتبيّن أنها لم تحضر" — the visit goes back to the
      // package, so the package is running again and she still owes it
      // one visit.
      store.markVisit(visit.id, VisitStatus.noShow, celebrate: false);

      expect(store.package(visit.packageId).isActive, isTrue);
      expect(store.remainingVisits(visit.packageId), 1);
      expect(store.pendingCelebration, isNull);
    });

    test('a correction never raises the celebration', () {
      final visit = nourFinalVisit();
      store.markVisit(visit.id, VisitStatus.attended, celebrate: false);

      expect(store.package(visit.packageId).isActive, isFalse);
      expect(store.pendingCelebration, isNull);
    });

    test('undo reopens the package', () {
      final visit = nourFinalVisit();
      store.markVisit(visit.id, VisitStatus.attended);
      store.undoVisit(visit.id);

      expect(store.package(visit.packageId).isActive, isTrue);
      expect(store.pendingCelebration, isNull);
      expect(store.remainingVisits(visit.packageId), 1);
    });
  });

  group('money', () {
    ClientPackage nourPackage() =>
        store.packagesFor('c-nour').firstWhere((p) => !p.isPaid);

    test('a payment reduces the balance and lands in this month revenue', () {
      final before = store.revenueForMonth(DateTime.now());
      final pkg = nourPackage();
      expect(pkg.balanceDue, 100);

      store.recordPayment(packageId: pkg.id, amount: 60, method: PaymentMethod.bit);

      expect(store.package(pkg.id).balanceDue, 40);
      expect(store.totalOutstanding, 240);
      expect(store.revenueForMonth(DateTime.now()), before + 60);
    });

    test('a payment recorded by mistake can be taken back', () {
      final pkg = nourPackage();
      final before = store.revenueForMonth(DateTime.now());
      store.recordPayment(packageId: pkg.id, amount: 60, method: PaymentMethod.bit);
      final payment = store.lastPaymentFor('c-nour')!;

      store.deletePayment(packageId: pkg.id, paymentId: payment.id);

      expect(store.package(pkg.id).balanceDue, 100);
      expect(store.package(pkg.id).payments.map((p) => p.id), isNot(contains(payment.id)));
      expect(store.revenueForMonth(DateTime.now()), before);
      expect(store.totalOutstanding, 300);
    });

    test('overpaying is capped at the outstanding balance', () {
      final pkg = nourPackage();
      store.recordPayment(packageId: pkg.id, amount: 500, method: PaymentMethod.cash);

      expect(store.package(pkg.id).balanceDue, 0);
      expect(store.package(pkg.id).paid, 100);
      expect(store.package(pkg.id).isPaid, isTrue);
    });
  });

  group('selling a package', () {
    test('paid in full creates visits and settles the balance', () {
      final option = AppStore.packageOptions.first;
      final pkg = store.sellPackage(
        clientId: 'c-doaa',
        option: option,
        intent: PaymentIntent.paidInFull,
        amountReceived: 0,
        method: PaymentMethod.cash,
      );

      expect(pkg.isPaid, isTrue);
      expect(pkg.balanceDue, 0);
      expect(store.visitsForPackage(pkg.id).length, option.visitCount);
      expect(store.remainingVisits(pkg.id), option.visitCount);
      expect(store.clientNeedsRenewal('c-doaa'), isFalse);
    });

    test('there is one package to sell: ٤ زيارات for ١٠٠ ₪', () {
      expect(AppStore.packageOptions, hasLength(1));
      expect(AppStore.defaultPackage.visitCount, 4);
      expect(AppStore.defaultPackage.price, 100);
    });

    test('paying later leaves the whole price outstanding', () {
      final pkg = store.sellPackage(
        clientId: 'c-doaa',
        option: AppStore.defaultPackage,
        intent: PaymentIntent.later,
        amountReceived: 150,
        method: PaymentMethod.cash,
      );

      expect(pkg.payments, isEmpty);
      expect(pkg.balanceDue, 100);
    });

    test('a partial payment records only what was received', () {
      final pkg = store.sellPackage(
        clientId: 'c-doaa',
        option: AppStore.defaultPackage,
        intent: PaymentIntent.partial,
        amountReceived: 60,
        method: PaymentMethod.transfer,
      );

      expect(pkg.paid, 60);
      expect(pkg.balanceDue, 40);
      expect(store.lastPaymentFor('c-doaa')?.amount, 60);
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

    test('deleting takes her packages, payments and visits with her', () {
      expect(store.packagesFor('c-nour'), isNotEmpty);
      expect(store.visitsForClient('c-nour'), isNotEmpty);
      final revenueBefore = store.revenueForMonth(DateTime.now());
      final herPayments = store
          .paymentsFor('c-nour')
          .where((p) => p.date.year == DateTime.now().year && p.date.month == DateTime.now().month)
          .fold(0.0, (sum, p) => sum + p.amount);

      store.deleteClient('c-nour');

      expect(store.clientOrNull('c-nour'), isNull);
      expect(store.packagesFor('c-nour'), isEmpty);
      expect(store.visitsForClient('c-nour'), isEmpty);
      expect(store.searchClients('نور', ClientFilter.all), isEmpty);
      // Her money leaves the totals with her, rather than lingering as a
      // balance owed by nobody.
      expect(store.totalOutstanding, 200);
      expect(store.revenueForMonth(DateTime.now()), revenueBefore - herPayments);
    });

    test('her visits leave today\'s schedule too', () {
      expect(
        store.todayVisits.any((v) => v.clientId == 'c-nour'),
        isTrue,
      );

      store.deleteClient('c-nour');

      expect(store.todayVisits.any((v) => v.clientId == 'c-nour'), isFalse);
    });

    test('the visit record runs newest first and covers every package', () {
      final visits = store.visitsForClient('c-nour');
      expect(visits, isNotEmpty);
      for (var i = 1; i < visits.length; i++) {
        expect(
          visits[i].scheduledAt.isAfter(visits[i - 1].scheduledAt),
          isFalse,
          reason: 'visit record is not in newest-first order',
        );
      }
      expect(
        visits.map((v) => v.packageId).toSet().length,
        store.packagesFor('c-nour').length,
      );
    });
  });

  group('the schedule', () {
    test('booking needs a running package to hang the visit on', () {
      expect(store.canSchedule('c-nour'), isTrue);
      // سلمى's package has closed, so there is nothing to book against.
      expect(store.canSchedule('c-salma'), isFalse);
      expect(
        store.scheduleVisit(
          clientId: 'c-salma',
          at: DateTime.now().add(const Duration(days: 1)),
        ),
        isNull,
      );
      expect(store.schedulableClients.map((c) => c.id), isNot(contains('c-salma')));
    });

    test('a booked appointment lands on its day and in its package', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at)!;

      expect(store.visitsOn(at).map((v) => v.id), contains(booked.id));
      expect(booked.packageId, store.activePackage('c-nour')!.id);
      expect(store.scheduledDaysIn(at), contains(at.day));
    });

    test('rescheduling moves the day and the time', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at)!;
      final moved = DateTime(at.year, at.month, at.day + 4, 14, 45);

      expect(store.rescheduleVisit(booked.id, at: moved), isTrue);

      expect(store.visit(booked.id).scheduledAt, moved);
      expect(store.visitsOn(at), isNot(contains(booked)));
      expect(store.visitsOn(moved).map((v) => v.id), contains(booked.id));
    });

    test('reassigning moves the appointment into the new client package', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at)!;
      final target = store.activePackage('c-heba')!;

      expect(store.rescheduleVisit(booked.id, clientId: 'c-heba'), isTrue);

      final moved = store.visit(booked.id);
      expect(moved.clientId, 'c-heba');
      expect(moved.packageId, target.id);
      expect(store.visitsForClient('c-nour').map((v) => v.id), isNot(contains(booked.id)));
      expect(store.visitsForClient('c-heba').map((v) => v.id), contains(booked.id));
    });

    test('reassigning to a client with no package changes nothing', () {
      final at = DateTime.now().add(const Duration(days: 3));
      final booked = store.scheduleVisit(clientId: 'c-nour', at: at)!;

      expect(store.rescheduleVisit(booked.id, clientId: 'c-salma'), isFalse);
      expect(store.visit(booked.id).clientId, 'c-nour');
    });

    test('deleting an attended appointment gives the visit back', () {
      final visit = store.todayVisits.firstWhere(
        (v) => store.client(v.clientId).name == 'نور خالد',
      );
      store.markVisit(visit.id, VisitStatus.attended);
      expect(store.package(visit.packageId).isActive, isFalse);

      store.deleteVisit(visit.id);

      expect(store.visits.map((v) => v.id), isNot(contains(visit.id)));
      expect(store.package(visit.packageId).isActive, isTrue);
      expect(store.remainingVisits(visit.packageId), 1);
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
      // Soonest first.
      for (var i = 1; i < upcoming.length; i++) {
        expect(upcoming[i].scheduledAt.isBefore(upcoming[i - 1].scheduledAt), isFalse);
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
      // The honorific is skipped, not greeted.
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

    test('a package never reads as complete on the day it is seeded active', () {
      for (final day in [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 15),
        DateTime(2026, 2, 28),
        DateTime(2026, 12, 31),
      ]) {
        final seeded = AppStore(seed: SampleData.build(today: day));
        for (final pkg in seeded.packages.where((p) => p.isActive)) {
          expect(
            seeded.attendedCount(pkg.id) < pkg.visitCount,
            isTrue,
            reason: 'active package ${pkg.id} was fully resolved on $day',
          );
        }
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
      expect(ArabicDates.days(21), '٢١ يوماً');
      expect(ArabicDates.dayMonth(DateTime(2026, 9, 1)), '١ سبتمبر');
      expect(ArabicDates.monthYear(DateTime(2026, 9, 1)), 'سبتمبر ٢٠٢٦');
      expect(ArabicDates.time(DateTime(2026, 9, 1, 10, 30)), '١٠:٣٠ ص');
      expect(ArabicDates.time(DateTime(2026, 9, 1, 12, 0)), '١٢:٠٠ م');
    });
  });
}
