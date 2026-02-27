import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disaster_model.dart';
import '../models/shelter_model.dart';

class AlertsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream active disasters ordered by updatedAt descending.
  Stream<List<DisasterModel>> streamActiveDisasters() {
    return _db.collection('disasters').snapshots().map((snap) {
      final disasters = snap.docs
          .map(DisasterModel.fromFirestore)
          .where((d) => d.status == 'active')
          .toList();
      // Sort in-place by updatedAt descending
      disasters.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return disasters;
    });
  }

  /// Stream a single disaster by its ID.
  Stream<DisasterModel?> streamDisasterById(String id) {
    return _db
        .collection('disasters')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? DisasterModel.fromFirestore(doc) : null);
  }

  /// Fetch shelters for a given list of area IDs.
  /// Strictly read-only.
  Stream<List<ShelterModel>> streamSheltersForAreas(
    List<String> affectedAreaIds,
  ) {
    if (affectedAreaIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore "in" filter is limited to 10 items.
    // If there are more, we might need multiple queries, but 10 is usually enough for affected areas.
    final limitedIds = affectedAreaIds.take(10).toList();

    return _db
        .collection('shelters')
        .where('areaId', whereIn: limitedIds)
        .snapshots()
        .map((snap) => snap.docs.map(ShelterModel.fromFirestore).toList());
  }

  /// Fetch all areas to resolve names and coordinates.
  Stream<Map<String, dynamic>> streamAreaMap() {
    return _db.collection('areas').snapshots().map((snap) {
      final Map<String, dynamic> areaMap = {};
      for (var doc in snap.docs) {
        areaMap[doc.id] = doc.data();
      }
      return areaMap;
    });
  }

  /// Decrement totalAffected in disaster document.
  Future<void> decrementTotalAffected(String disasterId) async {
    await _db.collection('disasters').doc(disasterId).update({
      'totalAffected': FieldValue.increment(-1),
    });
  }
}
