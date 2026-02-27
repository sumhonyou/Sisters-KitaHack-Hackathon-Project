import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';

// Your API Keys
const _geminiApiKey = 'AIzaSyDr5pYhrIyk77ofyJ7gSC88zGtiP8zS7Qg';
const _googleMapsApiKey = 'AIzaSyCzLAdN1glYnTu_spLSfiDJf8W-YMkqUXY';

class Shelter {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int capacityCurrent;
  final int capacityTotal;
  final String status;
  final List<String> tags;
  final String phone;
  final String? imageURL;

  // Calculated fields
  double distanceMeters = double.infinity;
  int etaSeconds = 0;
  String? encodedPolyline;
  String? recommendationReason;

  Shelter({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.capacityCurrent,
    required this.capacityTotal,
    required this.status,
    required this.tags,
    required this.phone,
    this.imageURL,
  });

  factory Shelter.fromFirestore(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Document is empty");

    double parsedLat = 0.0;
    double parsedLng = 0.0;

    // Safely parse location whether it is saved as a GeoPoint, an array, or a map
    if (data['location'] is GeoPoint) {
      GeoPoint loc = data['location'];
      parsedLat = loc.latitude;
      parsedLng = loc.longitude;
    } else if (data['location'] is List) {
      List locArr = data['location'];
      if (locArr.length >= 2) {
        parsedLat = (locArr[0] as num).toDouble();
        parsedLng = (locArr[1] as num).toDouble();
      }
    } else if (data['location'] is Map) {
      Map locMap = data['location'];
      parsedLat = (locMap['latitude'] ?? locMap['lat'] ?? 0.0).toDouble();
      parsedLng = (locMap['longitude'] ?? locMap['lng'] ?? 0.0).toDouble();
    }

    List<dynamic> dynamicTags = data['tags'] ?? [];
    // If tags are empty or not provided, we mock them for the UI demo based on the mock data design
    List<String> parsedTags = dynamicTags.map((e) => e.toString()).toList();
    if (parsedTags.isEmpty) {
      parsedTags = ['Medical', 'Food', 'WiFi', 'Access']; // Mock default tags
    }

    return Shelter(
      id: doc.id,
      name: data['name'] ?? 'Unknown Shelter',
      lat: parsedLat,
      lng: parsedLng,
      capacityCurrent: data['capacityCurrent'] ?? 0,
      capacityTotal: data['capacityTotal'] ?? 100,
      status: data['status']?.toString().toLowerCase() ?? 'closed',
      tags: parsedTags,
      phone: data['contactPhone'] ?? '',
      imageURL: data['imageURL'],
    );
  }
}

class SafetyRouteNavigationScreen extends StatefulWidget {
  const SafetyRouteNavigationScreen({super.key});

  @override
  _SafetyRouteNavigationScreenState createState() =>
      _SafetyRouteNavigationScreenState();
}

