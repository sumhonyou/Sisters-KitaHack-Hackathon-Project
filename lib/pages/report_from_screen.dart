import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitahack/services/report_service.dart';

class ReportFormScreen extends StatefulWidget {
  final String category;
  const ReportFormScreen({super.key, required this.category});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _reportService = ReportService();
  final _descController = TextEditingController();
  final _peopleController = TextEditingController(text: '1');

  double? _severity = 5.0;
  String? _checkIn = 'safe';
  Position? _position;
  List<File> _mediaFiles = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final pos = await _reportService.getCurrentLocation();
    if (mounted) setState(() => _position = pos);
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _mediaFiles.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    // Validation
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _reportService.submitReport(
        category: widget.category.toLowerCase(),
        checkIn: _checkIn ?? 'safe',
        lat: _position?.latitude,
        lng: _position?.longitude,
        severity: _severity?.toInt() ?? 5,
        peopleAffected: int.tryParse(_peopleController.text) ?? 1,
        description: _descController.text.trim(),
        mediaFiles: _mediaFiles,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Report Submitted'),
            content: const Text(
              'Thank you for reporting. Your report has been saved and help is being coordinated.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // dialog
                  Navigator.of(context).pop(); // form
                  Navigator.of(context).pop(); // category
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report ${widget.category}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How are you?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _checkInButton('safe', 'Safe', Colors.green),
                const SizedBox(width: 8),
                _checkInButton('need_assistance', 'Need Help', Colors.orange),
                const SizedBox(width: 8),
                _checkInButton('trapped', 'Trapped', Colors.red),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Severity Level',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _severity!,
              min: 1,
              max: 10,
              divisions: 9,
              label: _severity!.round().toString(),
              onChanged: (v) => setState(() => _severity = v),
            ),

            const SizedBox(height: 16),
            const Text(
              'People Affected',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _peopleController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(controller: _descController, maxLines: 3),

            const SizedBox(height: 16),
            const Text('Media', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Photo/Video'),
            ),
            if (_mediaFiles.isNotEmpty)
              Text('${_mediaFiles.length} files attached'),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text('SUBMIT REPORT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkInButton(String value, String label, Color color) {
    final selected = _checkIn == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _checkIn = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
