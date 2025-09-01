import 'package:flutter/material.dart';
import '../services/api.dart';

class SensorGrid extends StatelessWidget {
  final AirQualityData airData;

  const SensorGrid({super.key, required this.airData});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSensorCard(
          Icons.thermostat,
          "온도 (SHT31)",
          "${airData.temperature.toStringAsFixed(1)}°C",
          const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
          ),
        ),
        _buildSensorCard(
          Icons.water_drop,
          "습도 (SHT31)",
          "${airData.humidity.toStringAsFixed(1)}%",
          const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
          ),
        ),
        _buildSensorCard(
          Icons.cloud,
          "CO2",
          "${airData.co2.toStringAsFixed(1)} ppm",
          const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
        ),
        _buildSensorCard(
          Icons.air,
          "TVOC",
          "${airData.tvoc.toStringAsFixed(1)} ppb",
          const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
          ),
        ),
        _buildSensorCard(
          Icons.blur_on,
          "PM2.5",
          "${airData.pm25.toStringAsFixed(1)} μg/m³",
          const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
          ),
          isHighlighted: true,
        ),
        _buildSensorCard(
          Icons.blur_circular,
          "PM10",
          "${airData.pm10.toStringAsFixed(1)} μg/m³",
          const LinearGradient(
            colors: [Color(0xFF795548), Color(0xFFA1887F)],
          ),
          isHighlighted: true,
        ),
      ],
    );
  }

  Widget _buildSensorCard(IconData icon, String title, String value, LinearGradient gradient, {bool isHighlighted = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: isHighlighted ? 15 : 10,
            offset: const Offset(0, 5),
          ),
          if (isHighlighted)
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
        border: isHighlighted ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isHighlighted ? 36 : 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isHighlighted ? 15 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isHighlighted ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (isHighlighted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "중요",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
