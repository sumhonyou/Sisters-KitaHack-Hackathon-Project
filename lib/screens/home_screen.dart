import 'package:flutter/material.dart';
import 'package:kitahack/services/auth_service.dart';
import 'package:kitahack/services/sos_service.dart';
import 'package:kitahack/screens/login_screen.dart';
import 'package:kitahack/screens/sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final SosService _sosService = SosService();

  bool _isSosHolding = false;
  bool _isSosLoading = false;
  double _sosProgress = 0.0;
  late AnimationController _holdController;

  // Glow beacon: slow fade in, quick snap off
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _holdController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addListener(
            () => setState(() => _sosProgress = _holdController.value),
          )
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _triggerSos();
          });

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 5),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_glowController);
  }

  @override
  void dispose() {
    _holdController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onSosHoldStart() {
    setState(() => _isSosHolding = true);
    _holdController.forward(from: 0.0);
  }

  void _onSosHoldEnd() {
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.stop();
      _holdController.reset();
      setState(() {
        _isSosHolding = false;
        _sosProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSos() async {
    setState(() {
      _isSosHolding = false;
      _isSosLoading = true;
      _sosProgress = 0.0;
    });
    _holdController.reset();

    try {
      final position = await _sosService.getCurrentLocation();
      final lat = position?.latitude;
      final lng = position?.longitude;

      final profile = await _sosService.getUserProfile();
      final name = profile?['fullName'] ?? 'Unknown User';
      final phone = profile?['phone'] ?? 'Unknown Phone';

      final caseId = await _sosService.triggerSos(lat: lat, lng: lng);
      final message = _sosService.generateEmergencyMessage(
        name: name,
        phone: phone,
        lat: lat,
        lng: lng,
        caseId: caseId,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SosScreen(
              caseId: caseId,
              lat: lat,
              lng: lng,
              userName: name,
              userPhone: phone,
              emergencyMessage: message,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('SOS Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSosLoading = false);
    }
  }

  // ─── Hold progress pill — shown above button when holding ─────────────────
  Widget _buildHoldIndicator() {
    return AnimatedOpacity(
      opacity: _isSosHolding ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hold to activate SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _sosProgress,
                minHeight: 5,
                backgroundColor: Colors.red.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SOS Button ───────────────────────────────────────────────────────────
  Widget _buildSosButton() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final glow = _isSosHolding ? 1.0 : _glowAnimation.value;
        const double buttonSize = 60.0;
        const double haloSize = 68.0; // tight halo
        const double totalSize = haloSize + 12.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHoldIndicator(),
            const SizedBox(height: 8),
            GestureDetector(
              onLongPressStart: (_) => _onSosHoldStart(),
              onLongPressEnd: (_) => _onSosHoldEnd(),
              onLongPressCancel: () => _onSosHoldEnd(),
              child: SizedBox(
                width: totalSize,
                height: totalSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow halo — only alpha animates, size is fixed
                    Container(
                      width: haloSize,
                      height: haloSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.08 * glow),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.55 * glow),
                            blurRadius: 14,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),

                    // Round button
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isSosHolding
                              ? [Colors.red.shade300, Colors.red.shade800]
                              : [
                                  const Color(0xFFFF5252), // bright red
                                  const Color(0xFFC62828), // deep crimson
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.50),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isSosLoading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 33,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityGuard'),
        backgroundColor: const Color(0xFF2575FC),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final nav = Navigator.of(context);
              await AuthService().signOut();
              nav.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome to CityGuard!\n\nHold the SOS button\nfor 3 seconds in an emergency.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
      floatingActionButton: _buildSosButton(),
    );
  }
}
