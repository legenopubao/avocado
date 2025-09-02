import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class ControlSection extends StatelessWidget {
  final bool isBugDetected;
  final bool isWindowOpen;
  final bool isAutoMode;
  final VoidCallback onBugDetect;
  final VoidCallback onBugRelease;
  final VoidCallback onWindowToggle;
  final VoidCallback onAutoModeToggle;

  const ControlSection({
    super.key,
    required this.isBugDetected,
    required this.isWindowOpen,
    required this.isAutoMode,
    required this.onBugDetect,
    required this.onBugRelease,
    required this.onWindowToggle,
    required this.onAutoModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            children: [
              Icon(
                Icons.control_camera,
                color: Colors.grey[800],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "제어 섹션",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 벌레 감지 상태 및 제어
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBugDetected ? Colors.red.withValues(alpha:0.1) : Colors.green.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBugDetected ? Colors.red.withValues(alpha:0.3) : Colors.green.withValues(alpha:0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      color: isBugDetected ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "벌레 감지",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isBugDetected ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isBugDetected ? "감지됨" : "없음",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onBugDetect,
                        icon: const Icon(Icons.warning, size: 18),
                        label: const Text("벌레 감지 ON"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onBugRelease,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text("벌레 감지 OFF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 자동 제어 모드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.purple.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "자동 창문 제어",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: isAutoMode,
                      onChanged: (value) => onAutoModeToggle(),
                      activeThumbColor: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isAutoMode 
                    ? "자동 모드: 센서 데이터에 따라 창문이 자동으로 제어됩니다"
                    : "수동 모드: 사용자가 직접 창문을 제어할 수 있습니다",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 창문 제어 (자동 모드가 아닐 때만 표시)
          if (!isAutoMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.window,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "창문 제어",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWindowOpen ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isWindowOpen ? "열림" : "닫힘",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 디버그 정보 (테스트용)
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "디버그: 창문 상태 = ${isWindowOpen ? "열림" : "닫힘"}",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onWindowToggle,
                      icon: Icon(
                        isWindowOpen ? Icons.close : Icons.open_in_new,
                        size: 20,
                      ),
                      label: Text(isWindowOpen ? "창문 닫기" : "창문 열기"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isWindowOpen ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
