import '../models/models.dart';

/// The four lists the store is built from.
typedef SampleSeed = ({
  List<Client> clients,
  List<ClientPackage> packages,
  List<Visit> visits,
  List<WeightLog> weightLogs,
});

/// Placeholder roster used until the app is wired to a real database.
///
/// The six clients named in the mockups are seeded by hand so the Today,
/// client-detail and dashboard screens open on the states the design
/// shows; the rest of the book of business is generated so the revenue
/// trend and the "الكل ٢٤" count are real numbers rather than captions.
///
/// Everything is anchored to *today*, so the app demos correctly whenever
/// it is run rather than only on the day the mockups were drawn.
abstract final class SampleData {
  static SampleSeed build({DateTime? today}) {
    final anchor = today ?? DateTime.now();
    final builder = _SeedBuilder(DateTime(anchor.year, anchor.month, anchor.day));
    return builder.build();
  }
}

class _SeedBuilder {
  _SeedBuilder(this.today);

  final DateTime today;

  final clients = <Client>[];
  final packages = <ClientPackage>[];
  final visits = <Visit>[];
  final weights = <WeightLog>[];

  int _seq = 0;
  String _id(String prefix) => '$prefix${++_seq}';

  /// [daysAgo] days before today, at [hour]:[minute].
  DateTime _at(int daysAgo, [int hour = 10, int minute = 0]) =>
      DateTime(today.year, today.month, today.day - daysAgo, hour, minute);

  DateTime _day(int daysAgo) => _at(daysAgo, 0, 0);

  bool _isToday(DateTime d) =>
      d.year == today.year && d.month == today.month && d.day == today.day;

  SampleSeed build() {
    _featuredClients();
    _bookOfBusiness();
    return (clients: clients, packages: packages, visits: visits, weightLogs: weights);
  }

  // ── The six clients drawn in the mockups ─────────────────────────────

  void _featuredClients() {
    _nour();
    _heba();
    _reem();
    _salma();
    _lama();
    _amal();
    _doaa();
  }

