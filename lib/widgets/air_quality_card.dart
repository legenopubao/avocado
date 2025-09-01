import 'package:flutter/material.dart';
import '../services/api.dart';

class AirQualityCard extends StatelessWidget {
  final Map<String, dynamic> airStatus;
  final AirQualityData? airData;
  final int errorCount;

  const AirQualityCard({
    super.key,
    required this.airStatus,
    required this.airData,
    required this.errorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            airStatus["color"],
            airStatus["color"].withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: airStatus["color"].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "공기질 상태",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    airStatus["status"],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getAirQualityIcon(airStatus["status"]),
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (airData != null && errorCount < 3) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickData("온도", "${airData!.temperature.toStringAsFixed(1)}°C", Icons.thermostat),
                  _buildQuickData("습도", "${airData!.humidity.toStringAsFixed(1)}%", Icons.water_drop),
                  _buildQuickData("PM2.5", "${airData!.pm25.toStringAsFixed(1)}", Icons.blur_on),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickData(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  IconData _getAirQualityIcon(String status) {
    switch (status) {
      case "매우 좋음":
        return Icons.sentiment_very_satisfied;
      case "좋음":
        return Icons.sentiment_satisfied;
      case "나쁨":
        return Icons.sentiment_dissatisfied;
      case "환기 필수":
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }
}
