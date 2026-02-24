import 'package:cloud_firestore/cloud_firestore.dart';

/// Schema: posts/{postId}
class CommunityPost {
  final String postId;
  final String authorUid;
  final String authorName; // denormalised for display
  final String authorHandle; // denormalised for display
  final String authorAvatarColor; // hex, denormalised
  final String type; // 'Update' | 'Alert' | 'Help' | 'Info'
  final String category; // 'trending' | 'following' | 'nearby'
  final String areaId; // e.g. 'downtown', 'ampang', 'kepong'
  final String title;
  final String message;
  final List<String> tags; // e.g. ['flood','klcc','rescue']
  final DateTime createdAt;

  // Engagement stats (stored in Firestore)
  final int likeCount;
  final int repostCount;
  final int viewCount;

  // UI-only transient state (not stored in Firestore)
  final bool isLikedByMe;

  const CommunityPost({
    required this.postId,
    required this.authorUid,
    this.authorName = '',
    this.authorHandle = '',
    this.authorAvatarColor = '#1A56DB',
    required this.type,
    this.category = 'trending',
    required this.areaId,
    required this.title,
    required this.message,
    this.tags = const [],
    required this.createdAt,
    this.likeCount = 0,
    this.repostCount = 0,
    this.viewCount = 0,
    this.isLikedByMe = false,
  });

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityPost(
      postId: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? '',
      authorHandle: d['authorHandle'] ?? '',
      authorAvatarColor: d['authorAvatarColor'] ?? '#1A56DB',
      type: d['type'] ?? 'Update',
      category: d['category'] ?? 'trending',
      areaId: d['areaId'] ?? '',
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      tags: List<String>.from(d['tags'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (d['likeCount'] as num?)?.toInt() ?? 0,
      repostCount: (d['repostCount'] as num?)?.toInt() ?? 0,
      viewCount: (d['viewCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: d['isLikedByMe'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'authorUid': authorUid,
    'authorName': authorName,
    'authorHandle': authorHandle,
    'authorAvatarColor': authorAvatarColor,
    'type': type,
    'category': category,
    'areaId': areaId,
    'title': title,
    'message': message,
    'tags': tags,
    'createdAt': Timestamp.fromDate(createdAt),
    'likeCount': likeCount,
    'repostCount': repostCount,
    'viewCount': viewCount,
    'isLikedByMe': isLikedByMe,
  };

  CommunityPost copyWith({bool? isLikedByMe, int? likeCount}) => CommunityPost(
    postId: postId,
    authorUid: authorUid,
    authorName: authorName,
    authorHandle: authorHandle,
    authorAvatarColor: authorAvatarColor,
    type: type,
    category: category,
    areaId: areaId,
    title: title,
    message: message,
    tags: tags,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    repostCount: repostCount,
    viewCount: viewCount,
    isLikedByMe: isLikedByMe ?? this.isLikedByMe,
  );
}

/// Schema: posts/{postId}/comments/{commentId}
class CommunityComment {
  final String commentId;
  final String authorUid;
  final String authorName; // denormalised
  final String authorHandle; // denormalised
  final String authorAvatarColor;
  final String message;
  final DateTime createdAt;

  const CommunityComment({
    required this.commentId,
    required this.authorUid,
    this.authorName = '',
    this.authorHandle = '',
    this.authorAvatarColor = '#1A56DB',
    required this.message,
    required this.createdAt,
  });

  factory CommunityComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityComment(
      commentId: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? '',
      authorHandle: d['authorHandle'] ?? '',
      authorAvatarColor: d['authorAvatarColor'] ?? '#1A56DB',
      message: d['message'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'authorUid': authorUid,
    'authorName': authorName,
    'authorHandle': authorHandle,
    'authorAvatarColor': authorAvatarColor,
    'message': message,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
