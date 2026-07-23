/// Data model representing the response returned by the /predict API endpoint.
class PredictionResponse {
  final double predictedReadingScore;
  final String model;
  final String status;

  const PredictionResponse({
    required this.predictedReadingScore,
    required this.model,
    required this.status,
  });

  /// Constructs a [PredictionResponse] instance from a JSON map.
  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    final rawScore = json['predicted_reading_score'];
    final double score = (rawScore is num) ? rawScore.toDouble() : 0.0;

    return PredictionResponse(
      predictedReadingScore: score,
      model: json['model'] as String? ?? 'Unknown Model',
      status: json['status'] as String? ?? 'success',
    );
  }
}
