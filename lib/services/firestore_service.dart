import 'dart:math' show cos, sqrt, pi;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disaster_model.dart';
import '../models/shelter_model.dart';
import '../models/community_post_model.dart';
import '../models/reported_case_model.dart';
import '../models/area_model.dart';
import 'package:geocoding/geocoding.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Streams ───────────────────────────────────────────────────────────────

  // ── reported_cases ────────────────────────────────────────────────────────

  /// Stream all reported cases, newest first.
  /// Falls back to [fallbackLat]/[fallbackLng] if location is null.
  Stream<List<ReportedCase>> reportedCasesStream() {
    return _db.collection('reported_cases').snapshots().map((snap) {
      final cases = snap.docs
          .map((doc) => ReportedCase.fromFirestore(doc))
          .toList();
      cases.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return cases;
    });
  }

  // ── areas ─────────────────────────────────────────────────────────────────

  Stream<List<AreaModel>> areasStream() {
    return _db
        .collection('Areas')
        .snapshots()
        .map((snap) => snap.docs.map(AreaModel.fromFirestore).toList());
  }

  /// Save the coordinate-response unit statuses onto a reported_case document.
  /// [statuses] is a map like {'police': 'Dispatched', 'fire': 'En Route', ...}
  Future<void> updateCaseResponseStatus(
    String caseDocId,
    Map<String, String> statuses,
  ) async {
    await _db.collection('reported_cases').doc(caseDocId).update({
      'responseStatus': statuses,
      'responseUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Nearest Area Detection ──────────────────────────────────────────────

  /// Find the nearest area for a given location.
  /// If [insideRadius] is true, returns null if the user is not within any area's radius.
  Future<String?> getNearestAreaId(
    double lat,
    double lng, {
    bool insideRadius = false,
  }) async {
    final areas = await _db.collection('Areas').get();
    if (areas.docs.isEmpty) return null;

    String? nearestId;
    double minDistance = double.infinity;

    for (var doc in areas.docs) {
      final area = AreaModel.fromFirestore(doc);
      final dist = _calculateDistance(lat, lng, area.centerLat, area.centerLng);

      if (dist < minDistance) {
        if (!insideRadius || dist <= area.radiusKm) {
          minDistance = dist;
          nearestId = area.areaId;
        }
      }
    }

    return nearestId;
  }

  /// Get area (ID, Name) if user is within 5km of an existing center,
  /// otherwise create a new area and return its (ID, Name).
  Future<(String, String)> getOrCreateAreaId(double lat, double lng) async {
    // 1. Check for existing area within 5km
    final areas = await _db.collection('Areas').get();
    for (var doc in areas.docs) {
      final area = AreaModel.fromFirestore(doc);
      final dist = _calculateDistance(lat, lng, area.centerLat, area.centerLng);
      if (dist <= 5.0) {
        return (area.areaId, area.name);
      }
    }

    // 2. Determine a friendly name using Reverse Geocoding
    String newAreaName =
        "Area Around ${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Construct name from neighborhood (subLocality), city (locality), or state (adminArea)
        final neighborhood = place.subLocality ?? "";
        final city = place.locality ?? "";
        final state = place.administrativeArea ?? "";

        if (neighborhood.isNotEmpty && city.isNotEmpty) {
          newAreaName = "$neighborhood, $city";
        } else if (city.isNotEmpty) {
          newAreaName = city;
        } else if (state.isNotEmpty) {
          newAreaName = state;
        }
      }
    } catch (e) {
      // Fallback to coordinate-based name if geocoding fails
      print("Geocoding failed: $e");
    }

    // 3. Create new area
    final docRef = _db.collection('Areas').doc();
    final newAreaId = docRef.id;

    final newArea = AreaModel(
      id: newAreaId,
      areaId: newAreaId,
      name: newAreaName,
      centerLat: lat,
      centerLng: lng,
      radiusKm: 5.0, // Default radius
    );

    await docRef.set(newArea.toMap());
    return (newAreaId, newAreaName);
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = pi / 180;
    const c = cos;
    final a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * sqrt(a); // 2 * R; R = 6371 km
  }

  Stream<List<DisasterModel>> disastersStream({String? status}) {
    Query query = _db
        .collection('disasters')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(DisasterModel.fromFirestore).toList(),
    );
  }

  Stream<List<ShelterModel>> sheltersStream({String? status}) {
    Query query = _db.collection('shelters');
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(ShelterModel.fromFirestore).toList(),
    );
  }

  // posts collection
  Stream<List<CommunityPost>> communityPostsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityPost.fromFirestore).toList());
  }

  Stream<List<CommunityPost>> communityPostsByCategory(String category) {
    return _db
        .collection('posts')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map(CommunityPost.fromFirestore).toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  Stream<List<CommunityPost>> communityPostsByArea(String areaId) {
    return _db
        .collection('posts')
        .where('areaId', isEqualTo: areaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityPost.fromFirestore).toList());
  }

  // comments subcollection
  Stream<List<CommunityComment>> commentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityComment.fromFirestore).toList());
  }

  Future<void> addPost(CommunityPost post) async {
    await _db.collection('posts').add(post.toMap());
  }

  Future<void> addComment(String postId, CommunityComment comment) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());
  }

  Future<void> togglePostLike(
    String postId,
    bool isLiked,
    int currentLikes,
  ) async {
    await _db.collection('posts').doc(postId).update({
      'isLikedByMe': isLiked,
      'likeCount': isLiked ? currentLikes + 1 : currentLikes - 1,
    });
  }

  // ─── Seed Sample Data ──────────────────────────────────────────────────────

  Future<void> seedSampleDataIfEmpty() async {
    return; // All auto-seeding is disabled.
  }
}
