import 'package:flutter/material.dart';
import 'package:kitahack/services/sos_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _sosService = SosService();
  bool _initializing = true;
  String? _caseId;
  Map<String, dynamic>? _userProfile;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _triggerEmergency();
  }

  Future<void> _triggerEmergency() async {
    final profile = await _sosService.getUserProfile();
    final pos = await _sosService.getCurrentLocation();

    final caseId = await _sosService.triggerSos(
      lat: pos?.latitude,
      lng: pos?.longitude,
    );

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _lat = pos?.latitude;
        _lng = pos?.longitude;
        _caseId = caseId;
        _initializing = false;
      });
    }
  }

  Future<void> _callEmergency() async {
    final url = Uri.parse('tel:911');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: _initializing
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SOS TRIGGERED',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CASE ID: ${_caseId ?? 'Generating...'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Help is on the way.',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: _callEmergency,
                    icon: const Icon(Icons.phone),
                    label: const Text('CALL EMERGENCY SERVICES'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
