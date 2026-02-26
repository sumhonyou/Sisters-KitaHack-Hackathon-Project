import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneHomeScreen extends StatelessWidget {
  final VoidCallback? onAppLaunch;

  const PhoneHomeScreen({super.key, this.onAppLaunch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1620121692029-d088224efc74?q=80&w=2832&auto=format&fit=crop',
          ),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
              // Status Bar Simulation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3:42',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.signal_cellular_4_bar,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.wifi, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.battery_full,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Date
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    'Wed, Feb 25',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // App Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAppIcon(
                          'Play Store',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Google_Play_Arrow_logo.svg/1200px-Google_Play_Arrow_logo.svg.png',
                        ),
                        _buildAppIcon(
                          'Gmail',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Gmail_icon_%282020%29.svg/2560px-Gmail_icon_%282020%29.svg.png',
                        ),
                        _buildAppIcon(
                          'Photos',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Google_Photos_icon_%282020%29.svg/1024px-Google_Photos_icon_%282020%29.svg.png',
                        ),
                        _buildAppIcon(
                          'YouTube',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/YouTube_full-color_icon_%282017%29.svg/2560px-YouTube_full-color_icon_%282017%29.svg.png',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAppIcon(
                          'Phone',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/Google_Phone_icon.svg/1024px-Google_Phone_icon.svg.png',
                        ),
                        _buildAppIcon(
                          'Messages',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Google_Messages_icon_%282022%29.svg/1024px-Google_Messages_icon_%282022%29.svg.png',
                        ),
                        _buildAppIcon(
                          'Chrome',
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Google_Chrome_icon_%28February_2022%29.svg/1024px-Google_Chrome_icon_%28February_2022%29.svg.png',
                        ),
                        _buildAppIcon(
                          'City Guard',
                          'https://storage.googleapis.com/cms-storage-bucket/0dbfcc4a59529135017d.png',
                          onTap: onAppLaunch,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              // Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    const Icon(Icons.mic_none, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Home Indicator
              Container(
                width: 140,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(String label, String iconUrl, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(iconUrl),
                fit: BoxFit.contain,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
