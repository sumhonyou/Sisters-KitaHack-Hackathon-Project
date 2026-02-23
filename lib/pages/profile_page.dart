import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _blue = Color(0xFF1A56DB);
  // static const _demoUid = 'demo-user-001'; // removed hardcoded

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = AuthService();
  final _picker = ImagePicker();

  UserModel? _user;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  File? _pendingPhoto;

  // Edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  bool _disability = false;
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) return;
      final doc = await _db.collection('users').doc(currentUid).get();
      if (doc.exists) {
        setState(() {
          _user = UserModel.fromFirestore(doc);
          _syncControllers();
        });
      } else {
        // Seed a demo user
        final demo = UserModel(
          uid: currentUid,
          role: 'public',
          fullName: 'Ahmad Ismail',
          email: 'ahmad.ismail@email.com',
          phone: '+60123456789',
          homeAreaId: 'area-klcc',
          disability: false,
          emergencyContacts: [
            EmergencyContact(
              name: 'Nurul Huda',
              phone: '+60198765432',
              relationship: 'Spouse',
            ),
          ],
        );
        await _db.collection('users').doc(currentUid).set(demo.toMap());
        setState(() {
          _user = demo;
          _syncControllers();
        });
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  void _syncControllers() {
    if (_user == null) return;
    _nameCtrl.text = _user!.fullName;
    _emailCtrl.text = _user!.email;
    _phoneCtrl.text = _user!.phone;
    _disability = _user!.disability;
    _contacts = _user!.emergencyContacts
        .map(
          (c) => EmergencyContact(
            name: c.name,
            phone: c.phone,
            relationship: c.relationship,
          ),
        )
        .toList();
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = _user!.copyWith(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        disability: _disability,
        emergencyContacts: _contacts,
      );
      await _db
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .update(updated.toMap());
      setState(() {
        _user = updated;
        _isEditing = false;
      });
      _showSnack('✅ Profile updated successfully', Colors.green);
    } catch (e) {
      _showSnack('Failed to save: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      final file = File(picked.path);
      setState(() {
        _pendingPhoto = file;
        _isUploadingPhoto = true;
      });

      // Upload to Firebase Storage
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) return;
      final ref = _storage.ref('profile_photos/$currentUid.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Update Firestore
      await _db.collection('users').doc(_auth.currentUser?.uid).update({
        'profilePic': url,
      });
      setState(() {
        _user = _user?.copyWith(profilePic: url);
        _isUploadingPhoto = false;
      });
      _showSnack('✅ Profile photo updated', Colors.green);
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      _showSnack('Photo upload failed: $e', Colors.red);
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────────

  void _showPasswordResetDialog() {
    final emailForReset = _user?.email ?? _emailCtrl.text.trim();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Color(0xFF1A56DB), size: 26),
            SizedBox(width: 8),
            Text(
              'Reset Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A password reset link will be sent to:',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF1A56DB),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emailForReset,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check your inbox and follow the link to set a new password. After resetting, your new password will be used for all future logins.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.send, color: Colors.white, size: 16),
            label: const Text(
              'Send Email',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _auth.sendPasswordResetEmail(emailForReset);
                _showSnack(
                  '📧 Reset email sent to $emailForReset',
                  Colors.green,
                );
              } on FirebaseAuthException catch (e) {
                _showSnack(
                  e.message ?? 'Failed to send reset email',
                  Colors.red,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Emergency Contacts Sheet ──────────────────────────────────────────────────

  void _showAddContactSheet({EmergencyContact? existing, int? index}) {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final phoneC = TextEditingController(text: existing?.phone ?? '');
    final relC = TextEditingController(text: existing?.relationship ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing == null ? 'Add Emergency Contact' : 'Edit Contact',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _inputField(nameC, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              _inputField(
                phoneC,
                'Phone Number',
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _inputField(
                relC,
                'Relationship (e.g. Spouse)',
                Icons.people_outline,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final contact = EmergencyContact(
                      name: nameC.text.trim(),
                      phone: phoneC.text.trim(),
                      relationship: relC.text.trim(),
                    );
                    setState(() {
                      if (index != null) {
                        _contacts[index] = contact;
                      } else {
                        _contacts.add(contact);
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    existing == null ? 'Add Contact' : 'Save',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _blue, size: 20),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  if (_isEditing) _buildEditForm() else _buildViewMode(),
                  const SizedBox(height: 16),
                  _buildEmergencyContactsSection(),
                  const SizedBox(height: 16),
                  _buildSecuritySection(),
                  const SizedBox(height: 16),
                  _buildSignOutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver Header ─────────────────────────────────────────────────────────────

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: _blue,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_isEditing)
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
            label: const Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = false;
                _syncControllers();
              });
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Avatar
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: ClipOval(
                        child: _isUploadingPhoto
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : _pendingPhoto != null
                            ? Image.file(_pendingPhoto!, fit: BoxFit.cover)
                            : (_user!.profilePic.isNotEmpty
                                  ? Image.network(
                                      _user!.profilePic,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _avatarInitials(),
                                    )
                                  : _avatarInitials()),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Color(0xFF1A56DB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _user!.fullName.isEmpty ? 'Your Name' : _user!.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _user!.role == 'gov' ? '🏛️ Government' : '👤 Public User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      title: const Text(
        'My Profile',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _avatarInitials() {
    final initials = _user!.fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: const Color(0xFF3B82F6),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _photoOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            _photoOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take a Photo',
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            if (_user?.profilePic.isNotEmpty == true ||
                _pendingPhoto != null) ...[
              const SizedBox(height: 8),
              _photoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  await _db
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .update({'profilePic': ''});
                  setState(() {
                    _user = _user?.copyWith(profilePic: '');
                    _pendingPhoto = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? _blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── View Mode ────────────────────────────────────────────────────────────────

  Widget _buildViewMode() {
    return _sectionCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _infoRow(Icons.badge_outlined, 'Full Name', _user!.fullName),
        _infoRow(Icons.email_outlined, 'Email', _user!.email),
        _infoRow(Icons.phone_outlined, 'Phone', _user!.phone),
        _infoRow(
          Icons.location_on_outlined,
          'Home Area',
          _user!.homeAreaId.replaceAll('area-', '').toUpperCase(),
        ),
        _infoRow(
          Icons.accessible_outlined,
          'Special Needs',
          _user!.disability ? 'Yes' : 'None',
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit Form ────────────────────────────────────────────────────────────────

  Widget _buildEditForm() {
    return _sectionCard(
      title: 'Edit Information',
      icon: Icons.edit_outlined,
      children: [
        _inputField(_nameCtrl, 'Full Name', Icons.badge_outlined),
        const SizedBox(height: 12),
        _inputField(
          _emailCtrl,
          'Email Address',
          Icons.email_outlined,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _inputField(
          _phoneCtrl,
          'Phone Number',
          Icons.phone_outlined,
          type: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.accessible_outlined, color: _blue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Disability / Special Needs',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Switch(
                value: _disability,
                onChanged: (v) => setState(() => _disability = v),
                activeThumbColor: _blue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Emergency Contacts ────────────────────────────────────────────────────────

  Widget _buildEmergencyContactsSection() {
    return _sectionCard(
      title: 'Emergency Contacts',
      icon: Icons.contact_phone_outlined,
      trailing: GestureDetector(
        onTap: () => _showAddContactSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: _blue, size: 14),
              SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      children: [
        if (_contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No emergency contacts added.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          )
        else
          ..._contacts.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: _blue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          c.phone,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          c.relationship,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF6B7280),
                      size: 18,
                    ),
                    onPressed: () =>
                        _showAddContactSheet(existing: c, index: i),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _contacts.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Security Section ──────────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return _sectionCard(
      title: 'Account Security',
      icon: Icons.security_outlined,
      children: [
        _securityTile(
          icon: Icons.lock_reset,
          title: 'Change Password',
          subtitle: 'A reset link will be sent to your email',
          onTap: _showPasswordResetDialog,
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _securityTile(
          icon: Icons.verified_user_outlined,
          title: 'Account Role',
          subtitle: _user!.role == 'gov'
              ? 'Government Account'
              : 'Public Account',
          color: const Color(0xFF22C55E),
          showArrow: false,
        ),
      ],
    );
  }

  Widget _securityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? color,
    bool showArrow = true,
  }) {
    final c = color ?? _blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: const Color(0xFFEF4444),
        ),
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Sign Out',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _auth.signOut();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section Card ──────────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
