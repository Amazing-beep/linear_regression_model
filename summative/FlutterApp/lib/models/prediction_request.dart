/// Data model representing the payload sent to the /predict API endpoint.
class PredictionRequest {
  final int grade;
  final int male;
  final String raceeth;
  final double expectBachelors;
  final double read30MinsADay;
  final double minutesPerWeekEnglish;
  final double studentsInEnglish;
  final double schoolSize;

  const PredictionRequest({
    required this.grade,
    required this.male,
    required this.raceeth,
    required this.expectBachelors,
    required this.read30MinsADay,
    required this.minutesPerWeekEnglish,
    required this.studentsInEnglish,
    required this.schoolSize,
  });

  /// Converts the model instance into a JSON-encodable map.
  Map<String, dynamic> toJson() {
    return {
      'grade': grade,
      'male': male,
      'raceeth': raceeth,
      'expectBachelors': expectBachelors,
      'read30MinsADay': read30MinsADay,
      'minutesPerWeekEnglish': minutesPerWeekEnglish,
      'studentsInEnglish': studentsInEnglish,
      'schoolSize': schoolSize,
    };
  }
}
