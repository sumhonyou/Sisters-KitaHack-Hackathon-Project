import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneHomeScreen extends StatelessWidget {
  const PhoneHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop',
          ),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // Time and Date
          Text(
            '9:41',
            style: GoogleFonts.outfit(
              fontSize: 80,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          Text(
            'Wednesday, 25 February',
            style: GoogleFonts.outfit(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const Spacer(),
          // App Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 24,
              crossAxisSpacing: 20,
              children: [
                _buildAppIcon(Icons.message, 'Messages', Colors.green),
                _buildAppIcon(Icons.phone, 'Phone', Colors.blue),
                _buildAppIcon(Icons.explore, 'Safari', Colors.blueAccent),
                _buildAppIcon(Icons.mail, 'Mail', Colors.lightBlue),
                _buildAppIcon(Icons.calendar_today, 'Calendar', Colors.white),
                _buildAppIcon(Icons.photo_library, 'Photos', Colors.white),
                _buildAppIcon(Icons.music_note, 'Music', Colors.pink),
                _buildAppIcon(Icons.map, 'Maps', Colors.greenAccent),
                _buildAppIcon(Icons.settings, 'Settings', Colors.grey),
                _buildAppIcon(Icons.cloud, 'Weather', Colors.lightBlue),
                _buildAppIcon(Icons.fitness_center, 'Fitness', Colors.orange),
                _buildAppIcon(
                  Icons.security,
                  'City Guard',
                  const Color(0xFF1A56DB),
                  isTarget: true,
                ),
              ],
            ),
          ),
          // Dock
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDockIcon(Icons.camera_alt, Colors.grey[400]!),
                _buildDockIcon(Icons.chat_bubble, Colors.green),
                _buildDockIcon(Icons.web, Colors.blue),
                _buildDockIcon(Icons.apple, Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAppIcon(
    IconData icon,
    String label,
    Color color, {
    bool isTarget = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isTarget
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: color == Colors.white ? Colors.black : Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDockIcon(IconData icon, Color color) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color == Colors.white ? Colors.black : Colors.white,
        size: 28,
      ),
    );
  }
}
