import 'package:cloud_firestore/cloud_firestore.dart';

class AreaModel {
  final String id;
  final String areaId;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;

  AreaModel({
    required this.id,
    required this.areaId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    this.radiusKm = 5.0,
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
      radiusKm: (d['radiusKm'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'areaId': areaId,
    'name': name,
    'center': GeoPoint(centerLat, centerLng),
    'radiusKm': radiusKm,
  };
}
