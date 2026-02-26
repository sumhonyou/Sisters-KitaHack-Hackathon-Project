import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/reported_case_model.dart';
import '../models/area_model.dart';
import '../models/severity.dart'; // for Severity + severityColor
import '../services/firestore_service.dart';
import '../widgets/app_header.dart';
import '../widgets/severity_legend.dart';
import '../widgets/case_card.dart';
import '../widgets/area_card.dart';
import 'case_detail_page.dart';
import 'area_cases_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late TabController _tabController;
  bool _isHeatmap = true;
  GoogleMapController? _mapController;
  ReportedCase? _selectedCase;
  CameraPosition? _lastCameraPosition;

  static const LatLng _klCenter = LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.seedSampleDataIfEmpty();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Severity helpers ──────────────────────────────────────────────────────
  BitmapDescriptor _markerIcon(Severity s) {
    switch (s) {
      case Severity.critical:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case Severity.high:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case Severity.medium:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case Severity.low:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  double _circleRadius(Severity s) {
    switch (s) {
      case Severity.critical:
        return 2200;
      case Severity.high:
        return 1800;
      case Severity.medium:
        return 1400;
      case Severity.low:
        return 900;
    }
  }

  // ── Map builders ─────────────────────────────────────────────────────────
  Set<Marker> _buildMarkers(List<ReportedCase> cases) {
    return cases
        .map(
          (c) => Marker(
            markerId: MarkerId(c.id),
            position: LatLng(c.lat, c.lng),
            icon: _markerIcon(c.severity),
            infoWindow: InfoWindow(
              title: c.category.toUpperCase(),
              snippet: c.description.length > 60
                  ? '${c.description.substring(0, 60)}…'
                  : c.description,
            ),
            onTap: () {
              setState(() => _selectedCase = c);
              _showCaseBottomSheet(c);
            },
          ),
        )
        .toSet();
  }

  Set<Circle> _buildCircles(List<ReportedCase> cases) {
    final Set<Circle> circles = {};
    for (final c in cases) {
      final color = severityColor(c.severity);
      final r = _circleRadius(c.severity);
      circles.add(
        Circle(
          circleId: CircleId('${c.id}_outer'),
          center: LatLng(c.lat, c.lng),
          radius: r,
          strokeColor: color.withValues(alpha: 0.35),
          strokeWidth: 1,
          fillColor: color.withValues(alpha: 0.07),
        ),
      );
      circles.add(
        Circle(
          circleId: CircleId('${c.id}_inner'),
          center: LatLng(c.lat, c.lng),
          radius: r * 0.55,
          strokeColor: color.withValues(alpha: 0.5),
          strokeWidth: 2,
          fillColor: color.withValues(alpha: 0.12),
        ),
      );
    }
    return circles;
  }

  void _showCaseBottomSheet(ReportedCase rc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: CaseCard(
                    reportedCase: rc,
                    onViewDetails: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CaseDetailPage(reportedCase: rc),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Heatmap view ──────────────────────────────────────────────────────────
  Widget _buildHeatmapView(List<ReportedCase> cases) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition:
                  _lastCameraPosition ??
                  const CameraPosition(target: _klCenter, zoom: 11.5),
              onMapCreated: (c) => _mapController = c,
              onCameraMove: (pos) => _lastCameraPosition = pos,
              markers: _buildMarkers(cases),
              circles: _buildCircles(cases),
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),
        ),
        const SeverityLegend(),
        if (_selectedCase == null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                const Icon(Icons.touch_app, size: 32, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 6),
                Text(
                  'Tap a marker to view case details',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Grid view (areas) ─────────────────────────────────────────────────────
  Widget _buildGridView(List<ReportedCase> cases, List<AreaModel> areas) {
    // Map areaId → list of cases
    final Map<String, List<ReportedCase>> byCases = {};
    for (final c in cases) {
      byCases.putIfAbsent(c.areaId, () => []).add(c);
    }

    final List<AreaModel> displayAreas = List<AreaModel>.from(areas);
    final Set<String> areaIdSet = areas.map((a) => a.areaId).toSet();

    // Check if there are any cases with areaId that is NOT in the areas list
    final List<ReportedCase> orphanedCases = [];
    byCases.forEach((areaId, casesInArea) {
      if (!areaIdSet.contains(areaId)) {
        orphanedCases.addAll(casesInArea);
      }
    });

    if (orphanedCases.isNotEmpty) {
      // Add a "General" area for these orphaned cases
      const generalId = 'general_unresolved';
      displayAreas.add(
        AreaModel(
          id: generalId,
          areaId: generalId,
          name: 'OTHER LOCATIONS',
          centerLat: 3.1390,
          centerLng: 101.6869,
          radiusKm: 0,
        ),
      );
      byCases[generalId] = orphanedCases;
    }

    displayAreas.sort((a, b) => a.name.compareTo(b.name));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Select Area to View Cases',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ),
        if (displayAreas.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No areas configured yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final area = displayAreas[i];
                final areaCases = byCases[area.areaId] ?? [];
                // Pick first media image as thumbnail
                String? thumbnail;
                for (final c in areaCases) {
                  if (c.media.isNotEmpty) {
                    thumbnail = c.media.first;
                    break;
                  }
                }
                return AreaCard(
                  area: area,
                  cases: areaCases,
                  thumbnailUrl: thumbnail,
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          AreaCasesPage(area: area, cases: areaCases),
                    ),
                  ),
                );
              }, childCount: displayAreas.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────
  Widget _buildTabContent(List<ReportedCase> cases, List<AreaModel> areas) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                _ToggleBtn(
                  icon: Icons.location_on,
                  label: 'Heatmap',
                  selected: _isHeatmap,
                  onTap: () => setState(() => _isHeatmap = true),
                ),
                _ToggleBtn(
                  icon: Icons.grid_view,
                  label: 'Grid',
                  selected: !_isHeatmap,
                  onTap: () => setState(() => _isHeatmap = false),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isHeatmap
              ? _buildHeatmapView(cases)
              : _buildGridView(cases, areas),
        ),
      ],
    );
  }

  Widget _buildCasesTab(List<ReportedCase> cases) {
    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'No reported cases yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cases.length,
      itemBuilder: (ctx, i) => CaseCard(
        reportedCase: cases[i],
        onViewDetails: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => CaseDetailPage(reportedCase: cases[i]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            const Divider(height: 1),
            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF1A56DB),
                labelColor: const Color(0xFF1A56DB),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.map_outlined, size: 16),
                    text: 'Map',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.info_outline, size: 16),
                    text: 'Cases',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),
            // Title
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Urban Safety Map',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Real-time case tracking and area monitoring',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content — stream both collections together
            Expanded(
              child: StreamBuilder<List<ReportedCase>>(
                stream: _service.reportedCasesStream(),
                builder: (context, caseSnap) {
                  if (caseSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cases = caseSnap.data ?? [];

                  return StreamBuilder<List<AreaModel>>(
                    stream: _service.areasStream(),
                    builder: (context, areaSnap) {
                      final areas = areaSnap.data ?? [];

                      // Patch case lat/lng using area center GeoPoint as fallback
                      final patchedCases = cases.map((c) {
                        if (c.lat == 3.1390 && c.lng == 101.6869) {
                          // Try area fallback
                          try {
                            final area = areas.firstWhere(
                              (a) => a.areaId == c.areaId,
                            );
                            return ReportedCase(
                              id: c.id,
                              caseId: c.caseId,
                              areaId: c.areaId,
                              category: c.category,
                              checkIn: c.checkIn,
                              description: c.description,
                              locationLabel: c.locationLabel,
                              lat: area.centerLat,
                              lng: area.centerLng,
                              media: c.media,
                              peopleAffected: c.peopleAffected,
                              reporterUid: c.reporterUid,
                              severityLevel: c.severityLevel,
                              severity: c.severity,
                              status: c.status,
                              timestamp: c.timestamp,
                            );
                          } catch (_) {
                            return c; // no matching area, use KL center
                          }
                        }
                        return c;
                      }).toList();

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabContent(patchedCases, areas),
                          _buildCasesTab(patchedCases),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // Footer
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Column(
                children: [
                  Text(
                    '© 2026 City Guard - SDG 11',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                  Text(
                    'Emergency: 999',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
