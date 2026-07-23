import 'package:flutter/material.dart';

/// A card widget displaying the predicted reading score result.
class PredictionCard extends StatelessWidget {
  final double score;
  final String modelName;

  const PredictionCard({
    super.key,
    required this.score,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    const primaryEmerald = Color(0xFF047857);
    const bgEmerald = Color(0xFFECFDF5);
    const borderEmerald = Color(0xFFA7F3D0);
    const darkEmerald = Color(0xFF065F46);

    return Card(
      elevation: 3,
      color: bgEmerald,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderEmerald, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: primaryEmerald,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'PREDICTED READING SCORE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryEmerald,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              score.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: darkEmerald,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Model: $modelName',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryEmerald,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estimated student reading score based on PISA evaluation metric.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
