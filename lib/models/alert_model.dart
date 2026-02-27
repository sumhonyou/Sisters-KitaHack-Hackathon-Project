import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String title;
  final String description;
  final String type; // fire, flood, earthquake, tsunami
  final int severity; // 1-5
  final String status; // active, resolved
  final String country;
  final String? state;
  final String? district;
  final List<String> keywords;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final double? lat;
  final double? lng;

  const AlertModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.status,
    required this.country,
    this.state,
    this.district,
    required this.keywords,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.lat,
    this.lng,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      type: d['type'] ?? 'flood',
      severity: d['severity'] ?? 3,
      status: d['status'] ?? 'active',
      country: d['country'] ?? 'Malaysia',
      state: d['state'],
      district: d['district'],
      keywords: List<String>.from(d['keywords'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'type': type,
    'severity': severity,
    'status': status,
    'country': country,
    'state': state,
    'district': district,
    'keywords': keywords,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'lat': lat,
    'lng': lng,
  };
}
