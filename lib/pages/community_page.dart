import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/community_post_model.dart';
import '../services/firestore_service.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late TabController _tabController;
  final TextEditingController _composeCtrl = TextEditingController();

  static const _tabs = ['Trending', 'Following', 'Nearby'];
  static const _categories = ['trending', 'following', 'nearby'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fs.seedSampleDataIfEmpty();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _composeCtrl.dispose();
    super.dispose();
  }

  Stream<List<CommunityPost>> _streamForTab(int index) {
    return _fs.communityPostsByCategory(_categories[index]);
  }

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(dt);
  }

  String _compactCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Color _tagColor(String type) {
    switch (type) {
      case 'Alert':
        return const Color(0xFFDC2626);
      case 'Help':
        return const Color(0xFFEA580C);
      case 'Info':
        return const Color(0xFF2563EB);
      case 'Update':
      default:
        return const Color(0xFF7C3AED);
    }
  }

  // ─── Build Post Card (matching Figma) ────────────────────────────────────────
  Widget _buildPostCard(CommunityPost post) {
    final avatarColor = _hexColor(post.authorAvatarColor);
    final initials = post.authorName.isNotEmpty
        ? post.authorName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Author row ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: avatarColor,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + handle + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              post.authorHandle,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '· ${_timeAgo(post.createdAt)}',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Tag badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tagColor(post.type).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            post.type,
                            style: TextStyle(
                              color: _tagColor(post.type),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More button
                  const Icon(
                    Icons.more_horiz,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Post content ────────────────────────────────────────────────
              Text(
                post.message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 12),
              // ── Stats row ────────────────────────────────────────────────
              Row(
                children: [
                  _statItem(Icons.favorite, post.likeCount, Colors.red),
                  const SizedBox(width: 16),
                  StreamBuilder<List<CommunityComment>>(
                    stream: _fs.commentsStream(post.postId),
                    builder: (_, snap) {
                      final count = snap.data?.length ?? 0;
                      return _statItem(
                        Icons.chat_bubble_outline,
                        count,
                        const Color(0xFF6B7280),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _statItem(
                    Icons.repeat,
                    post.repostCount,
                    const Color(0xFF6B7280),
                  ),
                  const Spacer(),
                  _statItem(
                    Icons.visibility_outlined,
                    post.viewCount,
                    const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Action buttons ────────────────────────────────────────────────
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        Row(
          children: [
            Expanded(
              child: _actionBtn(
                icon: post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                label: 'Like',
                color: post.isLikedByMe ? Colors.red : const Color(0xFF6B7280),
                onTap: () => _toggleLike(post),
              ),
            ),
            _vertDivider(),
            Expanded(
              child: _actionBtn(
                icon: Icons.chat_bubble_outline,
                label: 'Comment',
                color: const Color(0xFF6B7280),
                onTap: () => _showCommentSheet(post),
              ),
            ),
            _vertDivider(),
            Expanded(
              child: _actionBtn(
                icon: Icons.ios_share_outlined,
                label: 'Share',
                color: const Color(0xFF6B7280),
                onTap: () => _sharePost(post),
              ),
            ),
          ],
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  Widget _statItem(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          _compactCount(count),
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _vertDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFFF3F4F6));

  void _toggleLike(CommunityPost post) {
    _fs.togglePostLike(post.postId, !post.isLikedByMe, post.likeCount);
  }

  void _sharePost(CommunityPost post) {
    final text =
        'CityGuard Update: ${post.title}\n\n'
        '${post.message}\n\n'
        'Shared via CityGuard Safety Platform.\n'
        'Check it out: https://cityguard.app/posts/${post.postId}';

    SharePlus.instance.share(ShareParams(text: text, subject: post.title));
  }

  // ─── Comment Sheet ────────────────────────────────────────────────────────
  void _showCommentSheet(CommunityPost post) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Comments',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Comments list
              Expanded(
                child: StreamBuilder<List<CommunityComment>>(
                  stream: _fs.commentsStream(post.postId),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comments = snap.data ?? [];
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _buildCommentTile(comments[i]),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Reply input
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentCtrl,
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final msg = commentCtrl.text.trim();
                        if (msg.isEmpty) return;
                        final comment = CommunityComment(
                          commentId: '',
                          authorUid: 'demo-user-001',
                          authorName: 'You',
                          authorHandle: '@you',
                          authorAvatarColor: '#1A56DB',
                          message: msg,
                          createdAt: DateTime.now(),
                        );
                        await _fs.addComment(post.postId, comment);
                        commentCtrl.clear();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommunityComment c) {
    final color = _hexColor(c.authorAvatarColor);
    final initials = c.authorName.isNotEmpty
        ? c.authorName
              .trim()
              .split(' ')
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: color,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    c.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${_timeAgo(c.createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.message,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── New Post Dialog ─────────────────────────────────────────────────────
  void _showNewPostDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String selectedType = 'Update';
    String selectedCategory = 'trending';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('New Post'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector
                Wrap(
                  spacing: 8,
                  children: ['Update', 'Alert', 'Help', 'Info'].map((t) {
                    final selected = selectedType == t;
                    return ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (_) => setInner(() => selectedType = t),
                      selectedColor: _tagColor(t).withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: selected ? _tagColor(t) : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Category selector
                Wrap(
                  spacing: 8,
                  children:
                      [
                        ['trending', 'Trending'],
                        ['following', 'Following'],
                        ['nearby', 'Nearby'],
                      ].map((c) {
                        final selected = selectedCategory == c[0];
                        return ChoiceChip(
                          label: Text(c[1]),
                          selected: selected,
                          onSelected: (_) =>
                              setInner(() => selectedCategory = c[0]),
                          selectedColor: const Color(
                            0xFF1E3A5F,
                          ).withValues(alpha: 0.15),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Title…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe what\'s happening…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final msg = msgCtrl.text.trim();
                if (title.isEmpty || msg.isEmpty) return;
                final post = CommunityPost(
                  postId: '',
                  authorUid: 'demo-user-001',
                  authorName: 'You',
                  authorHandle: '@you',
                  authorAvatarColor: '#1A56DB',
                  type: selectedType,
                  category: selectedCategory,
                  areaId: 'downtown',
                  title: title,
                  message: msg,
                  tags: [selectedType.toLowerCase()],
                  createdAt: DateTime.now(),
                );
                await _fs.addPost(post);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          'Community',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Text(
                          'Downtown District · 234 members',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '45 active',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Pill Tab Bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                tabs: _tabs.map((t) => Tab(text: t, height: 36)).toList(),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // ── Feed ────────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(3, (i) {
                  return StreamBuilder<List<CommunityPost>>(
                    stream: _streamForTab(i),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF22C55E),
                          ),
                        );
                      }
                      final posts = snap.data ?? [];
                      if (posts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No posts yet in ${_tabs[i]}',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (_, idx) => _buildPostCard(posts[idx]),
                      );
                    },
                  );
                }),
              ),
            ),

            // ── Compose Bar ──────────────────────────────────────────────────
            _buildComposeBar(),
          ],
        ),
      ),
      // FAB
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewPostDialog,
        backgroundColor: const Color(0xFF22C55E),
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildComposeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Text input
          TextField(
            controller: _composeCtrl,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) _showNewPostDialog();
            },
          ),
          const SizedBox(height: 8),
          // Emoji quick-reaction row
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['😊', '❤️', '🔥', '🙏', '💪', '⚠️', '🆘', '✅']
                        .map(
                          (e) => GestureDetector(
                            onTap: () {
                              _composeCtrl.text += e;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.image_outlined, color: Colors.grey.shade500, size: 26),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning !!!';
    if (h < 17) return 'Good afternoon !!!';
    return 'Good evening !!!';
  }
}
