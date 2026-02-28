import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Fetch user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

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
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Determine nearest area or create new one if location is provided
      String homeAreaId = '';
      if (latitude != null && longitude != null) {
        final areaRes = await _firestoreService.getOrCreateAreaId(
          latitude,
          longitude,
        );
        homeAreaId = areaRes.$1;
      }

      // 3. Add user details to Firestore
      if (result.user != null) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': result.user!.uid,
          'homeAreaId': homeAreaId,
          'role': 'public',
          'disability': false,
          'emergencyContacts': [],
        });
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'This email is already registered in our authentication system. '
            'If you have previously deleted your data from the database, the account login still exists. '
            'Please try logging in instead, or use a different email.';
      }
      rethrow;
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
