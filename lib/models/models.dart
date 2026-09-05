import 'package:flutter/widgets.dart';

/// Outcome of an appointment.
enum VisitStatus {
  /// Booked, not yet resolved either way.
  scheduled,

  /// She came. This is the only status that spends a visit.
  attended,

  /// She didn't. Kept in the record, costs the client nothing.
  noShow,
}

/// How a payment was received — نقداً / بِت / تحويل.
enum PaymentMethod {
  cash('نقداً'),
  bit('بِت'),
  transfer('تحويل');

  const PaymentMethod(this.label);
  final String label;
}

@immutable
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.age,
    required this.startDate,
    this.priorVisits = 0,
    this.priorPaid = 0,
  });

  final String id;
  final String name;
  final String phone;
  final int age;

  /// When this client first joined.
  final DateTime startDate;

  /// Visits she had attended *before* any of this was being recorded
  /// here — a client who has been coming for months and is only now
  /// being entered, or a few visits the dietitian never got around to
  /// writing down. Counted alongside the dated visits so her position in
  /// the current package is right from the first day.
  ///
  /// An opening balance rather than invented visit records: they have no
  /// real dates, and putting made-up ones in the visit history would be
  /// worse than saying plainly "٣ زيارات سابقة".
  final int priorVisits;

  /// Money she had already paid before then, in ₪. Same idea.
  final double priorPaid;

  String get initial => name.characters.first;

  Client copyWith({
    String? name,
    String? phone,
    int? age,
    int? priorVisits,
    double? priorPaid,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        age: age ?? this.age,
        startDate: startDate,
        priorVisits: priorVisits ?? this.priorVisits,
        priorPaid: priorPaid ?? this.priorPaid,
      );
}

/// One appointment, belonging to a client and nothing else.
///
/// Deliberately *not* tied to a package. The dietitian books an
/// appointment, the client comes, and only then does money change hands —
/// so an appointment that had to belong to a package she hadn't bought
/// yet couldn't be booked at all. Which package a visit falls into is
/// worked out by counting attendance, not by what it was filed under.
@immutable
class Visit {
  const Visit({
    required this.id,
    required this.clientId,
    required this.scheduledAt,
    this.status = VisitStatus.scheduled,
  });

  final String id;
  final String clientId;
  final DateTime scheduledAt;
  final VisitStatus status;

  bool get isResolved => status != VisitStatus.scheduled;

  Visit copyWith({VisitStatus? status, DateTime? scheduledAt, String? clientId}) => Visit(
        id: id,
        clientId: clientId ?? this.clientId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        status: status ?? this.status,
      );
}

/// Money received, belonging to a client and nothing else.
///
/// What it pays *for* is the client's running balance — visits attended,
/// priced by the package — rather than one nominated package. That is
/// what lets her be a package and a half behind without the books
/// needing somewhere to put the half.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.method,
    required this.date,
  });

  final String id;
  final String clientId;
  final double amount;
  final PaymentMethod method;
  final DateTime date;

  Payment copyWith({double? amount, PaymentMethod? method, DateTime? date}) => Payment(
        id: id,
        clientId: clientId,
        amount: amount ?? this.amount,
        method: method ?? this.method,
        date: date ?? this.date,
      );
}

/// What a package is: a block of visits at a price.
///
/// There is one — ٤ زيارات for ١٠٠ ₪ — and it is a rate rather than a
/// record. Nothing is stored per package; a client's visits are counted
/// and divided by this.
@immutable
class PackageRate {
  const PackageRate({required this.visitCount, required this.price});

  final int visitCount;
  final double price;

  double get pricePerVisit => price / visitCount;
}
