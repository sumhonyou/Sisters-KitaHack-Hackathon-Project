import 'package:cloud_firestore/cloud_firestore.dart';

class DisasterModel {
  final String id;
  final String type; // flood, earthquake, fire, storm, chemical, landslide
  final String severity; // critical, high, medium, low
  final String title;
  final String description;
  final List<String> affectedAreaIds;
  final GeoPoint? center;
  final String status; // active, monitoring, resolved
  final DateTime createdAt;
  final DateTime updatedAt;

  DisasterModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.affectedAreaIds,
    this.center,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DisasterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DisasterModel(
      id: doc.id,
      type: d['type'] ?? 'unknown',
      severity: d['severity'] ?? 'medium',
      title: d['title'] ?? 'Untitled Disaster',
      description: d['description'] ?? '',
      affectedAreaIds: List<String>.from(d['affectedAreaIds'] ?? []),
      center: d['center'] as GeoPoint?,
      status: d['status'] ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'severity': severity,
    'title': title,
    'description': description,
    'affectedAreaIds': affectedAreaIds,
    'center': center,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
