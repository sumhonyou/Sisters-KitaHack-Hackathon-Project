// Lightweight alert model with hardcoded mock data.
// No database connection needed — just static samples.

class AlertModel {
  final String id;
  final String title;
  final String type; // fire, flood, earthquake, tsunami, storm
  final String severity; // high, medium, low
  final String description;
  final String shortAdvice;
  final String locationName;
  final double distanceKm;
  final DateTime issuedAt;
  final DateTime? updatedAt;
  final double lat;
  final double lng;
  final List<String> recommendedActions;
  final List<ShelterInfo> nearbyShelters;
  final String officialSource;

  const AlertModel({
    required this.id,
    required this.title,
    required this.type,
    required this.severity,
    required this.description,
    required this.shortAdvice,
    required this.locationName,
    required this.distanceKm,
    required this.issuedAt,
    this.updatedAt,
    required this.lat,
    required this.lng,
    required this.recommendedActions,
    required this.nearbyShelters,
    required this.officialSource,
  });
}

class ShelterInfo {
  final String name;
  final String address;
  final double distanceKm;

  const ShelterInfo({
    required this.name,
    required this.address,
    required this.distanceKm,
  });
}

// ──────────────────────────────────────────
// Mock data
// ──────────────────────────────────────────
final List<AlertModel> mockAlerts = [
  AlertModel(
    id: 'ALR-001',
    title: 'Flash Flood Warning',
    type: 'flood',
    severity: 'high',
    description:
        'Heavy rainfall in the past 2 hours has caused water levels to rise rapidly in low-lying areas. Flash flooding is occurring in Taman Tun Dr Ismail and surrounding neighborhoods. Water levels are expected to continue rising for the next 1-2 hours.',
    shortAdvice: 'Avoid low-lying areas. Seek higher...',
    locationName: 'Taman Tun Dr Ismail, Kuala Lumpur',
    distanceKm: 2.3,
    issuedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    lat: 3.1319,
    lng: 101.6241,
    recommendedActions: [
      'Move to higher ground immediately',
      'Avoid walking or driving through flooded areas',
      'Turn off electricity and gas if instructed',
      'Stay informed through official channels',
    ],
    nearbyShelters: [
      const ShelterInfo(
        name: 'Dewan Komuniti Taman Tun',
        address: 'Jalan Tun Dr Ismail',
        distanceKm: 1.2,
      ),
      const ShelterInfo(
        name: 'Pusat Komuniti Bangsar',
        address: 'Jalan Bangsar Utama',
        distanceKm: 2.5,
      ),
      const ShelterInfo(
        name: 'Sekolah Kebangsaan Sri Hartamas',
        address: 'Jalan 26A/70A',
        distanceKm: 3.1,
      ),
    ],
    officialSource: 'National Disaster Management Agency',
  ),
  AlertModel(
    id: 'ALR-002',
    title: 'Wildfire Alert',
    type: 'fire',
    severity: 'medium',
    description:
        'A wildfire has been detected in the forested area near Bukit Kiara. Firefighters have been dispatched and are working to contain the blaze. Smoke may affect nearby residential areas.',
    shortAdvice: 'Stay indoors. Close windows and...',
    locationName: 'Bukit Kiara, Kuala Lumpur',
    distanceKm: 8.1,
    issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    lat: 3.1545,
    lng: 101.6340,
    recommendedActions: [
      'Stay indoors and close all windows',
      'Avoid outdoor activities',
      'Use air purifiers if available',
      'Follow evacuation orders if issued',
    ],
    nearbyShelters: [
      const ShelterInfo(
        name: 'Dewan Orang Ramai Segambut',
        address: 'Jalan Segambut',
        distanceKm: 4.2,
      ),
    ],
    officialSource: 'Fire and Rescue Department Malaysia',
  ),
  AlertModel(
    id: 'ALR-003',
    title: 'Earthquake Tremor',
    type: 'earthquake',
    severity: 'low',
    description:
        'A minor earthquake of magnitude 3.2 was recorded off the coast of Sabah. No tsunami threat. Mild tremors may be felt in coastal areas.',
    shortAdvice: 'Stay calm. Move to open area if...',
    locationName: 'Kota Kinabalu, Sabah',
    distanceKm: 12.0,
    issuedAt: DateTime.now().subtract(const Duration(hours: 5)),
    updatedAt: null,
    lat: 5.9804,
    lng: 116.0735,
    recommendedActions: [
      'Stay calm and do not panic',
      'Move away from buildings and structures',
      'Drop, cover, and hold on if indoors',
      'Check for structural damage before re-entering buildings',
    ],
    nearbyShelters: [
      const ShelterInfo(
        name: 'Dewan Masyarakat Kota Kinabalu',
        address: 'Jalan Pantai',
        distanceKm: 1.5,
      ),
    ],
    officialSource: 'Malaysian Meteorological Department',
  ),
  AlertModel(
    id: 'ALR-004',
    title: 'Tsunami Watch',
    type: 'tsunami',
    severity: 'high',
    description:
        'A tsunami watch has been issued for coastal areas of Sabah following a 6.1 magnitude earthquake in the Sulu Sea. Waves of up to 1-2 meters may reach shorelines within the next 2 hours.',
    shortAdvice: 'Move away from coastline immediately...',
    locationName: 'Sandakan, Sabah',
    distanceKm: 5.7,
    issuedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    lat: 5.8394,
    lng: 118.1171,
    recommendedActions: [
      'Move to higher ground away from the coast',
      'Do not go to the beach to watch the waves',
      'Follow evacuation routes posted in your area',
      'Listen to local radio for official updates',
    ],
    nearbyShelters: [
      const ShelterInfo(
        name: 'Dewan Serbaguna Sandakan',
        address: 'Jalan Utara',
        distanceKm: 2.0,
      ),
      const ShelterInfo(
        name: 'SK Taman Kabota',
        address: 'Jalan Kabota',
        distanceKm: 3.4,
      ),
    ],
    officialSource: 'Malaysian Meteorological Department',
  ),
  AlertModel(
    id: 'ALR-005',
    title: 'Tropical Storm Warning',
    type: 'storm',
    severity: 'medium',
    description:
        'Tropical storm Cempaka is approaching the east coast of Peninsular Malaysia with sustained winds of 75 km/h. Heavy rain and strong winds are expected in Terengganu and Kelantan over the next 12 hours.',
    shortAdvice: 'Secure loose objects. Stay indoors...',
    locationName: 'Kuala Terengganu, Terengganu',
    distanceKm: 15.3,
    issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    lat: 5.3117,
    lng: 103.1324,
    recommendedActions: [
      'Stay indoors and away from windows',
      'Secure loose outdoor objects',
      'Stock up on essential supplies and water',
      'Charge all electronic devices',
    ],
    nearbyShelters: [
      const ShelterInfo(
        name: 'Dewan Serbaguna Kuala Terengganu',
        address: 'Jalan Sultan Ismail',
        distanceKm: 1.8,
      ),
      const ShelterInfo(
        name: 'SK Ladang',
        address: 'Jalan Ladang',
        distanceKm: 4.5,
      ),
    ],
    officialSource: 'Malaysian Meteorological Department',
  ),
];