class _SafetyRouteNavigationScreenState
    extends State<SafetyRouteNavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _loadingText = "Locating you...";

  List<Shelter> _recommendedShelters = [];
  Shelter? _selectedShelter;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  String _travelMode = 'DRIVE'; // 'DRIVE' or 'WALK'

  final String _mapStyle = '''
  [
    {
      "featureType": "all",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#7c93a3"}]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry.fill",
      "stylers": [{"color": "#ebe5eb"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.fill",
      "stylers": [{"color": "#ffffff"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    try {
      debugPrint("====== INIT SAFETY ROUTE NAVIGATION ======");
      debugPrint("Google Maps Key Configured: ${_googleMapsApiKey.isNotEmpty}");
      debugPrint("Gemini Key Configured: ${_geminiApiKey.isNotEmpty}");

      debugPrint(">>> Step 0: Getting user location...");
      await _getUserLocation();
      debugPrint(
        ">>> Step 0 DONE (${stopwatch.elapsedMilliseconds}ms) — Location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}",
      );

      debugPrint(">>> Step 1: Fetching shelters from Firestore...");
      setState(() => _loadingText = "Finding nearby shelters...");
      List<Shelter> allShelters = await _fetchSheltersFromFirestore();
      debugPrint(
        ">>> Step 1 DONE (${stopwatch.elapsedMilliseconds}ms) — Found ${allShelters.length} shelters",
      );

      if (allShelters.isEmpty) {
        throw Exception("No shelters found in database.");
      }

      // Filter and get top 5 nearest by straight-line distance
      _sortSheltersByDistance(allShelters);
      List<Shelter> candidateShelters = allShelters.take(5).toList();
      debugPrint(
        "Top ${candidateShelters.length} candidates selected by distance.",
      );

      debugPrint(">>> Step 2: Calculating routes for candidates...");
      setState(() => _loadingText = "Calculating fastest routes...");
      await _calculateRoutesForCandidates(candidateShelters);
      debugPrint(">>> Step 2 DONE (${stopwatch.elapsedMilliseconds}ms)");

      debugPrint(">>> Step 3: AI ranking with Gemini...");
      setState(() => _loadingText = "AI is evaluating safety & suitability...");
      _recommendedShelters = await _rankWithGemini(candidateShelters);
      debugPrint(">>> Step 3 DONE (${stopwatch.elapsedMilliseconds}ms)");

      if (_recommendedShelters.isNotEmpty) {
        _selectedShelter = _recommendedShelters.first;
        _updateMap();
      }

      debugPrint(
        "====== INIT COMPLETE in ${stopwatch.elapsedMilliseconds}ms ======",
      );
    } catch (e) {
      debugPrint(
        "!!! ERROR initializing screen (${stopwatch.elapsedMilliseconds}ms): $e",
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getUserLocation() async {
    debugPrint("[Location] Checking if location services are enabled...");
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint("[Location] Service enabled: $serviceEnabled");
    if (!serviceEnabled) {
      debugPrint(
        "[Location] WARNING: Location services disabled — using default location",
      );
      // Use default Kuala Lumpur location instead of throwing
      _currentPosition = null;
      _useDefaultLocation();
      return;
    }

    debugPrint("[Location] Checking permission...");
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint("[Location] Current permission: $permission");
    if (permission == LocationPermission.denied) {
      debugPrint("[Location] Requesting permission...");
      permission = await Geolocator.requestPermission();
      debugPrint("[Location] Permission after request: $permission");
      if (permission == LocationPermission.denied) {
        debugPrint("[Location] Permission denied — using default location");
        _useDefaultLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        "[Location] Permission permanently denied — using default location",
      );
      _useDefaultLocation();
      return;
    }

    // Try 1: Get current position with LOW accuracy (fast, uses network/WiFi — works on emulators)
    debugPrint(
      "[Location] Attempt 1: getCurrentPosition with LOW accuracy (5s timeout)...",
    );
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      debugPrint(
        "[Location] Attempt 1 SUCCESS: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}",
      );
      return;
    } catch (e) {
      debugPrint("[Location] Attempt 1 FAILED: $e");
    }

    // Try 2: Get last known position (instant, cached)
    debugPrint("[Location] Attempt 2: getLastKnownPosition...");
    try {
      _currentPosition = await Geolocator.getLastKnownPosition();
      if (_currentPosition != null) {
        debugPrint(
          "[Location] Attempt 2 SUCCESS: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}",
        );
        return;
      }
      debugPrint("[Location] Attempt 2 returned null (no cached location)");
    } catch (e) {
      debugPrint("[Location] Attempt 2 FAILED: $e");
    }

    // Try 3: Final attempt with medium accuracy and longer timeout
    debugPrint(
      "[Location] Attempt 3: getCurrentPosition with MEDIUM accuracy (8s timeout)...",
    );
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      debugPrint(
        "[Location] Attempt 3 SUCCESS: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}",
      );
      return;
    } catch (e) {
      debugPrint("[Location] Attempt 3 FAILED: $e");
    }

    // All attempts failed — use default location so the app doesn't hang
    debugPrint(
      "[Location] ALL ATTEMPTS FAILED — falling back to default location",
    );
    _useDefaultLocation();
  }

  /// Fallback default location (Kuala Lumpur city center) when GPS is unavailable
  void _useDefaultLocation() {
    debugPrint(
      "[Location] Using default location: Kuala Lumpur (3.1390, 101.6869)",
    );
    _currentPosition = Position(
      latitude: 3.1390,
      longitude: 101.6869,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  Future<List<Shelter>> _fetchSheltersFromFirestore() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('shelters')
        .get();
    return querySnapshot.docs.map((doc) => Shelter.fromFirestore(doc)).toList();
  }

  void _sortSheltersByDistance(List<Shelter> shelters) {
    if (_currentPosition == null) return;
    for (var shelter in shelters) {
      shelter.distanceMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        shelter.lat,
        shelter.lng,
      );
    }
    shelters.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<void> _calculateRoutesForCandidates(List<Shelter> shelters) async {
    if (_currentPosition == null) return;
    final origin = {
      "location": {
        "latLng": {
          "latitude": _currentPosition!.latitude,
          "longitude": _currentPosition!.longitude,
        },
      },
    };

    List<Future<void>> routeFutures = shelters.map((shelter) async {
      final destination = {
        "location": {
          "latLng": {"latitude": shelter.lat, "longitude": shelter.lng},
        },
      };

      try {
        final response = await http
            .post(
              Uri.parse(
                'https://routes.googleapis.com/directions/v2:computeRoutes',
              ),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': _googleMapsApiKey,
                'X-Goog-FieldMask':
                    'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
              },
              body: jsonEncode({
                "origin": origin,
                "destination": destination,
                "travelMode": _travelMode,
                "routingPreference": _travelMode == 'DRIVE'
                    ? "TRAFFIC_AWARE"
                    : "ROUTING_PREFERENCE_UNSPECIFIED",
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            debugPrint(
              "Route found for ${shelter.name}: ${route['duration']} and ${route['distanceMeters']} meters",
            );

            final durationStr = route['duration'] as String; // e.g. "356s"
            shelter.etaSeconds =
                int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
            shelter.distanceMeters =
                (route['distanceMeters'] as num?)?.toDouble() ??
                shelter.distanceMeters;
            shelter.encodedPolyline = route['polyline']['encodedPolyline'];
          }
        } else {
          debugPrint(
            "Route API Error for ${shelter.name}: HTTP ${response.statusCode} - ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Error calculating route for ${shelter.name}: $e");
      }
    }).toList();

    await Future.wait(routeFutures);
  }

  Future<List<Shelter>> _rankWithGemini(List<Shelter> candidates) async {
    // Use gemini-2.0-flash (fast, non-thinking model) instead of gemini-2.5-flash (thinking model, very slow)
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _geminiApiKey,
      systemInstruction: Content.system(
        "You are an AI assistant helping a disaster management app rank safe shelters. Output strictly in JSON array format: [{\"id\": \"SH-001\", \"reason\": \"Short reason here\"}]",
      ),
    );

    final candidateInfo = candidates
        .map(
          (s) => {
            "id": s.id,
            "name": s.name,
            "status": s.status,
            "capacityCurrent": s.capacityCurrent,
            "capacityTotal": s.capacityTotal,
            "tags": s.tags,
            "distanceMeters": s.distanceMeters,
            "etaSeconds": s.etaSeconds,
          },
        )
        .toList();

    final prompt =
        """
    You are an emergency response AI evaluating safe shelters. Rank the top 3 best shelters from the candidates provided.
    
    CRITICAL RULES (Failure to follow these will endanger lives):
    1. The shelter you rank as #1 MUST be 'open' and MUST have available capacity (capacityTotal - capacityCurrent > 0). NEVER rank a 'full' shelter as #1 if there is an open shelter with capacity available.
    2. If a shelter is 'full' (or capacity remaining is 0), you may still include it, but YOU MUST rank it 2nd or 3rd.
    3. For any 'full' shelter you include, its reason MUST explicitly mention: "Although it is overall good for the situation, the capacity is full so it is a secondary choice."
    4. Among open shelters, prefer higher remaining capacity and lower ETA.
    
    Here are the candidates:
    ${jsonEncode(candidateInfo)}
    
    Respond STRICTLY with a JSON array:
    [
      {"id": "...", "reason": "..."},
      {"id": "...", "reason": "..."},
      {"id": "...", "reason": "..."}
    ]
    """;

    try {
      debugPrint(
        "[Gemini] Calling Gemini API (gemini-2.0-flash) for ranking...",
      );
      debugPrint(
        "[Gemini] Sending ${candidates.length} candidates for evaluation",
      );
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 45));
      debugPrint("[Gemini] Raw response: ${response.text}");
      String reply = response.text ?? "[]";
      // Clean up markdown formatting if any
      reply = reply.replaceAll('```json', '').replaceAll('```', '').trim();
      debugPrint("[Gemini] Cleaned response: $reply");
      List<dynamic> rankedJson = jsonDecode(reply);
      debugPrint(
        "[Gemini] Parsed ${rankedJson.length} ranked shelters from response",
      );

      List<Shelter> rankedShelters = [];
      for (var r in rankedJson) {
        final id = r['id'];
        final reason = r['reason'];
        debugPrint("[Gemini] Ranked shelter id=$id, reason=$reason");
        try {
          final shelter = candidates.firstWhere((s) => s.id == id);
          shelter.recommendationReason = reason;
          rankedShelters.add(shelter);
        } catch (e) {
          debugPrint(
            "[Gemini] WARNING: Shelter with id=$id not found in candidates, skipping",
          );
        }
      }

      if (rankedShelters.isEmpty) {
        debugPrint(
          "[Gemini] WARNING: No shelters matched from Gemini response, using fallback",
        );
        return _fallbackRanking(candidates);
      }

      debugPrint(
        "[Gemini] SUCCESS: Returning ${rankedShelters.length} AI-ranked shelters",
      );
      return rankedShelters;
    } catch (e) {
      debugPrint("[Gemini] ERROR: $e");
      debugPrint("[Gemini] Using fallback ranking with auto-generated reasons");
      return _fallbackRanking(candidates);
    }
  }

  /// Fallback ranking when Gemini fails — prioritizes open shelters with capacity,
  /// penalizes full/closed shelters, and generates recommendation reasons
  List<Shelter> _fallbackRanking(List<Shelter> candidates) {
    // Sort: open shelters with capacity first, then by ETA
    candidates.sort((a, b) {
      final aRemaining = a.capacityTotal - a.capacityCurrent;
      final bRemaining = b.capacityTotal - b.capacityCurrent;
      final aIsFull = a.status == 'full' || aRemaining <= 0;
      final bIsFull = b.status == 'full' || bRemaining <= 0;
      final aIsClosed = a.status == 'closed';
      final bIsClosed = b.status == 'closed';

      // Open with capacity > Full > Closed
      if (!aIsFull && !aIsClosed && (bIsFull || bIsClosed)) return -1;
      if ((aIsFull || aIsClosed) && !bIsFull && !bIsClosed) return 1;
      if (aIsFull && bIsClosed) return -1;
      if (aIsClosed && bIsFull) return 1;

      // Among same status group: sort by ETA
      return a.etaSeconds.compareTo(b.etaSeconds);
    });

    List<Shelter> top3 = candidates.take(3).toList();
    for (int i = 0; i < top3.length; i++) {
      final s = top3[i];
      final remaining = s.capacityTotal - s.capacityCurrent;
      final isFull = s.status == 'full' || remaining <= 0;

      if (isFull) {
        s.recommendationReason =
            "FULL — not accepting new evacuees. ${s.tags.isNotEmpty ? s.tags.first : 'General'} services available when capacity opens.";
      } else if (i == 0) {
        s.recommendationReason =
            "Best option: open with $remaining spots and ${_formatEta(s.etaSeconds)} travel time. ${s.tags.take(2).join(', ')} services offered.";
      } else {
        s.recommendationReason =
            "Open shelter with $remaining spots available, ${_formatEta(s.etaSeconds)} ETA. ${s.tags.take(2).join(', ')} services offered.";
      }
    }
    return top3;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return polyline;
  }

  void _updateMap() {
    if (_currentPosition == null) return;

    _markers.clear();
    _polylines.clear();

    // Add user marker
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    );

    // Add shelter markers
    for (int i = 0; i < _recommendedShelters.length; i++) {
      final shelter = _recommendedShelters[i];
      final isSelected = _selectedShelter?.id == shelter.id;

      _markers.add(
        Marker(
          markerId: MarkerId(shelter.id),
          position: LatLng(shelter.lat, shelter.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: shelter.name, snippet: shelter.status),
          onTap: () {
            setState(() {
              _selectedShelter = shelter;
              _updateMap();
            });
          },
        ),
      );
    }

    // Add polyline for selected shelter
    if (_selectedShelter != null && _selectedShelter!.encodedPolyline != null) {
      final points = _decodePolyline(_selectedShelter!.encodedPolyline!);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.deepPurpleAccent,
          width: 5,
        ),
      );
    }

    // Move camera to fit route
    if (_mapController != null && _selectedShelter != null) {
      try {
        LatLngBounds bounds = _boundsFromLatLngList([
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(_selectedShelter!.lat, _selectedShelter!.lng),
        ]);
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } catch (e) {
        debugPrint("Error animating camera: $e");
      }
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  String _formatEta(int seconds) {
    int minutes = (seconds / 60).round();
    if (minutes < 60) return "~$minutes min";
    int hours = minutes ~/ 60;
    int remainingMinutes = minutes % 60;
    return "~$hours hr $remainingMinutes min";
  }

  String _formatDistance(double meters) {
    double miles = meters / 1609.34; // Alternatively /1000 for km
    return "${miles.toStringAsFixed(1)} mi away";
  }

  Future<void> _launchMapsNavigation(double lat, double lng) async {
    final String navMode = _travelMode == 'DRIVE' ? 'd' : 'w';
    final Uri googleMapsUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=$navMode',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      // Fallback to web maps
      final Uri webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$navMode',
      );
      launchUrl(webUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Nearby Shelters',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF13C05D)),
                  const SizedBox(height: 16),
                  Text(
                    _loadingText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _currentPosition != null
                            ? CameraPosition(
                                target: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                zoom: 14,
                              )
                            : const CameraPosition(
                                target: LatLng(0, 0),
                                zoom: 2,
                              ),
                        markers: _markers,
                        polylines: _polylines,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          controller.setMapStyle(_mapStyle);
                          if (_selectedShelter != null) {
                            _updateMap();
                          }
                        },
                        zoomControlsEnabled: false,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      ),

                      // Travel Mode Toggle
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: SafeArea(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'DRIVE',
                                      icon: Icon(Icons.directions_car),
                                      label: Text('Drive'),
                                    ),
                                    ButtonSegment(
                                      value: 'WALK',
                                      icon: Icon(Icons.directions_walk),
                                      label: Text('Walk'),
                                    ),
                                  ],
                                  selected: {_travelMode},
                                  onSelectionChanged:
                                      (Set<String> newSelection) async {
                                        if (newSelection.first != _travelMode) {
                                          setState(() {
                                            _travelMode = newSelection.first;
                                            _isLoading = true;
                                            _loadingText =
                                                "Recalculating routes...";
                                          });

                                          // Recalculate routes for the current candidates
                                          await _calculateRoutesForCandidates(
                                            _recommendedShelters.isEmpty
                                                ? []
                                                : _recommendedShelters,
                                          );

                                          if (mounted) {
                                            setState(() {
                                              _isLoading = false;
                                              if (_selectedShelter != null) {
                                                _updateMap();
                                              }
                                            });
                                          }
                                        }
                                      },
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith<Color>((
                                          Set<WidgetState> states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.selected,
                                          )) {
                                            return const Color(
                                              0xFF13C05D,
                                            ).withOpacity(0.2);
                                          }
                                          return Colors.white;
                                        }),
                                    iconColor:
                                        WidgetStateProperty.resolveWith<Color>((
                                          Set<WidgetState> states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.selected,
                                          )) {
                                            return const Color(0xFF13C05D);
                                          }
                                          return Colors.grey;
                                        }),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith<Color>((
                                          Set<WidgetState> states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.selected,
                                          )) {
                                            return const Color(0xFF13C05D);
                                          }
                                          return Colors.black87;
                                        }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_selectedShelter != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _travelMode == 'DRIVE'
                                        ? Icons.directions_car
                                        : Icons.directions_walk,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${(_selectedShelter!.etaSeconds / 60).round()} min",
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Fastest route \u2022 ${_formatDistance(_selectedShelter!.distanceMeters)}",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _launchMapsNavigation(
                                    _selectedShelter!.lat,
                                    _selectedShelter!.lng,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF13C05D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    "Navigate",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recommendedShelters.length,
                    itemBuilder: (context, index) {
                      final shelter = _recommendedShelters[index];
                      return _buildShelterCard(shelter, index == 0);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildShelterCard(Shelter shelter, bool isTopRecommended) {
    bool isFull = shelter.status == 'full';
    double capacityRatio = shelter.capacityTotal > 0
        ? (shelter.capacityCurrent / shelter.capacityTotal)
        : 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedShelter = shelter;
          _updateMap();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: _selectedShelter?.id == shelter.id
              ? Border.all(color: const Color(0xFF13C05D), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: shelter.imageURL != null
                      ? Image.asset(
                          shelter.imageURL!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          'https://images.unsplash.com/photo-1541625602330-2277a4c46182?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (isTopRecommended)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Recommended",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.redAccent
                          : const Color(0xFF13C05D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isFull ? "Full" : "Available",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelter.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDistance(shelter.distanceMeters),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatEta(shelter.etaSeconds),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shelter.recommendationReason != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shelter.recommendationReason!,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Capacity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Capacity",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${shelter.capacityCurrent} / ${shelter.capacityTotal}",
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: capacityRatio,
                    backgroundColor: Colors.grey[200],
                    color: isFull ? Colors.redAccent : const Color(0xFF13C05D),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Row(
                    children: shelter.tags
                        .take(4)
                        .map((tag) => _buildTagIcon(tag))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Open Google Maps intent or internal navigation here
                      },
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        "Navigate",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13C05D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagIcon(String tag) {
    IconData icon;
    Color color;
    Color bgColor;

    switch (tag.toLowerCase()) {
      case 'medical':
        icon = Icons.favorite_border;
        color = Colors.red;
        bgColor = Colors.red[50]!;
        break;
      case 'food':
        icon = Icons.restaurant_menu;
        color = Colors.orange;
        bgColor = Colors.orange[50]!;
        break;
      case 'wifi':
        icon = Icons.wifi;
        color = Colors.blue;
        bgColor = Colors.blue[50]!;
        break;
      case 'access':
        icon = Icons.accessible_forward;
        color = Colors.green;
        bgColor = Colors.green[50]!;
        break;
      default:
        icon = Icons.check_circle_outline;
        color = Colors.grey;
        bgColor = Colors.grey[100]!;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(tag, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }
}
