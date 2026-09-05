import 'dart:math' as math;

import '../models/models.dart';

typedef SampleSeed = ({
  List<Client> clients,
  List<Visit> visits,
  List<Payment> payments,
});

/// The roster the mockups describe, and what demo mode and the tests
/// run on. A real signed-in account never sees any of it — it starts
/// empty and fills with her own people.
///
/// Anchored to "today" rather than the day the mockups were drawn, so a
/// test run always exercises a plausible current week. The six clients
/// named in the design are placed by hand to land on the exact states
/// the screens show; the rest of the twenty-four are generated so the
/// dashboard's revenue trend and outstanding total are real sums rather
/// than captions.
abstract final class SampleData {
  static SampleSeed build({DateTime? today}) {
    final anchor = today ?? DateTime.now();
    return _SeedBuilder(DateTime(anchor.year, anchor.month, anchor.day)).build();
  }
}

class _SeedBuilder {
  _SeedBuilder(this.today);

  final DateTime today;

  final clients = <Client>[];
  final visits = <Visit>[];
  final payments = <Payment>[];

  int _seq = 0;
  String _id(String prefix) => '$prefix${++_seq}';

  /// [daysAgo] days before today, at [hour]:[minute].
  DateTime _at(int daysAgo, [int hour = 10, int minute = 0]) =>
      DateTime(today.year, today.month, today.day - daysAgo, hour, minute);

  SampleSeed build() {
    _featured();
    _generated();
    return (clients: clients, visits: visits, payments: payments);
  }

  Client _client(
    String id,
    String name,
    String phone,
    int age, {
    int startedDaysAgo = 90,
  }) {
    final client = Client(
      id: id,
      name: name,
      phone: phone,
      age: age,
      startDate: _at(startedDaysAgo, 0, 0),
    );
    clients.add(client);
    return client;
  }

  void _visit(String clientId, DateTime at, VisitStatus status) {
    visits.add(Visit(id: _id('v'), clientId: clientId, scheduledAt: at, status: status));
  }

  /// [count] attended visits, one a week, ending [lastDaysAgo] days ago.
  void _attendedRun(String clientId, int count, {required int lastDaysAgo}) {
    for (var i = 0; i < count; i++) {
      _visit(clientId, _at(lastDaysAgo + (count - 1 - i) * 7, 10, 0), VisitStatus.attended);
    }
  }

  void _pay(String clientId, double amount, int daysAgo, PaymentMethod method) {
    payments.add(Payment(
      id: _id('p'),
      clientId: clientId,
      amount: amount,
      method: method,
      date: _at(daysAgo, 12, 0),
    ));
  }

  /// A payment [monthsAgo] months back, on a day that exists in every
  /// month. Placed by month rather than by "days ago" so the dashboard's
  /// six bars are guaranteed to have something in each of them however
  /// long the months in between happen to be.
  void _payInMonth(String clientId, double amount, int monthsAgo, PaymentMethod method) {
    final month = DateTime(today.year, today.month - monthsAgo);
    final day = monthsAgo == 0 ? (today.day > 1 ? 1 : today.day) : 15;
    payments.add(Payment(
      id: _id('p'),
      clientId: clientId,
      amount: amount,
      method: method,
      date: DateTime(month.year, month.month, day, 12),
    ));
  }

  /// The six named in the design, placed to land on the states the
  /// screens are drawn around.
  void _featured() {
    // نور — three visits in, her fourth is today and still to be marked.
    // Nothing paid yet, so she owes the package she is using.
    final nour = _client('c-nour', 'نور خالد', '0541234567', 34);
    _attendedRun(nour.id, 3, lastDaysAgo: 7);
    _visit(nour.id, _at(0, 10, 30), VisitStatus.scheduled);

    // هبة — halfway through a package she has paid for; today pending.
    final heba = _client('c-heba', 'هبة منصور', '0522345678', 29);
    _attendedRun(heba.id, 2, lastDaysAgo: 7);
    _pay(heba.id, 100, 21, PaymentMethod.bit);
    _visit(heba.id, _at(0, 12, 0), VisitStatus.scheduled);

    // ريم — came this morning, already marked.
    final reem = _client('c-reem', 'ريم عبد الله', '0533456789', 41);
    _attendedRun(reem.id, 1, lastDaysAgo: 7);
    _pay(reem.id, 100, 14, PaymentMethod.cash);
    _visit(reem.id, _at(0, 9, 0), VisitStatus.attended);

    // سلمى — didn't come this morning, and has just finished her four,
    // so she needs the next package. The no-show costs her nothing.
    final salma = _client('c-salma', 'سلمى يوسف', '0544567890', 26);
    _attendedRun(salma.id, 4, lastDaysAgo: 10);
    _pay(salma.id, 100, 40, PaymentMethod.transfer);
    _visit(salma.id, _at(0, 8, 0), VisitStatus.noShow);

    // لمى — a package and a bit behind: five visits used, one paid for.
    final lama = _client('c-lama', 'لمى صبري', '0555678901', 37);
    _attendedRun(lama.id, 5, lastDaysAgo: 5);
    _pay(lama.id, 100, 60, PaymentMethod.cash);

    // أمل — one visit in, nothing paid.
    final amal = _client('c-amal', 'أمل حجازي', '0566789012', 31);
    _attendedRun(amal.id, 1, lastDaysAgo: 3);

    // دعاء — two full packages done and paid; due to start a third.
    final doaa = _client('c-doaa', 'دعاء شاهين', '0577890123', 45, startedDaysAgo: 200);
    _attendedRun(doaa.id, 8, lastDaysAgo: 12);
    _pay(doaa.id, 100, 120, PaymentMethod.cash);
    _pay(doaa.id, 100, 50, PaymentMethod.bit);
  }

  /// Seventeen more, fully settled, spread across the last six months so
  /// the dashboard's trend and counts are sums of real rows.
  void _generated() {
    const names = [
      'رنا عوض', 'ميساء طه', 'جمانة نصر', 'بيان فارس', 'ليان شحادة',
      'تالا زيدان', 'شهد مرعي', 'راما قاسم', 'نغم بدران', 'يارا حلبي',
      'دانا سرحان', 'سارة عليان', 'هنا الخطيب', 'رهف عساف', 'مي دراغمة',
      'لين أبو زيد', 'جنى الشامي',
    ];

    final random = math.Random(7);
    for (var i = 0; i < names.length; i++) {
      final client = _client(
        'c-other-$i',
        names[i],
        '05${(10000000 + i * 111111).toString().padLeft(8, '0')}',
        22 + random.nextInt(28),
        startedDaysAgo: 150,
      );

      // Two to eight visits, cycling — so the roster is a mix of
      // part-way-through and just-finished rather than everyone sitting
      // exactly on a package boundary, which made "تحتاج تجديد" read as
      // if it meant everybody.
      final attended = 2 + (i % 7);
      _attendedRun(client.id, attended, lastDaysAgo: 14 + i * 3);

      // Settled up: one payment per package her visits have used,
      // spread across the six months the dashboard charts so every bar
      // is a real sum.
      final packages = (attended / 4).ceil();
      for (var p = 0; p < packages; p++) {
        _payInMonth(client.id, 100, (i + p * 3) % 6, PaymentMethod.values[i % 3]);
      }
    }
  }
}
