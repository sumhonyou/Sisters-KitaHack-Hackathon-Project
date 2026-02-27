import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final collection = firestore.collection('shelters');

  final updates = {
    'SH-001': 'assets/images/shelters/Dewan Komuniti Wangsa Maju.jpg',
    'SH-002': 'assets/images/shelters/SMK Kepong Baru Dewan.jpg',
    'SH-003': 'assets/images/shelters/Stadium Merdeka Community Centre.jpg',
    'SH-004': 'assets/images/shelters/Pusat Komuniti Ampang Jaya.jpg',
  };

  for (final entry in updates.entries) {
    try {
      await collection.doc(entry.key).update({'imageURL': entry.value});
      print('Updated \${entry.key}');
    } catch (e) {
      print('Error updating \${entry.key}: \$e');
    }
  }

  print('Done.');
  exit(0);
}
