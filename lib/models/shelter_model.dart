import 'package:cloud_firestore/cloud_firestore.dart';

class ShelterModel {
  final String id;
  final String name;
  final GeoPoint? location;
  final String areaId;
  final String status; // open, full, closed
  final int capacityTotal;
  final int capacityCurrent;
  final String contactPhone;
  final DateTime updatedAt;

  ShelterModel({
    required this.id,
    required this.name,
    this.location,
    required this.areaId,
    required this.status,
    required this.capacityTotal,
    required this.capacityCurrent,
    required this.contactPhone,
    required this.updatedAt,
  });

  factory ShelterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ShelterModel(
      id: doc.id,
      name: d['name'] ?? 'Unnamed Shelter',
      location: d['location'] as GeoPoint?,
      areaId: d['areaId'] ?? '',
      status: d['status'] ?? 'open',
      capacityTotal: d['capacityTotal'] ?? 0,
      capacityCurrent: d['capacityCurrent'] ?? 0,
      contactPhone: d['contactPhone'] ?? '',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'location': location,
    'areaId': areaId,
    'status': status,
    'capacityTotal': capacityTotal,
    'capacityCurrent': capacityCurrent,
    'contactPhone': contactPhone,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  int get availableCapacity => capacityTotal - capacityCurrent;
  bool get isFull => capacityCurrent >= capacityTotal;
  double get occupancyRate =>
      capacityTotal > 0 ? capacityCurrent / capacityTotal : 0.0;
}
