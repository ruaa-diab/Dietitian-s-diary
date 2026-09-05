import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Firestore access, scoped to one signed-in dietitian.
///
/// Every document lives under `practices/{uid}/...`, so a query here
/// never needs to filter by whose data it's touching — the path already
/// is that person's, and the security rules enforce the same boundary
/// server-side.
///
/// Three collections, one per model: clients, their appointments, and
/// their payments. Payments are their own collection rather than nested
/// inside a package, because there are no package records any more —
/// what a payment settles is a running balance, not one block of visits.
class CloudStore {
  CloudStore(this._firestore, this.uid);

  final FirebaseFirestore _firestore;
  final String uid;

  CollectionReference<Map<String, Object?>> get _clients =>
      _firestore.collection('practices/$uid/clients');
  CollectionReference<Map<String, Object?>> get _visits =>
      _firestore.collection('practices/$uid/visits');
  CollectionReference<Map<String, Object?>> get _payments =>
      _firestore.collection('practices/$uid/payments');

  DocumentReference<Map<String, Object?>> get _profile =>
      _firestore.doc('practices/$uid/settings/profile');

  /// Live lists — each fires immediately with whatever is cached
  /// locally, then again whenever this or another device changes it.
  Stream<List<Client>> watchClients() => _clients
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _clientFromDoc(doc.id, doc.data())).toList());

  Stream<List<Visit>> watchVisits() => _visits
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _visitFromDoc(doc.id, doc.data())).toList());

  Stream<List<Payment>> watchPayments() => _payments
      .snapshots()
      .map((snap) => snap.docs.map((doc) => _paymentFromDoc(doc.id, doc.data())).toList());

  /// Her own name, as she has edited it — null while she is still on the
  /// default, since nothing has been written yet.
  ///
  /// Lives at `practices/{uid}/settings/profile`, which the same security
  /// rule already covers: it matches `practices/{uid}/{collection}/{docId}`
  /// with `settings` as the collection.
  Stream<String?> watchDietitianName() =>
      _profile.snapshots().map((snap) => snap.data()?['dietitianName'] as String?);

  Future<void> saveDietitianName(String name) =>
      _profile.set(<String, Object?>{'dietitianName': name}, SetOptions(merge: true));

  // Creating and updating are the same write — a whole document, keyed
  // by an id the store already generated — so there is one method each
  // rather than an insert/update pair that only differ in name.

  Future<void> upsertClient(Client client) =>
      _clients.doc(client.id).set(_clientToDoc(client));

  Future<void> upsertVisit(Visit visit) => _visits.doc(visit.id).set(_visitToDoc(visit));

  Future<void> upsertPayment(Payment payment) =>
      _payments.doc(payment.id).set(_paymentToDoc(payment));

  Future<void> deleteVisit(String visitId) => _visits.doc(visitId).delete();

  Future<void> deletePayment(String paymentId) => _payments.doc(paymentId).delete();

  /// Deletes a client and everything of hers in one batch, so a dropped
  /// connection can't leave her appointments behind on a schedule she is
  /// no longer on, or her money in the month's takings.
  Future<void> deleteClient({
    required String clientId,
    required List<String> visitIds,
    required List<String> paymentIds,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_clients.doc(clientId));
    for (final id in visitIds) {
      batch.delete(_visits.doc(id));
    }
    for (final id in paymentIds) {
      batch.delete(_payments.doc(id));
    }
    await batch.commit();
  }

  // ── Doc <-> model ────────────────────────────────────────────────────

  static Client _clientFromDoc(String id, Map<String, Object?> data) => Client(
        id: id,
        name: data['name']! as String,
        phone: data['phone']! as String,
        age: (data['age'] as num?)?.toInt() ?? 0,
        startDate: (data['startDate']! as Timestamp).toDate(),
        priorVisits: (data['priorVisits'] as num?)?.toInt() ?? 0,
        priorPaid: (data['priorPaid'] as num?)?.toDouble() ?? 0,
      );

  static Map<String, Object?> _clientToDoc(Client client) => {
        'name': client.name,
        'phone': client.phone,
        'age': client.age,
        'startDate': Timestamp.fromDate(client.startDate),
        'priorVisits': client.priorVisits,
        'priorPaid': client.priorPaid,
      };

  static Visit _visitFromDoc(String id, Map<String, Object?> data) => Visit(
        id: id,
        clientId: data['clientId']! as String,
        scheduledAt: (data['scheduledAt']! as Timestamp).toDate(),
        status: VisitStatus.values.byName(data['status']! as String),
      );

  static Map<String, Object?> _visitToDoc(Visit visit) => {
        'clientId': visit.clientId,
        'scheduledAt': Timestamp.fromDate(visit.scheduledAt),
        'status': visit.status.name,
      };

  static Payment _paymentFromDoc(String id, Map<String, Object?> data) => Payment(
        id: id,
        clientId: data['clientId']! as String,
        amount: (data['amount']! as num).toDouble(),
        method: PaymentMethod.values.byName(data['method']! as String),
        date: (data['date']! as Timestamp).toDate(),
      );

  static Map<String, Object?> _paymentToDoc(Payment payment) => {
        'clientId': payment.clientId,
        'amount': payment.amount,
        'method': payment.method.name,
        'date': Timestamp.fromDate(payment.date),
      };
}
