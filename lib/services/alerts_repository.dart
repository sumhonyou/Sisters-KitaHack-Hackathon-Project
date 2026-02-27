import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class AlertsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AlertModel>> alertsStream() {
    return _db
        .collection('alerts')
        .where('status', isEqualTo: 'active')
        .orderBy('severity', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs.map((doc) => AlertModel.fromFirestore(doc)).where((
            alert,
          ) {
            // Client-side filter for expiresAt because Firestore doesn't support
            // multi-field inequality on different fields easily without composite indexes
            // and we want to keep it simple.
            if (alert.expiresAt != null && alert.expiresAt!.isBefore(now)) {
              return false;
            }
            return true;
          }).toList();
        });
  }
}
