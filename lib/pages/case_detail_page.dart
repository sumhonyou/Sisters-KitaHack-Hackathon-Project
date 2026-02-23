import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/reported_case_model.dart';
import '../widgets/severity_legend.dart';
import '../services/firestore_service.dart';

class CaseDetailPage extends StatefulWidget {
  final ReportedCase reportedCase;
  const CaseDetailPage({super.key, required this.reportedCase});

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  final FirestoreService _service = FirestoreService();
  bool _isSaving = false;

  // ── Coordinate Response state ─────────────────────────────────────────────
  static const List<String> _statusCycle = [
    'None',
    'Requested',
    'Dispatched',
    'En Route',
    'On Scene',
    'Returned',
  ];

  static const List<Map<String, dynamic>> _units = [
    {
      'key': 'police',
      'label': 'Police Unit',
      'icon': Icons.local_police,
      'color': Color(0xFF1A56DB),
    },
    {
      'key': 'fire',
      'label': 'Fire Brigade',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFF97316),
    },
    {
      'key': 'medical',
      'label': 'Medical Team',
      'icon': Icons.medical_services,
      'color': Color(0xFF22C55E),
    },
    {
      'key': 'civil',
      'label': 'Civil Defence',
      'icon': Icons.engineering,
      'color': Color(0xFF8B5CF6),
    },
  ];

  late Map<String, String> _unitStatuses;

  @override
  void initState() {
    super.initState();
    // Initialise all units to 'None'
    _unitStatuses = {for (final u in _units) u['key'] as String: 'None'};
  }

  void _cycleStatus(String key) {
    setState(() {
      final current = _unitStatuses[key]!;
      final idx = _statusCycle.indexOf(current);
      _unitStatuses[key] = _statusCycle[(idx + 1) % _statusCycle.length];
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Requested':
        return const Color(0xFF8B5CF6);
      case 'Dispatched':
        return const Color(0xFF1A56DB);
      case 'En Route':
        return const Color(0xFFF97316);
      case 'On Scene':
        return const Color(0xFF22C55E);
      case 'Returned':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFD1D5DB);
    }
  }

  Future<void> _sendUpdate() async {
    setState(() => _isSaving = true);
    try {
      await _service.updateCaseResponseStatus(
        widget.reportedCase.id,
        Map<String, String>.from(_unitStatuses),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response coordination updated!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final rc = widget.reportedCase;
    final color = severityColor(rc.severity);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rc.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              rc.caseId,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rc.severity.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Mini map using area center or case coordinates
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(rc.lat, rc.lng),
                zoom: 14,
              ),
              onMapCreated: (_) {},
              markers: {
                Marker(
                  markerId: MarkerId(rc.id),
                  position: LatLng(rc.lat, rc.lng),
                  infoWindow: InfoWindow(title: rc.category.toUpperCase()),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // Media gallery
          if (rc.media.isNotEmpty) _buildMediaGallery(rc),

          // Overview card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFF374151),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Case Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    _StatusChip(status: rc.status),
                  ],
                ),
                const Divider(height: 18),
                _Row2(
                  l1: 'Case ID',
                  v1: rc.caseId,
                  l2: 'Area ID',
                  v2: rc.areaId,
                ),
                const SizedBox(height: 10),
                _Row2(
                  l1: 'People Affected',
                  v1: rc.peopleAffected.toString(),
                  l2: 'Category',
                  v2: rc.category,
                ),
                const SizedBox(height: 10),
                _Row2(
                  l1: 'Check-In',
                  v1: rc.checkIn.isEmpty ? '—' : rc.checkIn,
                  l2: 'Reporter UID',
                  v2: rc.reporterUid.length > 10
                      ? '${rc.reporterUid.substring(0, 10)}…'
                      : rc.reporterUid,
                ),
                if (rc.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rc.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Coordinate Response (interactive) ───────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub, size: 18, color: Color(0xFF1A56DB)),
                    SizedBox(width: 6),
                    Text(
                      'Coordinate Response',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a status badge to cycle through response stages',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Divider(height: 16),
                // Unit rows
                ..._units.map((unit) {
                  final key = unit['key'] as String;
                  final status = _unitStatuses[key]!;
                  final unitColor = unit['color'] as Color;
                  final statusCol = _statusColor(status);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: unitColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            unit['icon'] as IconData,
                            size: 18,
                            color: unitColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            unit['label'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Tappable status chip
                        GestureDetector(
                          onTap: () => _cycleStatus(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusCol.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusCol.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusCol,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.touch_app,
                                  size: 12,
                                  color: statusCol.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _sendUpdate,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(
                      _isSaving ? 'Saving…' : 'Send Coordination Update',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Timeline card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, size: 18, color: Color(0xFF374151)),
                    SizedBox(width: 6),
                    Text(
                      'Case Timeline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _TimelineItem(
                  time: _formatTime(rc.timestamp),
                  label: 'Case reported',
                  color: const Color(0xFFEF4444),
                ),
                _TimelineItem(
                  time: _formatTime(
                    rc.timestamp.add(const Duration(minutes: 3)),
                  ),
                  label: 'Emergency services notified',
                  color: const Color(0xFFF97316),
                ),
                _TimelineItem(
                  time: _formatTime(
                    rc.timestamp.add(const Duration(minutes: 8)),
                  ),
                  label: 'Units dispatched',
                  color: const Color(0xFF1A56DB),
                ),
                _TimelineItem(
                  time: _formatTime(DateTime.now()),
                  label: 'Status: ${rc.status}',
                  color: const Color(0xFF22C55E),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(ReportedCase rc) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: Color(0xFF374151),
                ),
                SizedBox(width: 6),
                Text(
                  'Reported Media',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              scrollDirection: Axis.horizontal,
              itemCount: rc.media.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _showFullImage(context, rc.media[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    rc.media[i],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.broken_image,
                        size: 36,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Row2 extends StatelessWidget {
  final String l1, v1, l2, v2;
  const _Row2({
    required this.l1,
    required this.v1,
    required this.l2,
    required this.v2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l1,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                v1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l2,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                v2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String label;
  final Color color;
  final bool isLast;
  const _TimelineItem({
    required this.time,
    required this.label,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (!isLast)
              Container(width: 2, height: 28, color: Colors.grey.shade200),
          ],
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
