import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  String name;
  String phone;
  String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
        name: m['name'] ?? '',
        phone: m['phone'] ?? '',
        relationship: m['relationship'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };
}

class UserModel {
  final String uid;
  String role; // public / gov
  String fullName;
  String email;
  String phone;
  String profilePic; // URL or empty
  String homeAreaId;
  bool disability;
  List<EmergencyContact> emergencyContacts;

  UserModel({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePic = '',
    this.homeAreaId = '',
    this.disability = false,
    this.emergencyContacts = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      role: d['role'] ?? 'public',
      fullName: d['fullName'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      profilePic: d['profilePic'] ?? '',
      homeAreaId: d['homeAreaId'] ?? '',
      disability: d['disability'] ?? false,
      emergencyContacts: (d['emergencyContacts'] as List<dynamic>? ?? [])
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'profilePic': profilePic,
        'homeAreaId': homeAreaId,
        'disability': disability,
        'emergencyContacts':
            emergencyContacts.map((e) => e.toMap()).toList(),
      };

  UserModel copyWith({
    String? role,
    String? fullName,
    String? email,
    String? phone,
    String? profilePic,
    String? homeAreaId,
    bool? disability,
    List<EmergencyContact>? emergencyContacts,
  }) =>
      UserModel(
        uid: uid,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        profilePic: profilePic ?? this.profilePic,
        homeAreaId: homeAreaId ?? this.homeAreaId,
        disability: disability ?? this.disability,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      );
}
