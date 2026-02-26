import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class SosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch user profile from Firestore users collection
  Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // Get the current GPS location
  Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // Save SOS case to Firestore and return the generated caseId
  Future<String> triggerSos({
    required double? lat,
    required double? lng,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'anonymous';

    final docRef = await _firestore.collection('sos_cases').add({
      'userUid': uid,
      'location': (lat != null && lng != null) ? GeoPoint(lat, lng) : null,
      'disasterId': '',
      'suspectedType': 'Unknown',
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // Generate the auto-message for 911
  String generateEmergencyMessage({
    required String name,
    required String phone,
    required double? lat,
    required double? lng,
    required String caseId,
  }) {
    final location = (lat != null && lng != null)
        ? 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}'
        : 'Location unavailable';

    return 'EMERGENCY ALERT from CityGuard App.\n'
        'Name: $name\n'
        'Phone: $phone\n'
        'Location: $location\n'
        'Case ID: $caseId\n'
        'Please dispatch help immediately.';
  }
}
