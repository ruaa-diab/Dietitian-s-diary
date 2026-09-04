import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Firestore access, scoped to one signed-in dietitian.
///
/// Every document lives under `practices/{uid}/...`, so a query here
/// never needs to filter by whose data it's touching — the path already
/// is that person's, and the security rules enforce the same boundary
/// server-side.
class CloudStore {
  CloudStore(this._firestore, this.uid);

  final FirebaseFirestore _firestore;
  final String uid;

  CollectionReference<Map<String, Object?>> get _clients =>
      _firestore.collection('practices/$uid/clients');
  CollectionReference<Map<String, Object?>> get _packages =>
      _firestore.collection('practices/$uid/packages');
  CollectionReference<Map<String, Object?>> get _visits =>
      _firestore.collection('practices/$uid/visits');

  /// Live client list — fires immediately with whatever is cached
  /// locally, then again whenever this or another device changes it.
  Stream<List<Client>> watchClients() => _clients
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _clientFromDoc(doc.id, doc.data())).toList());

  Stream<List<ClientPackage>> watchPackages() => _packages
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _packageFromDoc(doc.id, doc.data())).toList());

  Stream<List<Visit>> watchVisits() => _visits
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _visitFromDoc(doc.id, doc.data())).toList());

  Future<void> insertClient(Client client) => _clients.doc(client.id).set(_clientToDoc(client));

  Future<void> insertPackage(ClientPackage package) =>
      _packages.doc(package.id).set(_packageToDoc(package));

  Future<void> updatePackage(ClientPackage package) =>
      _packages.doc(package.id).set(_packageToDoc(package));

  Future<void> insertVisit(Visit visit) => _visits.doc(visit.id).set(_visitToDoc(visit));

  Future<void> insertVisits(List<Visit> visits) async {
    final batch = _firestore.batch();
    for (final visit in visits) {
      batch.set(_visits.doc(visit.id), _visitToDoc(visit));
    }
    await batch.commit();
  }

  Future<void> updateVisit(Visit visit) => _visits.doc(visit.id).set(_visitToDoc(visit));

  /// Marking the visit that completes a package writes both documents —
  /// the visit and the package it closes — in one batch, so a dropped
  /// connection mid-write can't leave one updated without the other.
  Future<void> updateVisitAndPackage(Visit visit, ClientPackage? closedPackage) async {
    final batch = _firestore.batch();
    batch.set(_visits.doc(visit.id), _visitToDoc(visit));
    if (closedPackage != null) {
      batch.set(_packages.doc(closedPackage.id), _packageToDoc(closedPackage));
    }
    await batch.commit();
  }

  // ── Doc <-> model ────────────────────────────────────────────────────
  //
  // Payments are embedded in the package document rather than a
  // subcollection: they're always read and written together with their
  // package, never queried on their own, so one document keeps a
  // payment and the package it belongs to consistent in a single write.

  static Client _clientFromDoc(String id, Map<String, Object?> data) => Client(
        id: id,
        name: data['name']! as String,
        phone: data['phone']! as String,
        age: data['age']! as int,
        startDate: (data['startDate']! as Timestamp).toDate(),
      );

  static Map<String, Object?> _clientToDoc(Client client) => {
        'name': client.name,
        'phone': client.phone,
        'age': client.age,
        'startDate': Timestamp.fromDate(client.startDate),
      };

  static ClientPackage _packageFromDoc(String id, Map<String, Object?> data) {
    final endDate = data['endDate'];
    final payments = (data['payments'] as List<Object?>? ?? const [])
        .map((raw) => _paymentFromMap(id, raw! as Map<String, Object?>))
        .toList();
    return ClientPackage(
      id: id,
      clientId: data['clientId']! as String,
      visitCount: data['visitCount']! as int,
      price: (data['price']! as num).toDouble(),
      startDate: (data['startDate']! as Timestamp).toDate(),
      endDate: endDate == null ? null : (endDate as Timestamp).toDate(),
      payments: payments,
    );
  }

  static Map<String, Object?> _packageToDoc(ClientPackage package) => {
        'clientId': package.clientId,
        'visitCount': package.visitCount,
        'price': package.price,
        'startDate': Timestamp.fromDate(package.startDate),
        'endDate': package.endDate == null ? null : Timestamp.fromDate(package.endDate!),
        'payments': package.payments.map(_paymentToMap).toList(),
      };

  static Payment _paymentFromMap(String packageId, Map<String, Object?> map) => Payment(
        id: map['id']! as String,
        packageId: packageId,
        amount: (map['amount']! as num).toDouble(),
        method: PaymentMethod.values.byName(map['method']! as String),
        date: (map['date']! as Timestamp).toDate(),
      );

  static Map<String, Object?> _paymentToMap(Payment payment) => {
        'id': payment.id,
        'amount': payment.amount,
        'method': payment.method.name,
        'date': Timestamp.fromDate(payment.date),
      };

  static Visit _visitFromDoc(String id, Map<String, Object?> data) => Visit(
        id: id,
        clientId: data['clientId']! as String,
        packageId: data['packageId']! as String,
        index: data['seq']! as int,
        scheduledAt: (data['scheduledAt']! as Timestamp).toDate(),
        status: VisitStatus.values.byName(data['status']! as String),
      );

  static Map<String, Object?> _visitToDoc(Visit visit) => {
        'clientId': visit.clientId,
        'packageId': visit.packageId,
        'seq': visit.index,
        'scheduledAt': Timestamp.fromDate(visit.scheduledAt),
        'status': visit.status.name,
      };
}
