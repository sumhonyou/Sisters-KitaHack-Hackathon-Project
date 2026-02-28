import 'package:cloud_firestore/cloud_firestore.dart';

class DisasterModel {
  final String id;
  final String type; // maps to "Type" in Firestore
  final String severity; // low, medium, high
  final String title;
  final String description;
  final List<String> affectedAreaIds;
  final GeoPoint? center;
  final String status; // maps to "Status" (Active)
  final String? imageUrl; // Optional image URL
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
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DisasterModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final updatedAt =
        (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Handle numeric severity (e.g., "8") or string labels (e.g., "High")
    String rawSeverity = (d['severity'] ?? 'Medium').toString();
    String mappedSeverity;
    final intValue = int.tryParse(rawSeverity);
    if (intValue != null) {
      if (intValue >= 7) {
        mappedSeverity = 'High';
      } else if (intValue >= 4) {
        mappedSeverity = 'Medium';
      } else {
        mappedSeverity = 'Low';
      }
    } else {
      // Capitalize first letter if it's already a string label
      mappedSeverity = rawSeverity.isNotEmpty
          ? rawSeverity[0].toUpperCase() +
                rawSeverity.substring(1).toLowerCase()
          : 'Medium';
    }

    return DisasterModel(
      id: doc.id,
      type: d['Type'] ?? d['type'] ?? 'Other',
      severity: mappedSeverity,
      title: d['title'] ?? 'Untitled Disaster',
      description: d['description'] ?? '',
      affectedAreaIds: List<String>.from(d['affectedAreaIds'] ?? []),
      center: d['center'] as GeoPoint?,
      status: (d['Status'] ?? d['status'] ?? 'active').toString().toLowerCase(),
      imageUrl: d['imageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? updatedAt,
      updatedAt: updatedAt,
    );
  }

  String get category {
    final t = type.toLowerCase();
    final titleL = title.toLowerCase();

    // Prioritize specific categories
    if (t.contains('flood') || titleL.contains('flood')) {
      return 'Flood';
    }
    if (t.contains('fire') || titleL.contains('fire')) {
      return 'Fire';
    }
    if (t.contains('storm') ||
        t.contains('rain') ||
        t.contains('wind') ||
        t.contains('hurricane') ||
        t.contains('cyclone') ||
        t.contains('typhoon') ||
        t.contains('monsoon') ||
        titleL.contains('storm') ||
        titleL.contains('rain') ||
        titleL.contains('wind')) {
      return 'Storm';
    }
    if (t.contains('earthquake') ||
        t.contains('quake') ||
        titleL.contains('earthquake') ||
        titleL.contains('quake')) {
      return 'Earthquake';
    }
    if (t.contains('tsunami') ||
        t.contains('wave') ||
        titleL.contains('tsunami') ||
        titleL.contains('wave')) {
      return 'Tsunami';
    }
    if (t.contains('landslide') ||
        t.contains('mudslide') ||
        titleL.contains('landslide') ||
        titleL.contains('mudslide')) {
      return 'Landslide';
    }

    return 'Other';
  }

  Map<String, dynamic> toMap() => {
    'Type': type,
    'severity': severity,
    'title': title,
    'description': description,
    'affectedAreaIds': affectedAreaIds,
    'center': center,
    'Status': status,
    'imageUrl': imageUrl,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
