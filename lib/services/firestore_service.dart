import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_model.dart';
import '../models/reporter_model.dart';
import '../models/disaster_model.dart';
import '../models/shelter_model.dart';
import '../models/community_post_model.dart';
import '../models/reported_case_model.dart';
import '../models/area_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Streams ───────────────────────────────────────────────────────────────

  Stream<List<IncidentModel>> incidentsStream() {
    return _db
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(IncidentModel.fromFirestore).toList());
  }

  Stream<List<ReporterModel>> reportersStream({String? zone}) {
    Query query = _db
        .collection('reporters')
        .orderBy('timestamp', descending: true);
    if (zone != null && zone.isNotEmpty) {
      query = query.where('zone', isEqualTo: zone);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(ReporterModel.fromFirestore).toList(),
    );
  }

  // ── reported_cases ────────────────────────────────────────────────────────

  /// Stream all reported cases, newest first.
  /// Falls back to [fallbackLat]/[fallbackLng] if location is null.
  Stream<List<ReportedCase>> reportedCasesStream() {
    return _db.collection('reported_cases').snapshots().map((snap) {
      final cases = snap.docs
          .map((doc) => ReportedCase.fromFirestore(doc))
          .toList();
      cases.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return cases;
    });
  }

  // ── areas ─────────────────────────────────────────────────────────────────

  Stream<List<AreaModel>> areasStream() {
    return _db
        .collection('areas')
        .snapshots()
        .map((snap) => snap.docs.map(AreaModel.fromFirestore).toList());
  }

  /// Save the coordinate-response unit statuses onto a reported_case document.
  /// [statuses] is a map like {'police': 'Dispatched', 'fire': 'En Route', ...}
  Future<void> updateCaseResponseStatus(
    String caseDocId,
    Map<String, String> statuses,
  ) async {
    await _db.collection('reported_cases').doc(caseDocId).update({
      'responseStatus': statuses,
      'responseUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<DisasterModel>> disastersStream({String? status}) {
    Query query = _db
        .collection('disasters')
        .orderBy('createdAt', descending: true);
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(DisasterModel.fromFirestore).toList(),
    );
  }

  Stream<List<ShelterModel>> sheltersStream({String? status}) {
    Query query = _db.collection('shelters');
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map(
      (snap) => snap.docs.map(ShelterModel.fromFirestore).toList(),
    );
  }

  // posts collection
  Stream<List<CommunityPost>> communityPostsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityPost.fromFirestore).toList());
  }

  Stream<List<CommunityPost>> communityPostsByCategory(String category) {
    return _db
        .collection('posts')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snap) {
          final posts = snap.docs.map(CommunityPost.fromFirestore).toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  Stream<List<CommunityPost>> communityPostsByArea(String areaId) {
    return _db
        .collection('posts')
        .where('areaId', isEqualTo: areaId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityPost.fromFirestore).toList());
  }

  // comments subcollection
  Stream<List<CommunityComment>> commentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityComment.fromFirestore).toList());
  }

  Future<void> addPost(CommunityPost post) async {
    await _db.collection('posts').add(post.toMap());
  }

  Future<void> addComment(String postId, CommunityComment comment) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());
  }

  Future<void> togglePostLike(
    String postId,
    bool isLiked,
    int currentLikes,
  ) async {
    await _db.collection('posts').doc(postId).update({
      'isLikedByMe': isLiked,
      'likeCount': isLiked ? currentLikes + 1 : currentLikes - 1,
    });
  }

  // ─── Seed Sample Data ──────────────────────────────────────────────────────

  Future<void> seedSampleDataIfEmpty() async {
    final incidentSnap = await _db.collection('incidents').limit(1).get();
    final reporterSnap = await _db.collection('reporters').limit(1).get();
    final disasterSnap = await _db.collection('disasters').limit(1).get();
    final shelterSnap = await _db.collection('shelters').limit(1).get();
    final postSnap = await _db.collection('posts').limit(1).get();
    final caseSnap = await _db.collection('reported_cases').limit(1).get();
    final areaSnap = await _db.collection('areas').limit(1).get();

    final needIncidents = incidentSnap.docs.isEmpty;
    final needReporters = reporterSnap.docs.isEmpty;
    final needDisasters = disasterSnap.docs.isEmpty;
    final needShelters = shelterSnap.docs.isEmpty;
    final needPosts = postSnap.docs.isEmpty;
    final needCases = caseSnap.docs.length < 10;
    final needAreas = areaSnap.docs.isEmpty;

    if (!needIncidents &&
        !needReporters &&
        !needDisasters &&
        !needShelters &&
        !needPosts &&
        !needCases &&
        !needAreas) {
      return;
    }

    // ── Seed posts + comments ────────────────────────────────────────────────
    if (needPosts) {
      final now = DateTime.now();
      // Define posts data
      final postsData = [
        {
          'authorUid': 'cg-official',
          'authorName': 'City Guard Updates',
          'authorHandle': '@CityGuard',
          'authorAvatarColor': '#7C3AED',
          'type': 'Update',
          'category': 'trending',
          'areaId': 'downtown',
          'title': 'Flood Advisory: Klang Valley — All Shelters Open',
          'message':
              'FLOOD ADVISORY: Water levels in Klang Valley have risen significantly due to heavy rainfall. Residents in low-lying areas are advised to stay indoors. All shelters are now open for public use. Bring your IC, medications, and essential documents.',
          'tags': ['flood', 'klcc', 'advisory', 'shelter'],
          'likeCount': 2300,
          'repostCount': 1000,
          'viewCount': 10500,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 2)),
          ),
          'comments': [
            {
              'authorUid': 'user-001',
              'authorName': 'Nurul Ain',
              'authorHandle': '@nurulain_kl',
              'authorAvatarColor': '#EC4899',
              'message':
                  'Thank you City Guard! Sharing this to my family group now. 🙏',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 1, minutes: 50)),
              ),
            },
            {
              'authorUid': 'user-002',
              'authorName': 'Hafiz Zainuddin',
              'authorHandle': '@hafiz_zdn',
              'authorAvatarColor': '#059669',
              'message': 'Which shelters exactly? Can you list the addresses?',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 1, minutes: 40)),
              ),
            },
            {
              'authorUid': 'cg-official',
              'authorName': 'City Guard Updates',
              'authorHandle': '@CityGuard',
              'authorAvatarColor': '#7C3AED',
              'message':
                  'Shelters list: 1) Dewan Sri Petaling 2) SK Jalan Bukit 3) Pusat Komuniti Wangsa Maju. More at cityguard.gov.my/shelters',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 1, minutes: 30)),
              ),
            },
          ],
        },
        {
          'authorUid': 'cg-official',
          'authorName': 'City Guard Updates',
          'authorHandle': '@CityGuard',
          'authorAvatarColor': '#7C3AED',
          'type': 'Update',
          'category': 'trending',
          'areaId': 'downtown',
          'title': 'Roads Clearance Update — Downtown Area',
          'message':
              'All major roads in the downtown area are now clear. Traffic is moving normally. Thank you for your patience during the emergency response. Road sweeping crews will continue overnight.',
          'tags': ['roads', 'traffic', 'clearance', 'update'],
          'likeCount': 1200,
          'repostCount': 456,
          'viewCount': 8800,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
          'comments': [
            {
              'authorUid': 'user-003',
              'authorName': 'Priya Kannan',
              'authorHandle': '@priya_kl',
              'authorAvatarColor': '#D97706',
              'message':
                  'What about Jalan Cheras? Still flooded as of 30 min ago.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(minutes: 55)),
              ),
            },
            {
              'authorUid': 'user-004',
              'authorName': 'Ahmad Farouk',
              'authorHandle': '@ahmadfarouk',
              'authorAvatarColor': '#1A56DB',
              'message':
                  'Confirmed Jalan Ampang is passable now. Good work team! 👍',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(minutes: 45)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-005',
          'authorName': 'Nurul Ain',
          'authorHandle': '@nurulain_kl',
          'authorAvatarColor': '#EC4899',
          'type': 'Help',
          'category': 'trending',
          'areaId': 'taman-desa',
          'title': 'Elderly Neighbour Stranded — Need Help Now',
          'message':
              'Anyone near Taman Desa — my elderly neighbour Uncle Rajan (72 yrs) is stranded on the 2nd floor. Water is about knee height. He cannot walk well. Please help or contact me at 012-3456789. 🙏',
          'tags': ['help', 'elderly', 'rescue', 'taman-desa'],
          'likeCount': 892,
          'repostCount': 267,
          'viewCount': 5600,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 3)),
          ),
          'comments': [
            {
              'authorUid': 'user-006',
              'authorName': 'Mei Ling Tan',
              'authorHandle': '@meiling_rescues',
              'authorAvatarColor': '#DC2626',
              'message': 'I have a boat! Give me your exact address DM me.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 2, minutes: 50)),
              ),
            },
            {
              'authorUid': 'user-007',
              'authorName': 'Encik Roslan',
              'authorHandle': '@roslan_kl',
              'authorAvatarColor': '#0891B2',
              'message':
                  'Called BOMBA. They are routing a unit to Taman Desa. ETA 20 min.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 2, minutes: 40)),
              ),
            },
            {
              'authorUid': 'user-005',
              'authorName': 'Nurul Ain',
              'authorHandle': '@nurulain_kl',
              'authorAvatarColor': '#EC4899',
              'message':
                  'UPDATE: Uncle Rajan is safe! BOMBA arrived. Thank you everyone 🙏❤️',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 2, minutes: 10)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-008',
          'authorName': 'Hafiz Zainuddin',
          'authorHandle': '@hafiz_zdn',
          'authorAvatarColor': '#059669',
          'type': 'Info',
          'category': 'following',
          'areaId': 'wangsa-maju',
          'title': 'Pusat Komuniti Wangsa Maju — Now Accepting Evacuees',
          'message':
              'Pusat Komuniti Wangsa Maju is now accepting flood victims. Capacity: 300 pax. Food & water available. Bring your IC. Location: 800m from Wangsa Maju LRT, follow the orange signs. Open 24/7.',
          'tags': ['shelter', 'wangsa-maju', 'evacuation', 'info'],
          'likeCount': 654,
          'repostCount': 432,
          'viewCount': 4100,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 4)),
          ),
          'comments': [
            {
              'authorUid': 'user-009',
              'authorName': 'Siti Rahimah',
              'authorHandle': '@sitirah',
              'authorAvatarColor': '#8B5CF6',
              'message':
                  'Is there space for 8 people including 2 kids and a baby?',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 3, minutes: 45)),
              ),
            },
            {
              'authorUid': 'user-008',
              'authorName': 'Hafiz Zainuddin',
              'authorHandle': '@hafiz_zdn',
              'authorAvatarColor': '#059669',
              'message':
                  '@sitirah Yes! Family rooms are available. Please come.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 3, minutes: 30)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-003',
          'authorName': 'Priya Kannan',
          'authorHandle': '@priya_kl',
          'authorAvatarColor': '#D97706',
          'type': 'Alert',
          'category': 'trending',
          'areaId': 'jalan-ipoh',
          'title': '⚠️ Do NOT Use Jalan Ipoh Underpass — Completely Submerged!',
          'message':
              'WARNING: Do NOT use the Jalan Ipoh underpass — completely submerged! A motorcyclist nearly got swept away. Avoid entirely. Use Jalan Kuching as alternative route. Spread the word!',
          'tags': ['alert', 'road', 'flood', 'jalan-ipoh', 'warning'],
          'likeCount': 3100,
          'repostCount': 2100,
          'viewCount': 18400,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 5)),
          ),
          'comments': [
            {
              'authorUid': 'user-010',
              'authorName': 'Zul Omar',
              'authorHandle': '@zulomar',
              'authorAvatarColor': '#1A56DB',
              'message':
                  'Just turned back from there! It is really bad. Please heed this warning.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 4, minutes: 55)),
              ),
            },
            {
              'authorUid': 'user-011',
              'authorName': 'Linda Chong',
              'authorHandle': '@lindachong',
              'authorAvatarColor': '#EC4899',
              'message':
                  'DBKL pls put up barriers asap!! Someone will get hurt.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 4, minutes: 40)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-004',
          'authorName': 'Ahmad Farouk',
          'authorHandle': '@ahmadfarouk',
          'authorAvatarColor': '#1A56DB',
          'type': 'Info',
          'category': 'following',
          'areaId': 'ampang-jaya',
          'title': 'Community WhatsApp Group for Ampang Jaya Taman',
          'message':
              'My street in Ampang Jaya is flooded but manageable. We set up a community WhatsApp group to coordinate help for elders and families without cars. DM me to join. We have 60+ members helping each other. 💪',
          'tags': ['community', 'ampang', 'help', 'coordination'],
          'likeCount': 445,
          'repostCount': 123,
          'viewCount': 2800,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 6)),
          ),
          'comments': [
            {
              'authorUid': 'user-012',
              'authorName': 'Ranjit Singh',
              'authorHandle': '@ranjitsgh',
              'authorAvatarColor': '#F97316',
              'message': 'DM sent! Great initiative bro.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 5, minutes: 55)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-006',
          'authorName': 'Mei Ling Tan',
          'authorHandle': '@meiling_rescues',
          'authorAvatarColor': '#DC2626',
          'type': 'Help',
          'category': 'nearby',
          'areaId': 'sg-besi',
          'title': 'Volunteers Needed — Boat Rescue at Sg Besi',
          'message':
              'VOLUNTEERS NEEDED 🆘 We have a boat and need 2 more people to help rescue families in Sg Besi area. Meet at Petronas Sg Besi at 4PM. Bring your own life vest if possible. No experience needed, just courage. WhatsApp 017-8901234.',
          'tags': ['volunteers', 'rescue', 'sg-besi', 'boat'],
          'likeCount': 1876,
          'repostCount': 934,
          'viewCount': 9200,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 7)),
          ),
          'comments': [
            {
              'authorUid': 'user-013',
              'authorName': 'Danial Azman',
              'authorHandle': '@danialazman',
              'authorAvatarColor': '#059669',
              'message': 'I am coming! WhatsApp-ed you. ETA 3:30PM.',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 6, minutes: 50)),
              ),
            },
            {
              'authorUid': 'user-014',
              'authorName': 'Kavita Nair',
              'authorHandle': '@kavitanair',
              'authorAvatarColor': '#7C3AED',
              'message': 'I will take videos and help document. On my way!',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 6, minutes: 45)),
              ),
            },
          ],
        },
        {
          'authorUid': 'user-007',
          'authorName': 'Encik Roslan',
          'authorHandle': '@roslan_kl',
          'authorAvatarColor': '#0891B2',
          'type': 'Update',
          'category': 'nearby',
          'areaId': 'jalan-pahang',
          'title':
              'Good News: Pump Station Operational — Water Receding Tonight',
          'message':
              'Good news neighbours! The pump station on Jalan Pahang is now operational after a 3-hour repair. Water should recede by tonight 11PM. JKR is on site monitoring. Stay safe! 🙌',
          'tags': ['infrastructure', 'pump', 'good-news', 'jalan-pahang'],
          'likeCount': 567,
          'repostCount': 89,
          'viewCount': 3300,
          'isLikedByMe': false,
          'createdAt': Timestamp.fromDate(
            now.subtract(const Duration(hours: 8)),
          ),
          'comments': [
            {
              'authorUid': 'user-015',
              'authorName': 'Nora Hamid',
              'authorHandle': '@norahamid',
              'authorAvatarColor': '#EC4899',
              'message':
                  'Finally some good news! Thank you JKR and all the workers! 🙏',
              'createdAt': Timestamp.fromDate(
                now.subtract(const Duration(hours: 7, minutes: 55)),
              ),
            },
          ],
        },
      ];

      // Write each post and its comments
      for (final postData in postsData) {
        final comments = postData.remove('comments') as List;
        final postRef = _db.collection('posts').doc();
        await postRef.set(postData);
        for (final c in comments) {
          await postRef.collection('comments').add(c as Map<String, dynamic>);
        }
      }
    }

    final now = DateTime.now();
    final incidents = [
      IncidentModel(
        id: 'INC-001',
        title: 'Earthquake Incident',
        location: 'KLCC, Kuala Lumpur',
        lat: 3.1578,
        lng: 101.7123,
        zone: 'Zone A',
        severity: Severity.critical,
        peopleAffected: 45,
        status: 'Trapped',
        description:
            'Building structural damage, multiple people trapped on upper floors',
        timestamp: now.subtract(const Duration(minutes: 16)),
      ),
      IncidentModel(
        id: 'INC-002',
        title: 'Flash Flood',
        location: 'Kepong, Kuala Lumpur',
        lat: 3.2100,
        lng: 101.6388,
        zone: 'Zone B',
        severity: Severity.high,
        peopleAffected: 28,
        status: 'Evacuating',
        description:
            'Rapid water rise, residential area flooded, families stranded on rooftops',
        timestamp: now.subtract(const Duration(minutes: 34)),
      ),
      IncidentModel(
        id: 'INC-003',
        title: 'Building Collapse',
        location: 'Chow Kit, Kuala Lumpur',
        lat: 3.1674,
        lng: 101.6990,
        zone: 'Zone A',
        severity: Severity.critical,
        peopleAffected: 32,
        status: 'Search & Rescue',
        description:
            'Old shophouse collapsed, debris blocking access roads, survivors heard calling for help',
        timestamp: now.subtract(const Duration(minutes: 52)),
      ),
      IncidentModel(
        id: 'INC-004',
        title: 'Gas Explosion',
        location: 'Ampang, Kuala Lumpur',
        lat: 3.1479,
        lng: 101.7602,
        zone: 'Zone B',
        severity: Severity.high,
        peopleAffected: 15,
        status: 'Contained',
        description:
            'Industrial gas tank explosion, significant fire, surrounding area evacuated',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      IncidentModel(
        id: 'INC-005',
        title: 'Traffic Landslide',
        location: 'Bukit Jalil, Kuala Lumpur',
        lat: 3.0617,
        lng: 101.6921,
        zone: 'Zone C',
        severity: Severity.medium,
        peopleAffected: 8,
        status: 'Active',
        description:
            'Hillside landslide blocking major highway, several vehicles buried, no fatalities',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
      ),
      IncidentModel(
        id: 'INC-006',
        title: 'Chemical Spill',
        location: 'Pandan Indah, Kuala Lumpur',
        lat: 3.1158,
        lng: 101.7441,
        zone: 'Zone C',
        severity: Severity.medium,
        peopleAffected: 20,
        status: 'Active',
        description:
            'Unknown chemical spill near residential area, pungent odour reported',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      IncidentModel(
        id: 'INC-007',
        title: 'Medical Emergency',
        location: 'Subang Jaya, Selangor',
        lat: 3.0565,
        lng: 101.5831,
        zone: 'Zone D',
        severity: Severity.low,
        peopleAffected: 3,
        status: 'Responded',
        description:
            'Mass food poisoning at community event, 3 hospitalised, situation stable',
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      IncidentModel(
        id: 'INC-008',
        title: 'Fire Outbreak',
        location: 'Petaling Jaya, Selangor',
        lat: 3.1073,
        lng: 101.6067,
        zone: 'Zone D',
        severity: Severity.low,
        peopleAffected: 5,
        status: 'Controlled',
        description:
            'Small factory fire, contained by local fire brigade, no casualties',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
    ];

    final reporters = [
      // Zone A
      ReporterModel(
        id: 'R-001',
        unitId: 'A-12-05',
        incidentId: 'INC-001',
        zone: 'Zone A',
        severity: 'critical',
        locationLabel: 'Pavilion Residences, KLCC',
        reporterName: 'Ahmad Ismail',
        phone: '+60123456789',
        peopleAffected: 4,
        hasSOS: true,
        timestamp: now.subtract(const Duration(minutes: 16)),
      ),
      ReporterModel(
        id: 'R-002',
        unitId: 'A-20-15',
        incidentId: 'INC-001',
        zone: 'Zone A',
        severity: 'critical',
        locationLabel: 'Pavilion Residences, KLCC',
        reporterName: 'Nurul Huda',
        phone: '+60123456793',
        peopleAffected: 5,
        hasSOS: true,
        timestamp: now.subtract(const Duration(minutes: 18)),
      ),
      ReporterModel(
        id: 'R-003',
        unitId: 'A-15-08',
        incidentId: 'INC-001',
        zone: 'Zone A',
        severity: 'high',
        locationLabel: 'Pavilion Residences, KLCC',
        reporterName: 'Siti Aminah',
        phone: '+60123456790',
        peopleAffected: 3,
        hasSOS: false,
        timestamp: now.subtract(const Duration(minutes: 21)),
      ),
      ReporterModel(
        id: 'R-004',
        unitId: 'A-18-22',
        incidentId: 'INC-001',
        zone: 'Zone A',
        severity: 'high',
        locationLabel: 'Pavilion Residences, KLCC',
        reporterName: 'Lee Chong Wei',
        phone: '+60123456791',
        peopleAffected: 6,
        hasSOS: false,
        timestamp: now.subtract(const Duration(minutes: 25)),
      ),
      ReporterModel(
        id: 'R-005',
        unitId: 'A-03-11',
        incidentId: 'INC-003',
        zone: 'Zone A',
        severity: 'critical',
        locationLabel: 'Chow Kit Road, KL',
        reporterName: 'Rajan Kumar',
        phone: '+60112345678',
        peopleAffected: 7,
        hasSOS: true,
        timestamp: now.subtract(const Duration(minutes: 52)),
      ),
      ReporterModel(
        id: 'R-006',
        unitId: 'A-07-04',
        incidentId: 'INC-003',
        zone: 'Zone A',
        severity: 'medium',
        locationLabel: 'Chow Kit Road, KL',
        reporterName: 'Fatimah Zahra',
        phone: '+60112345679',
        peopleAffected: 2,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 1)),
      ),
      ReporterModel(
        id: 'R-007',
        unitId: 'A-11-01',
        incidentId: 'INC-003',
        zone: 'Zone A',
        severity: 'critical',
        locationLabel: 'Chow Kit Road, KL',
        reporterName: 'David Lim',
        phone: '+60112345680',
        peopleAffected: 9,
        hasSOS: true,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
      ),
      // Zone B
      ReporterModel(
        id: 'R-008',
        unitId: 'B-05-02',
        incidentId: 'INC-002',
        zone: 'Zone B',
        severity: 'high',
        locationLabel: 'Taman Kepong, KL',
        reporterName: 'Mohd Hafiz',
        phone: '+60198765432',
        peopleAffected: 8,
        hasSOS: false,
        timestamp: now.subtract(const Duration(minutes: 34)),
      ),
      ReporterModel(
        id: 'R-009',
        unitId: 'B-09-14',
        incidentId: 'INC-002',
        zone: 'Zone B',
        severity: 'critical',
        locationLabel: 'Taman Kepong, KL',
        reporterName: 'Wong Mei Ling',
        phone: '+60198765433',
        peopleAffected: 12,
        hasSOS: true,
        timestamp: now.subtract(const Duration(minutes: 40)),
      ),
      ReporterModel(
        id: 'R-010',
        unitId: 'B-14-07',
        incidentId: 'INC-004',
        zone: 'Zone B',
        severity: 'high',
        locationLabel: 'Ampang Point, KL',
        reporterName: 'Priya Nair',
        phone: '+60198765435',
        peopleAffected: 5,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      // Zone C
      ReporterModel(
        id: 'R-011',
        unitId: 'C-02-09',
        incidentId: 'INC-005',
        zone: 'Zone C',
        severity: 'medium',
        locationLabel: 'Bukit Jalil Highway',
        reporterName: 'Tan Wei Jie',
        phone: '+60176543210',
        peopleAffected: 3,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
      ),
      ReporterModel(
        id: 'R-012',
        unitId: 'C-08-03',
        incidentId: 'INC-005',
        zone: 'Zone C',
        severity: 'critical',
        locationLabel: 'Bukit Jalil Highway',
        reporterName: 'Amirul Hakim',
        phone: '+60176543211',
        peopleAffected: 4,
        hasSOS: true,
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      ReporterModel(
        id: 'R-013',
        unitId: 'C-12-18',
        incidentId: 'INC-006',
        zone: 'Zone C',
        severity: 'medium',
        locationLabel: 'Pandan Indah, KL',
        reporterName: 'Zainab Othman',
        phone: '+60176543215',
        peopleAffected: 6,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 10)),
      ),
      // Zone D
      ReporterModel(
        id: 'R-014',
        unitId: 'D-01-06',
        incidentId: 'INC-007',
        zone: 'Zone D',
        severity: 'low',
        locationLabel: 'Subang Parade, Subang Jaya',
        reporterName: 'Kavitha Pillai',
        phone: '+60154321098',
        peopleAffected: 2,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      ReporterModel(
        id: 'R-015',
        unitId: 'D-06-11',
        incidentId: 'INC-008',
        zone: 'Zone D',
        severity: 'low',
        locationLabel: 'PJ Industrial Area',
        reporterName: 'Hendry Liew',
        phone: '+60154321099',
        peopleAffected: 3,
        hasSOS: false,
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
    ];

    // ── Disasters ─────────────────────────────────────────────────────────────
    final disasters = needDisasters
        ? [
            DisasterModel(
              id: 'DIS-001',
              type: 'flood',
              severity: 'high',
              title: 'Severe Flooding in Downtown District',
              description:
                  'Rapid water rise near Klang River. Multiple residential areas inundated. Residents on lower floors advised to evacuate immediately.',
              affectedAreaIds: ['area-klcc', 'area-chowkit'],
              center: const GeoPoint(3.1478, 101.6953),
              status: 'active',
              createdAt: now.subtract(const Duration(minutes: 30)),
              updatedAt: now.subtract(const Duration(minutes: 5)),
            ),
            DisasterModel(
              id: 'DIS-002',
              type: 'storm',
              severity: 'medium',
              title: 'Severe Thunderstorm Warning',
              description:
                  'Strong winds up to 90 km/h and heavy rain expected across Kuala Lumpur and surrounding areas. Flash floods possible.',
              affectedAreaIds: ['area-ampang', 'area-pj'],
              center: const GeoPoint(3.1073, 101.7067),
              status: 'monitoring',
              createdAt: now.subtract(const Duration(minutes: 15)),
              updatedAt: now.subtract(const Duration(minutes: 2)),
            ),
            DisasterModel(
              id: 'DIS-003',
              type: 'earthquake',
              severity: 'critical',
              title: 'Earthquake Alert — KLCC Area',
              description:
                  'Magnitude 5.2 tremors reported near city centre. Several buildings evacuated. Search and rescue teams deployed.',
              affectedAreaIds: ['area-klcc'],
              center: const GeoPoint(3.1579, 101.7116),
              status: 'active',
              createdAt: now.subtract(const Duration(hours: 1)),
              updatedAt: now.subtract(const Duration(minutes: 10)),
            ),
            DisasterModel(
              id: 'DIS-004',
              type: 'fire',
              severity: 'high',
              title: 'Industrial Fire — Kepong',
              description:
                  'Large warehouse fire in Kepong industrial zone. Toxic smoke reported. Residents within 2 km advised to stay indoors.',
              affectedAreaIds: ['area-kepong'],
              center: const GeoPoint(3.2100, 101.6388),
              status: 'active',
              createdAt: now.subtract(const Duration(hours: 2)),
              updatedAt: now.subtract(const Duration(minutes: 20)),
            ),
          ]
        : <DisasterModel>[];

    // ── Shelters ───────────────────────────────────────────────────────────────
    final shelters = needShelters
        ? [
            ShelterModel(
              id: 'SH-001',
              name: 'Dewan Komuniti Wangsa Maju',
              location: const GeoPoint(3.1855, 101.7452),
              areaId: 'area-wangsamaju',
              status: 'open',
              capacityTotal: 500,
              capacityCurrent: 234,
              contactPhone: '+60312345678',
              updatedAt: now.subtract(const Duration(minutes: 30)),
            ),
            ShelterModel(
              id: 'SH-002',
              name: 'SMK Kepong Baru Dewan',
              location: const GeoPoint(3.2043, 101.6364),
              areaId: 'area-kepong',
              status: 'open',
              capacityTotal: 800,
              capacityCurrent: 611,
              contactPhone: '+60312346789',
              updatedAt: now.subtract(const Duration(hours: 1)),
            ),
            ShelterModel(
              id: 'SH-003',
              name: 'Stadium Merdeka Community Centre',
              location: const GeoPoint(3.1414, 101.6974),
              areaId: 'area-klcc',
              status: 'full',
              capacityTotal: 1200,
              capacityCurrent: 1200,
              contactPhone: '+60312347890',
              updatedAt: now.subtract(const Duration(minutes: 45)),
            ),
            ShelterModel(
              id: 'SH-004',
              name: 'Pusat Komuniti Ampang Jaya',
              location: const GeoPoint(3.1479, 101.7602),
              areaId: 'area-ampang',
              status: 'open',
              capacityTotal: 350,
              capacityCurrent: 89,
              contactPhone: '+60312348901',
              updatedAt: now.subtract(const Duration(hours: 2)),
            ),
          ]
        : <ShelterModel>[];

    final batch = _db.batch();
    if (needIncidents) {
      for (final incident in incidents) {
        batch.set(
          _db.collection('incidents').doc(incident.id),
          incident.toMap(),
        );
      }
    }
    if (needReporters) {
      for (final reporter in reporters) {
        batch.set(
          _db.collection('reporters').doc(reporter.id),
          reporter.toMap(),
        );
      }
    }
    if (needDisasters) {
      for (final disaster in disasters) {
        batch.set(
          _db.collection('disasters').doc(disaster.id),
          disaster.toMap(),
        );
      }
    }
    if (needShelters) {
      for (final shelter in shelters) {
        batch.set(_db.collection('shelters').doc(shelter.id), shelter.toMap());
      }
    }

    // ── Seed Areas ───────────────────────────────────────────────────────────
    if (needAreas) {
      final areas = [
        {
          'areaId': 'area-klcc',
          'name': 'KLCC & City Centre',
          'center': const GeoPoint(3.1579, 101.7116),
        },
        {
          'areaId': 'area-bukitbintang',
          'name': 'Bukit Bintang',
          'center': const GeoPoint(3.1466, 101.7115),
        },
        {
          'areaId': 'area-cheras',
          'name': 'Cheras District',
          'center': const GeoPoint(3.1030, 101.7349),
        },
        {
          'areaId': 'area-ampang',
          'name': 'Ampang Jaya',
          'center': const GeoPoint(3.1479, 101.7602),
        },
        {
          'areaId': 'area-kepong',
          'name': 'Kepong Industrial',
          'center': const GeoPoint(3.2100, 101.6388),
        },
        {
          'areaId': 'area-wangsamaju',
          'name': 'Wangsa Maju',
          'center': const GeoPoint(3.1855, 101.7452),
        },
      ];
      for (final area in areas) {
        batch.set(_db.collection('areas').doc(area['areaId'] as String), area);
      }
    }

    // ── Seed Reported Cases ──────────────────────────────────────────────────
    if (needCases) {
      final cases = [
        // --- KLCC Area ---
        {
          'caseId': 'CASE-2024-001',
          'areaId': 'area-klcc',
          'category': 'Structural Damage',
          'checkIn': 'Pavilion Residences',
          'description':
              'Large cracks appeared in the basement parking. Residents evacuated.',
          'location': const GeoPoint(3.1578, 101.7123),
          'media': [
            'https://images.unsplash.com/photo-1590483734724-383b853b237d?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 120,
          'reporterUid': 'user-klcc-1',
          'severity': 5,
          'status': 'Evacuated',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 2)),
          ),
        },
        {
          'caseId': 'CASE-2024-002',
          'areaId': 'area-klcc',
          'category': 'Medical',
          'checkIn': 'Suria KLCC Entrance',
          'description':
              'Multiple persons reported dizzy spells near the fountain.',
          'location': const GeoPoint(3.1582, 101.7116),
          'media': [
            'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 8,
          'reporterUid': 'user-klcc-2',
          'severity': 3,
          'status': 'Investigating',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 45)),
          ),
        },
        {
          'caseId': 'CASE-2024-006',
          'areaId': 'area-klcc',
          'category': 'Elevator Trap',
          'checkIn': 'Menara Petronas 2',
          'description': '4 employees trapped in elevator on 42nd floor.',
          'location': const GeoPoint(3.1579, 101.7120),
          'media': [],
          'peopleAffected': 4,
          'reporterUid': 'user-klcc-3',
          'severity': 4,
          'status': 'Rescue In Progress',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 15)),
          ),
        },

        // --- Cheras District ---
        {
          'caseId': 'CASE-2024-003',
          'areaId': 'area-cheras',
          'category': 'Flash Flood',
          'checkIn': 'Jalan Cheras Underpass',
          'description': 'Water rising rapidly. Two cars stuck in the middle.',
          'location': const GeoPoint(3.1035, 101.7355),
          'media': [
            'https://images.unsplash.com/photo-1547683905-f686c993aae5?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 5,
          'reporterUid': 'user-cheras-1',
          'severity': 4,
          'status': 'Requested',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 20)),
          ),
        },
        {
          'caseId': 'CASE-2024-007',
          'areaId': 'area-cheras',
          'category': 'Tree Fallen',
          'checkIn': 'Taman Midah Main Road',
          'description': 'Large tree blocking both lanes of the road.',
          'location': const GeoPoint(3.1040, 101.7340),
          'media': [
            'https://images.unsplash.com/photo-1563293750-2c21458a17a3?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 0,
          'reporterUid': 'user-cheras-2',
          'severity': 2,
          'status': 'Dispatched',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 3)),
          ),
        },

        // --- Bukit Bintang ---
        {
          'caseId': 'CASE-2024-004',
          'areaId': 'area-bukitbintang',
          'category': 'Fire',
          'checkIn': 'Jalan Alor Shophouse',
          'description':
              'Kitchen fire spread to the second floor. Heavily smoke-filled.',
          'location': const GeoPoint(3.1471, 101.7100),
          'media': [
            'https://images.unsplash.com/photo-1516496636080-14fb876e029d?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 12,
          'reporterUid': 'user-bb-1',
          'severity': 4,
          'status': 'En Route',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
        },
        {
          'caseId': 'CASE-2024-008',
          'areaId': 'area-bukitbintang',
          'category': 'Crowd Control',
          'checkIn': 'Pavilion Pedestrian Crossing',
          'description': 'Overcrowding due to event blockage. High risk.',
          'location': const GeoPoint(3.1481, 101.7115),
          'media': [],
          'peopleAffected': 200,
          'reporterUid': 'user-bb-2',
          'severity': 3,
          'status': 'On Scene',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 30)),
          ),
        },

        // --- Ampang Jaya ---
        {
          'caseId': 'CASE-2024-005',
          'areaId': 'area-ampang',
          'category': 'Landslide',
          'checkIn': 'Taman Bukit Permai',
          'description':
              'Small landslide blocked the entrance road to the park.',
          'location': const GeoPoint(3.1485, 101.7610),
          'media': [
            'https://images.unsplash.com/photo-1541818167660-394f4c82db75?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 0,
          'reporterUid': 'user-ampang-1',
          'severity': 2,
          'status': 'Returned',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(days: 1)),
          ),
        },
        {
          'caseId': 'CASE-2024-009',
          'areaId': 'area-ampang',
          'category': 'Power Outage',
          'checkIn': 'Ampang Point Mall',
          'description': 'Partial power failure in the shopping mall.',
          'location': const GeoPoint(3.1479, 101.7602),
          'media': [
            'https://images.unsplash.com/photo-1584982224638-9814a2911f75?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 500,
          'reporterUid': 'user-ampang-2',
          'severity': 1,
          'status': 'Monitoring',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 4)),
          ),
        },

        // --- Kepong Industrial ---
        {
          'caseId': 'CASE-2024-010',
          'areaId': 'area-kepong',
          'category': 'Warehouse Fire',
          'checkIn': 'Jalan Kepong Industrial 5',
          'description':
              'Chemical warehouse caught fire. Toxic fumes reported.',
          'location': const GeoPoint(3.2110, 101.6390),
          'media': [
            'https://images.unsplash.com/photo-1481697943534-ea55b5ce970b?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 25,
          'reporterUid': 'user-kepong-1',
          'severity': 5,
          'status': 'Evacuating',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 50)),
          ),
        },
        {
          'caseId': 'CASE-2024-011',
          'areaId': 'area-kepong',
          'category': 'Road Accident',
          'checkIn': 'Kepong Sentral Crossroad',
          'description': 'Two lories collided. One driver trapped.',
          'location': const GeoPoint(3.2090, 101.6380),
          'media': [
            'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 2,
          'reporterUid': 'user-kepong-2',
          'severity': 4,
          'status': 'Dispatched',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
        },

        // --- Wangsa Maju ---
        {
          'caseId': 'CASE-2024-012',
          'areaId': 'area-wangsamaju',
          'category': 'Flash Flood',
          'checkIn': 'Wangsa Walk Parking',
          'description': 'Basement parking flooding. Water up to knee height.',
          'location': const GeoPoint(3.1860, 101.7455),
          'media': [
            'https://images.unsplash.com/photo-1545048702-793e24bb1d17?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 10,
          'reporterUid': 'user-wm-1',
          'severity': 3,
          'status': 'Requested',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(hours: 2)),
          ),
        },
        {
          'caseId': 'CASE-2024-013',
          'areaId': 'area-wangsamaju',
          'category': 'Medical',
          'checkIn': 'Wangsa Maju LRT',
          'description': 'Elderly man fainted on the escalator.',
          'location': const GeoPoint(3.1850, 101.7450),
          'media': [
            'https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?auto=format&fit=crop&w=800',
          ],
          'peopleAffected': 1,
          'reporterUid': 'user-wm-2',
          'severity': 2,
          'status': 'On Scene',
          'timestamp': Timestamp.fromDate(
            now.subtract(const Duration(minutes: 10)),
          ),
        },
      ];
      for (final c in cases) {
        batch.set(_db.collection('reported_cases').doc(), c);
      }
    }

    await batch.commit();
  }
}
