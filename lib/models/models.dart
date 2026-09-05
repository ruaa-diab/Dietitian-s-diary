import 'package:flutter/widgets.dart';

/// Outcome of a scheduled visit.
enum VisitStatus { scheduled, attended, noShow }

/// How a payment was received — نقداً / بِت / تحويل.
enum PaymentMethod {
  cash('نقداً'),
  bit('بِت'),
  transfer('تحويل');

  const PaymentMethod(this.label);
  final String label;
}

/// The payment intent chosen when a package is sold.
enum PaymentIntent {
  paidInFull('مدفوع كامل'),
  partial('دفعة جزئية'),
  later('لاحقاً');

  const PaymentIntent(this.label);
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
  });

  final String id;
  final String name;
  final String phone;
  final int age;

  /// When this client first joined — distinct from any one package's start.
  final DateTime startDate;

  String get initial => name.characters.first;

  Client copyWith({String? name, String? phone, int? age}) => Client(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        age: age ?? this.age,
        startDate: startDate,
      );
}

/// A block of visits sold to a client, plus whatever has been paid for it.
@immutable
class ClientPackage {
  const ClientPackage({
    required this.id,
    required this.clientId,
    required this.visitCount,
    required this.price,
    required this.startDate,
    this.endDate,
    this.payments = const [],
  });

  final String id;
  final String clientId;
  final int visitCount;

  /// Total price for the whole package, in ₪.
  final double price;
  final DateTime startDate;

  /// `null` while the package is still running (جارية).
  final DateTime? endDate;
  final List<Payment> payments;

  double get pricePerVisit => visitCount == 0 ? 0 : price / visitCount;

  double get paid => payments.fold(0.0, (sum, p) => sum + p.amount);

  double get balanceDue => (price - paid).clamp(0, price);

  bool get isPaid => balanceDue <= 0.001;

  bool get isActive => endDate == null;

  ClientPackage copyWith({DateTime? endDate, List<Payment>? payments, bool clearEndDate = false}) =>
      ClientPackage(
        id: id,
        clientId: clientId,
        visitCount: visitCount,
        price: price,
        startDate: startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        payments: payments ?? this.payments,
      );
}

@immutable
class Payment {
  const Payment({
    required this.id,
    required this.packageId,
    required this.amount,
    required this.method,
    required this.date,
  });

  final String id;
  final String packageId;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
}

/// One appointment within a package. [index] is 1-based, so a visit reads
/// as "الزيارة ٤ من ٤".
@immutable
class Visit {
  const Visit({
    required this.id,
    required this.clientId,
    required this.packageId,
    required this.index,
    required this.scheduledAt,
    this.status = VisitStatus.scheduled,
  });

  final String id;
  final String clientId;
  final String packageId;
  final int index;
  final DateTime scheduledAt;
  final VisitStatus status;

  bool get isResolved => status != VisitStatus.scheduled;

  /// [clientId], [packageId] and [index] move together when an
  /// appointment is reassigned to a different client: the visit leaves
  /// one package for another, and takes its place in the new one.
  Visit copyWith({
    VisitStatus? status,
    DateTime? scheduledAt,
    String? clientId,
    String? packageId,
    int? index,
  }) =>
      Visit(
        id: id,
        clientId: clientId ?? this.clientId,
        packageId: packageId ?? this.packageId,
        index: index ?? this.index,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        status: status ?? this.status,
      );
}

/// A package shape the dietitian can sell, as offered on the
/// "باقة جديدة" screen.
@immutable
class PackageOption {
  const PackageOption({required this.visitCount, required this.price});

  final int visitCount;
  final double price;

  double get pricePerVisit => price / visitCount;
}
