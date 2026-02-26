import 'package:flutter/material.dart';

class DemoNavigationBar extends StatelessWidget {
  final String currentView;
  final Function(String) onViewChanged;

  const DemoNavigationBar({
    super.key,
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton('Home'),
                const SizedBox(width: 8),
                _buildButton('Alerts List'),
                const SizedBox(width: 8),
                _buildButton('Alert Detail'),
                const SizedBox(width: 8),
                _buildButton('Banner Popup'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton('Phone Home Screen'),
                const SizedBox(width: 8),
                _buildButton('Lock Screen'),
                const SizedBox(width: 8),
                _buildButton('Lock Screen (Expanded)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label) {
    final isSelected = currentView == label;
    return GestureDetector(
      onTap: () => onViewChanged(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56DB) : const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
