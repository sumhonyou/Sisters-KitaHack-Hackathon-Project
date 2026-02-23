import 'package:cloud_firestore/cloud_firestore.dart';

class ReporterModel {
  final String id;
  final String unitId;
  final String incidentId;
  final String zone;
  final String severity;
  final String locationLabel;
  final String reporterName;
  final String phone;
  final int peopleAffected;
  final DateTime timestamp;
  final bool hasSOS;

  ReporterModel({
    required this.id,
    required this.unitId,
    required this.incidentId,
    required this.zone,
    required this.severity,
    required this.locationLabel,
    required this.reporterName,
    required this.phone,
    required this.peopleAffected,
    required this.timestamp,
    required this.hasSOS,
  });

  factory ReporterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReporterModel(
      id: doc.id,
      unitId: d['unitId'] ?? '',
      incidentId: d['incidentId'] ?? '',
      zone: d['zone'] ?? '',
      severity: d['severity'] ?? 'low',
      locationLabel: d['locationLabel'] ?? '',
      reporterName: d['reporterName'] ?? '',
      phone: d['phone'] ?? '',
      peopleAffected: (d['peopleAffected'] as num?)?.toInt() ?? 0,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasSOS: d['hasSOS'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'unitId': unitId,
    'incidentId': incidentId,
    'zone': zone,
    'severity': severity,
    'locationLabel': locationLabel,
    'reporterName': reporterName,
    'phone': phone,
    'peopleAffected': peopleAffected,
    'timestamp': Timestamp.fromDate(timestamp),
    'hasSOS': hasSOS,
  };
}
