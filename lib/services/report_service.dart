import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'firestore_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Get current GPS position (requests permission if needed).
  Future<Position?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get Area Name for coordinates
  Future<String> getAreaName(double lat, double lng) async {
    final res = await _firestoreService.getOrCreateAreaId(lat, lng);
    return res.$2;
  }

  // _resolveArea removed in favor of _firestoreService.getOrCreateAreaId

  /// Upload a list of local image/video files to Firebase Storage.
  /// Returns a list of download URLs.
  Future<List<String>> _uploadMedia(String caseId, List<File> files) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final ext = files[i].path.split('.').last;
      final ref = _storage.ref().child('reported_cases/$caseId/media_$i.$ext');
      final task = await ref.putFile(files[i]);
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }

  /// Submit a disaster report and save to Firestore.
  /// Returns the generated caseId.
  Future<String> submitReport({
    required String category,
    required String checkIn,
    required double? lat,
    required double? lng,
    required int severity,
    required int peopleAffected,
    required String description,
    required List<File> mediaFiles,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'anonymous';

    // Create the document first to get the ID for media paths
    final docRef = _firestore.collection('reported_cases').doc();
    final caseId = docRef.id;

    // Upload media
    final mediaUrls = mediaFiles.isNotEmpty
        ? await _uploadMedia(caseId, mediaFiles)
        : <String>[];

    // Resolve area
    String areaId = 'unknown';
    String areaName = 'Unknown Location';
    if (lat != null && lng != null) {
      final res = await _firestoreService.getOrCreateAreaId(lat, lng);
      areaId = res.$1;
      areaName = res.$2;
    }

    await docRef.set({
      'caseId': caseId,
      'reporterUid': uid,
      'category': category,
      'checkIn': checkIn,
      'locationLabel': areaName,
      'location': (lat != null && lng != null) ? GeoPoint(lat, lng) : null,
      'areaId': areaId,
      'severity': severity,
      'peopleAffected': peopleAffected,
      'timestamp': FieldValue.serverTimestamp(),
      'description': description,
      'status': 'pending',
      'media': mediaUrls,
    });

    return caseId;
  }
}
