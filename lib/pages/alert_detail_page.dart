import 'package:flutter/material.dart';
import '../models/disaster_model.dart';
import '../models/shelter_model.dart';
import '../services/alerts_service.dart';
import 'safety_route_navigation.dart';

class AlertDetailPage extends StatefulWidget {
  final String disasterId;
  const AlertDetailPage({super.key, required this.disasterId});

  @override
  State<AlertDetailPage> createState() => _Alert_DetailPageState();
}

class _Alert_DetailPageState extends State<AlertDetailPage> {
  final AlertsService _alertsService = AlertsService();
  bool _isMarkedSafe = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DisasterModel?>(
      stream: _alertsService.streamDisasterById(widget.disasterId),
      builder: (context, disasterSnapshot) {
        if (disasterSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final disaster = disasterSnapshot.data;
        if (disaster == null) {
          return const Scaffold(body: Center(child: Text("Alert not found")));
        }

        return StreamBuilder<Map<String, dynamic>>(
          stream: _alertsService.streamAreaMap(),
          builder: (context, areaSnapshot) {
            final areaMap = areaSnapshot.data ?? {};
            String locationName = 'Unknown Location';
            if (disaster.affectedAreaIds.isNotEmpty) {
              final areaId = disaster.affectedAreaIds.first;
              locationName = areaMap[areaId]?['name'] ?? areaId;
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF3F4F7),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Alert Details',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: false,
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMapHeader(disaster),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 20.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleCard(disaster, locationName),
                          const SizedBox(height: 16),
                          _buildDescriptionCard(disaster),
                          const SizedBox(height: 16),
                          _buildRecommendedActionsCard(disaster),
                          const SizedBox(height: 16),
                          _buildSheltersCard(disaster),
                          const SizedBox(height: 32),
                          _buildOfficialSource(),
                          const SizedBox(height: 32),
                          _buildActionButtons(disaster),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapHeader(DisasterModel disaster) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Simplified map representation to match screenshots aesthetic
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFEF4444),
                size: 40,
              ),
            ),
          ),
          // Circular artifacts to simulate map detail
          Positioned(top: 40, left: 60, child: _mapSquare()),
          Positioned(bottom: 60, right: 80, child: _mapSquare()),

          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                "2.3 km",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapSquare() => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _buildTitleCard(DisasterModel disaster, String locationName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  disaster.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSeverityPill(disaster.severity),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.location_on, locationName),
          const SizedBox(height: 12),
          _infoRow(
            Icons.history,
            "Issued: Today, 2:30 PM  •  Updated: ${_formatTime(disaster.updatedAt)}",
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(DisasterModel disaster) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What happened',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            disaster.description,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedActionsCard(DisasterModel disaster) {
    final actions = _getActionsForType(disaster.category);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          ...actions.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheltersCard(DisasterModel disaster) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safe shelters nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ShelterModel>>(
            stream: _alertsService.streamSheltersForAreas(
              disaster.affectedAreaIds,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final shelters = snapshot.data ?? [];
              if (shelters.isEmpty) {
                return const Text(
                  "No shelters found in this area",
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                );
              }

              return Column(
                children: shelters.take(3).map((s) => _shelterCard(s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shelterCard(ShelterModel shelter) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF22C55E),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shelter.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  "Jalan Tun Dr Ismail", // Placeholder
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "1.2 km", // Placeholder
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialSource() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 10),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Official source: ',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              children: [
                TextSpan(
                  text: 'National Disaster Management Agency',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(DisasterModel disaster) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SafetyRouteNavigationScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.send_outlined,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Navigate to shelter',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: const Color(0xFF111827),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isMarkedSafe
                    ? null
                    : () async {
                        setState(() => _isMarkedSafe = true);
                        try {
                          await _alertsService.decrementTotalAffected(
                            disaster.id,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you! Stay safe.'),
                                backgroundColor: Color(0xFF22C55E),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error updating safety status'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => _isMarkedSafe = false);
                          }
                        }
                      },
                icon: const Icon(Icons.person_outline, size: 20),
                label: Text(_isMarkedSafe ? 'Safe' : 'I\'m safe'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: const Color(0xFF111827),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityPill(String severity) {
    Color bg;
    Color text;
    if (severity.toLowerCase() == 'high') {
      bg = const Color(0xFFEF4444);
      text = Colors.white;
    } else if (severity.toLowerCase() == 'medium') {
      bg = const Color(0xFFFFEDD5);
      text = const Color(0xFFF97316);
    } else {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF22C55E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<String> _getActionsForType(String category) {
    if (category == 'Flood')
      return [
        'Move to higher ground immediately',
        'Avoid walking or driving through flooded areas',
        'Turn off electricity and gas if instructed',
        'Stay informed through official channels',
      ];
    if (category == 'Fire')
      return [
        'Evacuate immediately',
        'Stay low to avoid smoke',
        'Call emergency services',
      ];
    if (category == 'Earthquake')
      return [
        'Drop, Cover, and Hold on',
        'Stay away from windows',
        'Move to an open area if outside',
      ];
    return [
      'Follow local evacuation orders',
      'Keep emergency kit ready',
      'Listen to radio for updates',
    ];
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} PM";
  }
}
