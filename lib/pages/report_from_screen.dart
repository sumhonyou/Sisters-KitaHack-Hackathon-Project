import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitahack/services/report_service.dart';
import 'package:geolocator/geolocator.dart';

class ReportFormScreen extends StatefulWidget {
  final String category;
  final IconData categoryIcon;
  final Color categoryColor;
  final Color categoryBg;

  const ReportFormScreen({
    super.key,
    required this.category,
    required this.categoryIcon,
    required this.categoryColor,
    required this.categoryBg,
  });

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final ReportService _service = ReportService();
  final _descController = TextEditingController();
  final _peopleController = TextEditingController();
  final _picker = ImagePicker();

  // Form state
  String? _checkIn; // null = not yet picked
  int? _severity; // null = not yet chosen
  Position? _position;
  String? _areaName;
  bool _loadingLocation = true;
  final List<File> _mediaFiles = [];
  bool _submitting = false;

  // Validation errors
  final Map<String, String?> _errors = {
    'checkIn': null,
    'severity': null,
    'people': null,
    'description': null,
    'photo': null,
  };

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final pos = await _service.getCurrentLocation();
    String? areaName;
    if (pos != null) {
      areaName = await _service.getAreaName(pos.latitude, pos.longitude);
    }
    if (mounted) {
      setState(() {
        _position = pos;
        _areaName = areaName;
        _loadingLocation = false;
      });
    }
  }

  Future<void> _pickMedia() async {
    if (_mediaFiles.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 5 photos allowed')));
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      final remaining = 5 - _mediaFiles.length;
      final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
      setState(() {
        _mediaFiles.addAll(toAdd);
        _errors['photo'] = null; // clear error once photo added
      });
    }
  }

  bool _validate() {
    final peopleText = _peopleController.text.trim();
    final peopleNum = int.tryParse(peopleText);
    final errs = <String, String?>{
      'checkIn': _checkIn == null ? 'Please select your check-in status' : null,
      'severity': _severity == null
          ? 'Please drag to set a severity level'
          : null,
      'people': peopleText.isEmpty
          ? 'Please enter the number of people affected'
          : (peopleNum == null || peopleNum < 0)
          ? 'Must be a valid number (0 or more)'
          : null,
      'description': _descController.text.trim().isEmpty
          ? 'Please describe what you are observing'
          : null,
      'photo': null,
    };
    setState(() => _errors.addAll(errs));
    return errs.values.every((e) => e == null);
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _submitting = true);

    try {
      final caseId = await _service.submitReport(
        category: widget.category.toLowerCase(),
        checkIn: _checkIn ?? 'safe',
        lat: _position?.latitude,
        lng: _position?.longitude,
        severity: _severity!,
        peopleAffected: int.parse(_peopleController.text.trim()),
        description: _descController.text.trim(),
        mediaFiles: _mediaFiles,
      );

      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Report Submitted',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Case ID: ${caseId.substring(0, 8).toUpperCase()}\nThank you for helping keep your community safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // close dialog
                      Navigator.of(context).pop(); // close form
                      Navigator.of(context).pop(); // close category
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.categoryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(widget.categoryIcon, color: widget.categoryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.category,
              style: TextStyle(
                color: widget.categoryColor,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Self Check-In ───────────────────────────────────────────
            _sectionLabel('Self Check-In', errorKey: 'checkIn'),
            _card(
              child: Row(
                children: [
                  _checkChip('Safe', 'safe', Colors.green),
                  const SizedBox(width: 8),
                  _checkChip('Need Help', 'need_assistance', Colors.orange),
                  const SizedBox(width: 8),
                  _checkChip('Trapped', 'trapped', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Severity ─────────────────────────────────────────────────
            _sectionLabel('Severity', errorKey: 'severity'),
            _card(
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _severity != null
                          ? _severityColor(_severity!)
                          : Colors.grey.shade300,
                      thumbColor: _severity != null
                          ? _severityColor(_severity!)
                          : Colors.grey.shade400,
                      overlayColor:
                          (_severity != null
                                  ? _severityColor(_severity!)
                                  : Colors.grey)
                              .withValues(alpha: 0.15),
                      inactiveTrackColor: Colors.grey.shade200,
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: (_severity ?? 1).toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (v) => setState(() {
                        _severity = v.round();
                        _errors['severity'] = null; // clear error on pick
                      }),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Minor',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      // Badge — shows placeholder when null
                      _severity == null
                          ? Text(
                              'Drag to set',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _severityColor(
                                  _severity!,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_severity/10',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _severityColor(_severity!),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                      Text(
                        'Critical',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Location ─────────────────────────────────────────────────
            _sectionLabel('Location'),
            _card(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: Colors.blue.shade500,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingLocation
                        ? Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Detecting location...',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : _position == null
                        ? GestureDetector(
                            onTap: () {
                              setState(() => _loadingLocation = true);
                              _fetchLocation();
                            },
                            child: Text(
                              'Location unavailable — tap to retry',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _areaName ??
                                    'Lat: ${_position!.latitude.toStringAsFixed(4)}'
                                        '  •  Lng: ${_position!.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Description ──────────────────────────────────────────────
            _sectionLabel('Description', errorKey: 'description'),
            _card(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _descController,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) {
                  if (_errors['description'] != null) {
                    setState(() => _errors['description'] = null);
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Describe what you\'re observing...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            // ── People Affected ───────────────────────────────────────────
            _sectionLabel('People Affected', errorKey: 'people'),
            _card(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _peopleController,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_errors['people'] != null) {
                    setState(() => _errors['people'] = null);
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. 10',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.people_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            // ── Media ─────────────────────────────────────────────────────
            _sectionLabel(
              'Add Photo (Optional)',
              errorKey: 'photo',
              isRequired: false,
            ),

            _card(
              child: Column(
                children: [
                  if (_mediaFiles.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaFiles.length,
                        separatorBuilder: (_, s) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _mediaFiles[i],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _mediaFiles.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_mediaFiles.isNotEmpty) const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.grey.shade400,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mediaFiles.isEmpty
                                ? 'Add Photo'
                                : 'Add More (${_mediaFiles.length}/5)',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Submit button (fixed bottom) ───────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.orange.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(
    String text, {
    String? errorKey,
    bool isRequired = true,
  }) {
    final err = errorKey != null ? _errors[errorKey] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                err,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _checkChip(String label, String value, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _checkIn = value;
        _errors['checkIn'] = null; // clear error on pick
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _checkIn == value ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _checkIn == value ? color : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _checkIn == value ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  Color _severityColor(int v) {
    if (v <= 3) return Colors.green.shade600;
    if (v <= 6) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
