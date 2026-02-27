import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitahack/firebase_options.dart';
import 'package:kitahack/pages/login_screen.dart';
import 'package:kitahack/services/notification_service.dart';
import 'package:kitahack/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:kitahack/services/alerts_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications
  await NotificationService().init();

  // Seed sample data if database is empty (for demo purposes)
  final firestoreService = FirestoreService();
  await firestoreService.seedSampleDataIfEmpty();
  await firestoreService.seedAlertsIfEmpty();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AlertsController())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService().navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CityGuard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2575FC)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: const LoginScreen(),
    );
  }
}