  /// نور خالد — on her third package, final visit today at ١٠:٣٠،
  /// ١٠٠ ₪ still owed, four kilos down.
  void _nour() {
    final id = 'c-nour';
    clients.add(Client(
      id: id,
      name: 'نور خالد',
      phone: '0541234567',
      age: 34,
      startDate: _day(75),
      goalKg: -6,
    ));

    _closedPackage(clientId: id, visitCount: 4, price: 100, startDaysAgo: 75, endDaysAgo: 49);
    _closedPackage(clientId: id, visitCount: 4, price: 100, startDaysAgo: 48, endDaysAgo: 21);

    // The running package: three attended, the fourth is today's visit.
    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 4,
      price: 100,
      startDate: _day(20),
    ));
    _visit(id, pkgId, 1, _at(20, 10, 30), VisitStatus.attended);
    _visit(id, pkgId, 2, _at(13, 10, 30), VisitStatus.attended);
    _visit(id, pkgId, 3, _at(6, 10, 30), VisitStatus.attended);
    _visit(id, pkgId, 4, _at(0, 10, 30), VisitStatus.scheduled);

    _weights(id, const [
      (20, 78.0),
      (16, 77.0),
      (12, 76.2),
      (8, 75.1),
      (4, 74.4),
      (0, 73.8),
    ]);
  }

  /// هبة منصور — second visit of four today at ١٢:٠٠، paid up front.
  void _heba() {
    final id = 'c-heba';
    clients.add(Client(
      id: id,
      name: 'هبة منصور',
      phone: '0522987410',
      age: 29,
      startDate: _day(12),
      goalKg: -5,
    ));

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 4,
      price: 100,
      startDate: _day(12),
      payments: [_payment(pkgId, 100, PaymentMethod.cash, _day(12))],
    ));
    _visit(id, pkgId, 1, _at(12, 12, 0), VisitStatus.attended);
    _visit(id, pkgId, 2, _at(0, 12, 0), VisitStatus.scheduled);
    _visit(id, pkgId, 3, _at(-7, 12, 0), VisitStatus.scheduled);
    _visit(id, pkgId, 4, _at(-14, 12, 0), VisitStatus.scheduled);

    _weights(id, const [(12, 82.5), (5, 81.6)]);
  }

  /// ريم عبد الله — came in at ٩:٠٠ this morning and was marked attended,
  /// so she shows as a collapsed row on the Today screen.
  void _reem() {
    final id = 'c-reem';
    clients.add(Client(
      id: id,
      name: 'ريم عبد الله',
      phone: '0503311882',
      age: 41,
      startDate: _day(27),
      goalKg: -8,
    ));

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 4,
      price: 100,
      startDate: _day(27),
      payments: [_payment(pkgId, 100, PaymentMethod.transfer, _day(27))],
    ));
    _visit(id, pkgId, 1, _at(27, 9, 0), VisitStatus.attended);
    _visit(id, pkgId, 2, _at(0, 9, 0), VisitStatus.attended);
    _visit(id, pkgId, 3, _at(-7, 9, 0), VisitStatus.scheduled);
    _visit(id, pkgId, 4, _at(-14, 9, 0), VisitStatus.scheduled);

    _weights(id, const [(27, 95.4), (14, 93.8), (0, 92.5)]);
  }

  /// سلمى يوسف — missed her last visit at ٨:٠٠، which closed her package,
  /// so she heads the "تحتاج تجديد" list.
  void _salma() {
    final id = 'c-salma';
    clients.add(Client(
      id: id,
      name: 'سلمى يوسف',
      phone: '0547720513',
      age: 36,
      startDate: _day(30),
      goalKg: -4,
    ));

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 4,
      price: 100,
      startDate: _day(30),
      endDate: today,
      payments: [_payment(pkgId, 100, PaymentMethod.bit, _day(30))],
    ));
    _visit(id, pkgId, 1, _at(30, 8, 0), VisitStatus.attended);
    _visit(id, pkgId, 2, _at(23, 8, 0), VisitStatus.attended);
    _visit(id, pkgId, 3, _at(16, 8, 0), VisitStatus.attended);
    _visit(id, pkgId, 4, _at(0, 8, 0), VisitStatus.noShow);

    _weights(id, const [(30, 68.9), (16, 67.4), (0, 66.8)]);
  }

  /// لمى صبري — eight-visit package, part-paid, ١٠٠ ₪ outstanding.
  void _lama() {
    final id = 'c-lama';
    clients.add(Client(
      id: id,
      name: 'لمى صبري',
      phone: '0526640199',
      age: 45,
      startDate: _day(16),
      goalKg: -10,
    ));

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 8,
      price: 190,
      startDate: _day(16),
      payments: [_payment(pkgId, 90, PaymentMethod.cash, _day(16))],
    ));
    for (var i = 0; i < 8; i++) {
      final daysAgo = 16 - i * 7;
      _visit(id, pkgId, i + 1, _at(daysAgo, 11, 0),
          daysAgo > 0 ? VisitStatus.attended : VisitStatus.scheduled);
    }

    _weights(id, const [(30, 101.2), (16, 99.6), (2, 98.1)]);
  }

  /// أمل حجازي — just signed up, nothing paid yet, first visit still ahead.
  void _amal() {
    final id = 'c-amal';
    clients.add(Client(
      id: id,
      name: 'أمل حجازي',
      phone: '0559084423',
      age: 31,
      startDate: _day(7),
      goalKg: -6,
    ));

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: id,
      visitCount: 4,
      price: 100,
      startDate: _day(7),
    ));
    for (var i = 0; i < 4; i++) {
      _visit(id, pkgId, i + 1, _at(-3 - i * 7, 13, 0), VisitStatus.scheduled);
    }

    _weights(id, const [(7, 74.0)]);
  }

  /// دعاء شاهين — finished ten days ago and has not renewed.
  void _doaa() {
    final id = 'c-doaa';
    clients.add(Client(
      id: id,
      name: 'دعاء شاهين',
      phone: '0538812704',
      age: 38,
      startDate: _day(45),
      goalKg: -5,
    ));
    _closedPackage(clientId: id, visitCount: 4, price: 100, startDaysAgo: 38, endDaysAgo: 10);
    _weights(id, const [(38, 88.3), (24, 86.9), (10, 85.5)]);
  }

  // ── The rest of the book, so the totals are real ─────────────────────

  static const _otherNames = [
    'مريم عساف', 'رانيا الخوري', 'دينا سرحان', 'هالة زيدان', 'ياسمين قاسم',
    'نادين حمدان', 'رغد الشامي', 'جمانة نصار', 'بشرى العلي', 'صفاء درويش',
    'ميساء الحاج', 'عبير طنوس', 'لينا مراد', 'سوسن بدران', 'وفاء الأحمد',
    'إيمان زعبي', 'شذى الخطيب',
  ];

  /// Packages sold per month over the trailing six months, oldest first.
  /// Prices alternate between the ٤-visit and ٨-visit packages.
  static const _salesPerMonth = [11, 13, 10, 15, 14, 16];

  void _bookOfBusiness() {
    final ids = <String>[];
    for (var i = 0; i < _otherNames.length; i++) {
      final id = 'c-other-$i';
      ids.add(id);
      clients.add(Client(
        id: id,
        name: _otherNames[i],
        phone: '05${(20000000 + i * 731913) % 100000000}'.padRight(10, '0'),
        age: 26 + (i * 3) % 24,
        startDate: _day(200 - i * 4),
        goalKg: -(4 + i % 7).toDouble(),
      ));
      _weights(id, [
        (60, 70.0 + (i * 2.3) % 30),
        (30, 69.0 + (i * 2.3) % 30),
        (5, 68.2 + (i * 2.3) % 30),
      ]);
    }

    var cursor = 0;
    for (var m = 0; m < _salesPerMonth.length; m++) {
      final isCurrentMonth = m == _salesPerMonth.length - 1;
      for (var j = 0; j < _salesPerMonth[m]; j++) {
        final clientId = ids[cursor++ % ids.length];
        final visitCount = j.isEven ? 4 : 8;
        final price = j.isEven ? 100.0 : 190.0;

        if (isCurrentMonth) {
          _activePackage(clientId, visitCount, price, j);
        } else {
          final start = _monthDay(5 - m, 2 + (j % 20));
          final closed = _day(1).isBefore(start.add(const Duration(days: 21)))
              ? _day(1)
              : start.add(const Duration(days: 21));
          _closedPackageOn(clientId, visitCount, price, start, closed);
        }
      }
    }
  }

  /// A running package started earlier this month, part-attended, with the
  /// remaining visits still ahead — never on today, which belongs to the
  /// six featured clients.
  void _activePackage(String clientId, int visitCount, double price, int j) {
    // Started within the last fortnight, so the closing visit always lands
    // in the future and the package can never read as already complete.
    final startDay = (today.day - j % 14).clamp(1, today.day);
    final start = DateTime(today.year, today.month, startDay);

    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: clientId,
      visitCount: visitCount,
      price: price,
      startDate: start,
      payments: [_payment(pkgId, price, _method(j), start)],
    ));

    for (var i = 0; i < visitCount; i++) {
      var at = DateTime(start.year, start.month, start.day + i * 7, 9 + (i + j) % 8, 0);
      if (_isToday(at)) at = at.add(const Duration(days: 1));
      _visit(clientId, pkgId, i + 1, at,
          at.isBefore(today) ? VisitStatus.attended : VisitStatus.scheduled);
    }
  }

  void _closedPackage({
    required String clientId,
    required int visitCount,
    required double price,
    required int startDaysAgo,
    required int endDaysAgo,
  }) =>
      _closedPackageOn(clientId, visitCount, price, _day(startDaysAgo), _day(endDaysAgo));

  void _closedPackageOn(
    String clientId,
    int visitCount,
    double price,
    DateTime start,
    DateTime end,
  ) {
    final pkgId = _id('pkg-');
    packages.add(ClientPackage(
      id: pkgId,
      clientId: clientId,
      visitCount: visitCount,
      price: price,
      startDate: start,
      endDate: end,
      payments: [_payment(pkgId, price, _method(visitCount + start.day), start)],
    ));

    final span = end.difference(start).inDays.clamp(visitCount, 1000);
    for (var i = 0; i < visitCount; i++) {
      final at = start.add(Duration(days: (span * i / visitCount).round(), hours: 10));
      _visit(clientId, pkgId, i + 1, at, VisitStatus.attended);
    }
  }

  /// Day [day] of the month [monthsAgo] months back, clamped to a day the
  /// month actually has and never later than today.
  DateTime _monthDay(int monthsAgo, int day) {
    final month = DateTime(today.year, today.month - monthsAgo);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final candidate = DateTime(month.year, month.month, day.clamp(1, lastDay));
    return candidate.isAfter(today) ? today : candidate;
  }

  PaymentMethod _method(int seed) => PaymentMethod.values[seed % PaymentMethod.values.length];

  Payment _payment(String packageId, double amount, PaymentMethod method, DateTime date) =>
      Payment(id: _id('pay-'), packageId: packageId, amount: amount, method: method, date: date);

  void _visit(String clientId, String packageId, int index, DateTime at, VisitStatus status) {
    visits.add(Visit(
      id: _id('visit-'),
      clientId: clientId,
      packageId: packageId,
      index: index,
      scheduledAt: at,
      status: status,
    ));
  }

  void _weights(String clientId, List<(int daysAgo, double kg)> entries) {
    for (final (daysAgo, kg) in entries) {
      weights.add(WeightLog(clientId: clientId, date: _day(daysAgo), weightKg: kg));
    }
  }
}
