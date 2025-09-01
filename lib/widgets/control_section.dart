import 'package:flutter/material.dart';

class ControlSection extends StatelessWidget {
  final bool isBugDetected;
  final VoidCallback onBugDetect;
  final VoidCallback onBugRelease;

  const ControlSection({
    super.key,
    required this.isBugDetected,
    required this.onBugDetect,
    required this.onBugRelease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isBugDetected 
                    ? const Color(0xFFFF5722).withValues(alpha:0.1)
                    : const Color(0xFF4CAF50).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.pest_control,
                  size: 32,
                  color: isBugDetected ? const Color(0xFFFF5722) : const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isBugDetected ? '벌레 감지됨' : '감지 해제',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isBugDetected ? const Color(0xFFFF5722) : const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: Icons.block,
                  label: '벌레 감지\n(닫기)',
                  onPressed: onBugDetect,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControlButton(
                  icon: Icons.autorenew,
                  label: '해제\n(자동 복귀)',
                  onPressed: onBugRelease,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
