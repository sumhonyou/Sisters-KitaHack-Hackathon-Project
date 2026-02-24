import 'package:cloud_firestore/cloud_firestore.dart';

enum Severity { critical, high, medium, low }

class IncidentModel {
  final String id;
  final String title;
  final String location;
  final double lat;
  final double lng;
  final String zone;
  final Severity severity;
  final int peopleAffected;
  final String status;
  final String description;
  final DateTime timestamp;

  IncidentModel({
    required this.id,
    required this.title,
    required this.location,
    required this.lat,
    required this.lng,
    required this.zone,
    required this.severity,
    required this.peopleAffected,
    required this.status,
    required this.description,
    required this.timestamp,
  });

  static Severity _parseSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'critical':
        return Severity.critical;
      case 'high':
        return Severity.high;
      case 'medium':
        return Severity.medium;
      default:
        return Severity.low;
    }
  }

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return IncidentModel(
      id: doc.id,
      title: d['title'] ?? '',
      location: d['location'] ?? '',
      lat: (d['lat'] as num?)?.toDouble() ?? 3.1390,
      lng: (d['lng'] as num?)?.toDouble() ?? 101.6869,
      zone: d['zone'] ?? 'Zone A',
      severity: _parseSeverity(d['severity'] ?? 'low'),
      peopleAffected: (d['peopleAffected'] as num?)?.toInt() ?? 0,
      status: d['status'] ?? 'Active',
      description: d['description'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'location': location,
    'lat': lat,
    'lng': lng,
    'zone': zone,
    'severity': severity.name,
    'peopleAffected': peopleAffected,
    'status': status,
    'description': description,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
