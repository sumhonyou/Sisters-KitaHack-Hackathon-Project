import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/reported_case_model.dart';
import '../models/area_model.dart';
import '../models/severity.dart'; // for Severity + severityColor
import '../services/firestore_service.dart';
import '../widgets/severity_legend.dart';
import '../widgets/case_card.dart';
import '../widgets/area_card.dart';
import 'case_detail_page.dart';
import 'area_cases_page.dart';
import '../services/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  final AiService _aiService = AiService();

  late TabController _tabController;
  bool _isHeatmap = true;
  GoogleMapController? _mapController;
  ReportedCase? _selectedCase;
  CameraPosition? _lastCameraPosition;

  // AI Summary States
  Map<String, dynamic>? _aiInsightData;
  bool _isSummarizing = false;
  List<ReportedCase> _lastAnalyzedIncidents = [];
  final Map<String, String> _areaNames = {};
  bool _areasLoaded = false;
  bool _showAllDisasters = false;

  static const LatLng _klCenter = LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.seedSampleDataIfEmpty();
    _loadAreaNames();
  }

  Future<void> _loadAreaNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('areas')
          .get();
      final Map<String, String> loadedNames = {};
      for (var doc in snapshot.docs) {
        final name = doc.data()['name'] as String?;
        if (name != null) loadedNames[doc.id] = name;
      }
      if (mounted) {
        setState(() {
          _areaNames.clear();
          _areaNames.addAll(loadedNames);
          _areasLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading area names: $e");
      if (mounted) setState(() => _areasLoaded = true);
    }
  }

  String _getAreaName(String areaId) {
    return _areaNames[areaId] ?? areaId;
  }

  Future<void> _syncDisastersToFirestore(List<dynamic> groups) async {
    final db = FirebaseFirestore.instance;
    for (var group in groups) {
      final disasterId = group['disasterId']?.toString();
      if (disasterId == null) continue;

      final docRef = db.collection('disasters').doc(disasterId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'disasterID': disasterId,
          'Type': group['Type'] ?? 'Unknown',
          'severity': group['severity'] ?? 'Medium',
          'title': group['title'] ?? 'New Disaster',
          'description': group['description'] ?? '',
          'affectedAreaIds': group['affectedAreaIds'] ?? [],
          'Status': group['Status'] ?? 'Active',
          'updatedAt': group['updatedAt'] != null
              ? Timestamp.fromDate(DateTime.parse(group['updatedAt']))
              : FieldValue.serverTimestamp(),
          'incidentCount': group['incidentCount'] ?? 0,
          'totalAffected': group['totalAffected'] ?? 0,
        });
      }
    }
  }

  Future<void> _generateAiSummary(List<ReportedCase> incidents) async {
    if (incidents.isEmpty) return;

    if (_aiInsightData != null &&
        incidents.length == _lastAnalyzedIncidents.length) {
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      bool needsRecheck = false;
      for (var inc in incidents) {
        final aid = inc.areaId;
        if (aid.isNotEmpty && !_areaNames.containsKey(aid)) {
          needsRecheck = true;
          break;
        }
      }

      if (needsRecheck) await _loadAreaNames();

      // Convert ReportedCase objects to Maps for the AI Service
      final mappedIncidents = incidents
          .map(
            (rc) => {
              'caseId': rc.caseId,
              'areaId': rc.areaId,
              'category': rc.category,
              'severity': rc.severityLevel,
              'peopleAffected': rc.peopleAffected,
              'description': rc.description,
            },
          )
          .toList();

      final insightData = await _aiService.summarizeIncidents(
        mappedIncidents,
        _areaNames,
      );

      if (mounted) {
        setState(() {
          _aiInsightData = insightData;
          _isSummarizing = false;
          _lastAnalyzedIncidents = incidents;
        });

        if (insightData['groups'] != null) {
          _syncDisastersToFirestore(insightData['groups']);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSummarizing = false);
    }
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

  Widget _buildHeatmapView(List<ReportedCase> cases) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
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
          ),
        ),
        const SliverToBoxAdapter(child: SeverityLegend()),
        if (_selectedCase == null) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildAiSummarySection()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
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

  Widget _buildCasesTab(List<ReportedCase> cases, List<AreaModel> areas) {
    final filtered = _filterAndSort(cases);
    final totalItems = filtered.length;

    // Safety check range
    if (_caseOffset >= totalItems && totalItems > 0) {
      _caseOffset = 0;
    }

    final endIndex = (_caseOffset + 10 > totalItems)
        ? totalItems
        : (_caseOffset + 10);
    final displayCases = filtered.sublist(_caseOffset, endIndex);

    int totalIncidents = filtered.length;
    int criticalCases = filtered
        .where((c) => c.severity == Severity.critical)
        .length;
    int peopleTrapped = filtered
        .where(
          (c) =>
              c.status == 'need_assistance' || c.checkIn == 'need_assistance',
        )
        .fold(0, (acc, c) => acc + c.peopleAffected);
    int totalAffected = filtered.fold(0, (acc, c) => acc + c.peopleAffected);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatsGrid(
                  totalIncidents,
                  criticalCases,
                  peopleTrapped,
                  totalAffected,
                ),
                const SizedBox(height: 16),
                _buildFilterSection(),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Reported Incidents',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_caseOffset + 1}-$endIndex of $totalItems',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (_caseOffset > 0) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(
                      () =>
                          _caseOffset = (_caseOffset - 10).clamp(0, totalItems),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '< Prev',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
                if (endIndex < totalItems) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _caseOffset += 10),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Next >',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (displayCases.isEmpty)
          SliverFillRemaining(
            child: Center(
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
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final rc = displayCases[i];
              final area = areas
                  .where((a) => a.areaId == rc.areaId)
                  .firstOrNull;
              final areaName = area?.name ?? 'Unknown Area';
              return CaseCardCompact(
                reportedCase: rc,
                areaName: areaName,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => CaseDetailPage(reportedCase: rc),
                  ),
                ),
              );
            }, childCount: displayCases.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
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

            // Content — stream both collections together
            Expanded(
              child: StreamBuilder<List<ReportedCase>>(
                stream: _service.reportedCasesStream(),
                builder: (context, caseSnap) {
                  if (caseSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final cases = caseSnap.data ?? [];

                  // Trigger automatic AI analysis if not already doing it
                  if (_areasLoaded &&
                      !_isSummarizing &&
                      (_aiInsightData == null ||
                          cases.length != _lastAnalyzedIncidents.length)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _generateAiSummary(cases);
                    });
                  }

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
                          _buildCasesTab(patchedCases, areas),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter states
  int _caseOffset = 0;
  String _selectedSeverity = 'All';
  String _selectedType = 'All';
  String _selectedStatus = 'All';
  String _selectedTime = 'All Time';

  // Sort state
  String _sortBy = 'Newest';
  final _sorts = const ['Newest', 'Most Affected', 'Severity'];

  List<ReportedCase> _filterAndSort(List<ReportedCase> cases) {
    var list = cases.where((c) {
      if (_selectedSeverity != 'All') {
        if (c.severity.name.toLowerCase() != _selectedSeverity.toLowerCase())
          return false;
      }

      if (_selectedType != 'All' &&
          c.category.toLowerCase() != _selectedType.toLowerCase()) {
        return false;
      }

      if (_selectedStatus != 'All' &&
          c.checkIn.toLowerCase() != _selectedStatus.toLowerCase()) {
        return false;
      }

      // Filter Time
      if (_selectedTime != 'All Time') {
        final now = DateTime.now();
        final timestamp = c.timestamp;

        if (_selectedTime == 'Today' &&
            timestamp.isBefore(DateTime(now.year, now.month, now.day))) {
          return false;
        }
        if (_selectedTime == 'Last 7 Days' &&
            timestamp.isBefore(now.subtract(const Duration(days: 7)))) {
          return false;
        }
        if (_selectedTime == 'Last 30 Days' &&
            timestamp.isBefore(now.subtract(const Duration(days: 30)))) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sortBy) {
      case 'Newest':
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Most Affected':
        list.sort((a, b) => b.peopleAffected.compareTo(a.peopleAffected));
        break;
      case 'Severity':
        const order = ['critical', 'high', 'medium', 'low'];
        list.sort(
          (a, b) => order
              .indexOf(a.severity.name)
              .compareTo(order.indexOf(b.severity.name)),
        );
        break;
    }
    return list;
  }

  Widget _buildStatsGrid(int total, int critical, int trapped, int affected) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.65,
      children: [
        _buildStatsCard(
          'Total Incidents',
          '$total',
          'Active reports',
          Icons.article_outlined,
          Colors.blue.shade700,
          Colors.blue.shade50,
        ),
        _buildStatsCard(
          'Critical Cases',
          '$critical',
          'Immediate attention',
          Icons.warning_amber_rounded,
          Colors.red.shade700,
          Colors.red.shade50,
        ),
        _buildStatsCard(
          'People Trapped',
          '$trapped',
          'Rescue needed',
          Icons.hail_rounded,
          Colors.orange.shade700,
          Colors.orange.shade50,
        ),
        _buildStatsCard(
          'People Affected',
          '$affected',
          'Across all incidents',
          Icons.people_outline_rounded,
          Colors.indigo.shade700,
          Colors.indigo.shade50,
        ),
      ],
    );
  }

  Widget _buildStatsCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: Colors.grey),
              const SizedBox(width: 10),
              const Text(
                'Filter Incidents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _caseOffset = 0;
                    _selectedSeverity = 'All';
                    _selectedType = 'All';
                    _selectedStatus = 'All';
                    _selectedTime = 'All Time';
                    _sortBy = 'Newest';
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
              const Spacer(),
              _buildFilterDropdown(
                '',
                _sortBy,
                _sorts,
                (val) => setState(() => _sortBy = val!),
                width: 130, // Make wider to fit Most Affected
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Severity',
                  _selectedSeverity,
                  ['All', 'Critical', 'High', 'Medium', 'Low'],
                  (val) => setState(() => _selectedSeverity = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Type', _selectedType, [
                  'All',
                  'Flood',
                  'Fire',
                  'Storm',
                  'Earthquake',
                  'Other',
                ], (val) => setState(() => _selectedType = val!)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  ['All', 'Reported', 'Need_assistance', 'Rescued', 'Safe'],
                  (val) => setState(() => _selectedStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Time', _selectedTime, [
                  'All Time',
                  'Today',
                  'Last 7 Days',
                  'Last 30 Days',
                ], (val) => setState(() => _selectedTime = val!)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged, {
    double? width,
  }) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: items
                  .map(
                    (String item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
    return width != null ? SizedBox(width: width, child: body) : body;
  }

  Widget _buildAiSummarySection() {
    if (_isSummarizing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'AI is analyzing recent incidents...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_aiInsightData == null) return const SizedBox.shrink();

    final summary = _aiInsightData!['summary']?.toString() ?? '';
    final groups = _aiInsightData!['groups'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Color(0xFF1A56DB),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Intelligence Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A56DB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Analyzed Disasters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...groups
                .take(_showAllDisasters ? groups.length : 2)
                .map((g) => _buildDisasterGroupCard(g as Map<String, dynamic>)),
            if (groups.length > 2)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllDisasters = !_showAllDisasters;
                    });
                  },
                  child: Text(
                    _showAllDisasters ? 'Show less' : 'Show all',
                    style: const TextStyle(
                      color: Color(0xFF1A56DB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisasterGroupCard(Map<String, dynamic> group) {
    final areaIds = group['affectedAreaIds'] as List? ?? [];
    final rawAreaId = areaIds.isNotEmpty ? areaIds[0].toString() : '';
    final areaName = rawAreaId.isNotEmpty
        ? _getAreaName(rawAreaId)
        : (group['area']?.toString() ?? 'Unknown Area');
    final severity = group['severity']?.toString() ?? 'Medium';
    final severityColor = _getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 14, color: severityColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    areaName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    severity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['title']?.toString() ?? 'Incident Group',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group['analysis']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat(
                      Icons.article_outlined,
                      '${group['incidentCount']} Cases',
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      Icons.people_outline,
                      '${group['totalAffected']} Affected',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
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

class CaseCardCompact extends StatelessWidget {
  final ReportedCase reportedCase;
  final String areaName;
  final VoidCallback onTap;
  const CaseCardCompact({
    super.key,
    required this.reportedCase,
    required this.areaName,
    required this.onTap,
  });

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final rc = reportedCase;
    final color = severityColor(rc.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.35)),
      ),
      color: color.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: rc.media.isNotEmpty
                    ? Image.network(
                        rc.media.first,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _defaultIcon(color),
                      )
                    : _defaultIcon(color),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: rc.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                TextSpan(
                                  text: ' • $areaName',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rc.severity.name.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rc.description.isNotEmpty ? rc.description : '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${rc.peopleAffected} affected',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(rc.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.warning_amber_rounded, color: color, size: 28),
    );
  }
}
