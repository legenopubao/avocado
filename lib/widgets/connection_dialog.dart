import 'package:flutter/material.dart';

class ConnectionDialog extends StatelessWidget {
  final VoidCallback onAutoConnect;
  final VoidCallback onManualConnect;
  final VoidCallback onCancel;

  const ConnectionDialog({
    super.key,
    required this.onAutoConnect,
    required this.onManualConnect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "스마트 창문 연결",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "ESP32와 연결하기 위해\n동일한 WiFi 네트워크에 연결되어 있는지 확인해주세요.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoContainer(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildGradientButton(
                    onPressed: onAutoConnect,
                    text: "자동 연결",
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGradientButton(
                    onPressed: onManualConnect,
                    text: "수동 설정",
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancel,
              child: const Text("취소", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(3), width: 1),
      ),
      child: const Text(
        "ESP32는 보통 다음 주소 중 하나입니다:\n• http://192.168.1.100:8000\n• http://192.168.4.1:8000\n• http://esp32.local:8000",
        style: TextStyle(
          fontSize: 13,
          color: Colors.white,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String text,
    required Gradient gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
