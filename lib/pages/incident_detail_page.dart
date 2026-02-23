import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/incident_model.dart';
import '../widgets/severity_legend.dart';

class IncidentDetailPage extends StatefulWidget {
  final IncidentModel incident;
  const IncidentDetailPage({super.key, required this.incident});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final color = severityColor(incident.severity);

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
              incident.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              incident.id,
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
              incident.severity.name.toUpperCase(),
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
        padding: const EdgeInsets.all(0),
        children: [
          // Mini Map
          SizedBox(
            height: 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(incident.lat, incident.lng),
                zoom: 14,
              ),
              onMapCreated: (_) {},
              markers: {
                Marker(
                  markerId: MarkerId(incident.id),
                  position: LatLng(incident.lat, incident.lng),
                  infoWindow: InfoWindow(title: incident.title),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // Main info card
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
                      'Incident Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    _StatusChip(status: incident.status),
                  ],
                ),
                const Divider(height: 18),
                _Row2(
                  l1: 'Incident ID',
                  v1: incident.id,
                  l2: 'Zone',
                  v2: incident.zone,
                ),
                const SizedBox(height: 10),
                _Row2(
                  l1: 'People Affected',
                  v1: incident.peopleAffected.toString(),
                  l2: 'Severity',
                  v2: incident.severity.name.toUpperCase(),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      incident.location,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 3),
                Text(
                  incident.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),

          // Coordinate Response Card
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
                const Divider(height: 16),
                _ResponseItem(
                  icon: Icons.local_police,
                  label: 'Police Unit',
                  status: 'Dispatched',
                  statusColor: const Color(0xFF1A56DB),
                ),
                _ResponseItem(
                  icon: Icons.local_fire_department,
                  label: 'Fire Brigade',
                  status: 'En Route',
                  statusColor: const Color(0xFFF97316),
                ),
                _ResponseItem(
                  icon: Icons.medical_services,
                  label: 'Medical Team',
                  status: 'Standby',
                  statusColor: const Color(0xFF22C55E),
                ),
                _ResponseItem(
                  icon: Icons.engineering,
                  label: 'Civil Defence',
                  status: 'Requested',
                  statusColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Response coordinates updated!'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Coordination Update'),
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
                      'Incident Timeline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _TimelineItem(
                  time: _formatTime(incident.timestamp),
                  label: 'Incident reported',
                  color: const Color(0xFFEF4444),
                ),
                _TimelineItem(
                  time: _formatTime(
                    incident.timestamp.add(const Duration(minutes: 3)),
                  ),
                  label: 'Emergency services notified',
                  color: const Color(0xFFF97316),
                ),
                _TimelineItem(
                  time: _formatTime(
                    incident.timestamp.add(const Duration(minutes: 8)),
                  ),
                  label: 'Units dispatched',
                  color: const Color(0xFF1A56DB),
                ),
                _TimelineItem(
                  time: _formatTime(DateTime.now()),
                  label: 'Status: ${incident.status}',
                  color: const Color(0xFF22C55E),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

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

class _ResponseItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color statusColor;
  const _ResponseItem({
    required this.icon,
    required this.label,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
