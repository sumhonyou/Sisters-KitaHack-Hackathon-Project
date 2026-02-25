import 'package:cloud_firestore/cloud_firestore.dart';
import 'severity.dart';

class ReportedCase {
  final String id;
  final String caseId;
  final String areaId;
  final String category;
  final String checkIn;
  final String description;
  final String locationLabel;
  final double lat;
  final double lng;
  final List<String> media;
  final int peopleAffected;
  final String reporterUid;
  final int severityLevel; // raw int from Firestore (1–5)
  final Severity severity; // derived enum
  final String status;
  final DateTime timestamp;

  ReportedCase({
    required this.id,
    required this.caseId,
    required this.areaId,
    required this.category,
    required this.checkIn,
    required this.description,
    required this.locationLabel,
    required this.lat,
    required this.lng,
    required this.media,
    required this.peopleAffected,
    required this.reporterUid,
    required this.severityLevel,
    required this.severity,
    required this.status,
    required this.timestamp,
  });

  // Convert a numeric severity (1–5) to the Severity enum
  static Severity _severityFromInt(int s) {
    if (s >= 5) return Severity.critical;
    if (s >= 4) return Severity.high;
    if (s >= 3) return Severity.medium;
    return Severity.low;
  }

  // Also handle string-based severity
  static Severity _severityFromString(String s) {
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

  factory ReportedCase.fromFirestore(
    DocumentSnapshot doc, {
    double fallbackLat = 3.1390,
    double fallbackLng = 101.6869,
  }) {
    final d = doc.data() as Map<String, dynamic>;

    // Parse lat/lng from location GeoPoint or fall back to area-provided coords
    double lat = fallbackLat;
    double lng = fallbackLng;
    final loc = d['location'];
    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
    }

    // Parse severity (can be int or string)
    int severityLevel = 1;
    Severity severity = Severity.low;
    final rawSev = d['severity'];
    if (rawSev is int) {
      severityLevel = rawSev;
      severity = _severityFromInt(rawSev);
    } else if (rawSev is num) {
      severityLevel = rawSev.toInt();
      severity = _severityFromInt(rawSev.toInt());
    } else if (rawSev is String) {
      severity = _severityFromString(rawSev);
      severityLevel = severity.index + 1;
    }

    // Parse media URLs
    final mediaRaw = d['media'];
    final media = <String>[];
    if (mediaRaw is List) {
      for (final item in mediaRaw) {
        if (item is String && item.isNotEmpty) media.add(item);
      }
    }

    return ReportedCase(
      id: doc.id,
      caseId: d['caseId'] ?? doc.id,
      areaId: d['areaId'] ?? '',
      category: d['category'] ?? 'general',
      checkIn: d['checkIn'] ?? '',
      description: d['description'] ?? '',
      locationLabel: (loc is String) ? loc : '',
      lat: lat,
      lng: lng,
      media: media,
      peopleAffected: (d['peopleAffected'] as num?)?.toInt() ?? 0,
      reporterUid: d['reporterUid'] ?? '',
      severityLevel: severityLevel,
      severity: severity,
      status: d['status'] ?? 'pending',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
