import 'package:cloud_firestore/cloud_firestore.dart';

class AreaModel {
  final String id;
  final String areaId;
  final String name;
  final double centerLat;
  final double centerLng;

  AreaModel({
    required this.id,
    required this.areaId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
  });

  factory AreaModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    double lat = 3.1390;
    double lng = 101.6869;
    final center = d['center'];
    if (center is GeoPoint) {
      lat = center.latitude;
      lng = center.longitude;
    }

    return AreaModel(
      id: doc.id,
      areaId: d['areaId'] ?? doc.id,
      name: d['name'] ?? 'Unknown Area',
      centerLat: lat,
      centerLng: lng,
    );
  }
}
