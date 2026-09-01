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

    test('a no-show also consumes the visit and closes the package', () {
      final visit = nourFinalVisit();
      store.markVisit(visit.id, VisitStatus.noShow);

      expect(store.package(visit.packageId).isActive, isFalse);
      expect(store.attendedCount(visit.packageId), 3);
      expect(store.resolvedCount(visit.packageId), 4);
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

    test('paying later leaves the whole price outstanding', () {
      final pkg = store.sellPackage(
        clientId: 'c-doaa',
        option: AppStore.packageOptions.last,
        intent: PaymentIntent.later,
        amountReceived: 150,
        method: PaymentMethod.cash,
      );

      expect(pkg.payments, isEmpty);
      expect(pkg.balanceDue, 190);
    });

    test('a partial payment records only what was received', () {
      final pkg = store.sellPackage(
        clientId: 'c-doaa',
        option: AppStore.packageOptions.last,
        intent: PaymentIntent.partial,
        amountReceived: 90,
        method: PaymentMethod.transfer,
      );

      expect(pkg.paid, 90);
      expect(pkg.balanceDue, 100);
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

  group('weight tracking', () {
    test('delta is measured from the first reading', () {
      expect(store.startWeight('c-nour'), 78.0);
      expect(store.currentWeight('c-nour'), 73.8);
      expect(store.weightDelta('c-nour')!, closeTo(-4.2, 0.001));
    });

    test('logging a weight moves the current value', () {
      store.logWeight(clientId: 'c-nour', weightKg: 73.1);
      expect(store.currentWeight('c-nour'), 73.1);
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
            seeded.resolvedCount(pkg.id) < pkg.visitCount,
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
