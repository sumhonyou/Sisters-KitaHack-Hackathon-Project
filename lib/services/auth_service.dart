import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  // Enhanced to also create an area entry as requested.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? areaName, // Optional area name
    double? areaLat, // Optional area latitude
    double? areaLng, // Optional area longitude
    double? areaRadiusKm, // Optional area radius
  }) async {
    try {
      // 1. Create user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user?.uid;
      if (uid != null) {
        // 2. Add user details to Firestore 'users' collection
        await _firestore.collection('users').doc(uid).set({
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
        });

        // 3. Add area details to Firestore 'areas' collection
        // We use a new doc for the area or link it to the user.
        // The user mentioned an 'areas' table with areaId, center, name, radiusKm.
        final areaRef = _firestore.collection('areas').doc();
        await areaRef.set({
          'areaId': areaRef.id,
          'name': areaName ?? 'Default Area',
          'center': (areaLat != null && areaLng != null)
              ? GeoPoint(areaLat, areaLng)
              : const GeoPoint(3.1390, 101.6869), // Default to KL if missing
          'radiusKm': areaRadiusKm ?? 5.0,
        });
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Delete account
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Delete Firestore data
      await _firestore.collection('users').doc(user.uid).delete();

      // 2. Delete Auth user
      await user.delete();
    } catch (e) {
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
