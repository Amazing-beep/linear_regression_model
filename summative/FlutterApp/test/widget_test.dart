import 'package:flutter_test/flutter_test.dart';
import 'package:student_predictor/main.dart';

void main() {
  testWidgets('Smoke test for StudentPredictorApp', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StudentPredictorApp());

    // Verify that the title is displayed in the AppBar.
    expect(find.text('PISA Reading Score Predictor'), findsWidgets);
  });
}
