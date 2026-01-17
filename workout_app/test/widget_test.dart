// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:workout_app/main.dart';

void main() {
  testWidgets('App loads and shows shoulder workout title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WorkoutTrackerApp());

    // Verify that the app title is displayed
    expect(find.text('💪 Shoulder Workout'), findsOneWidget);

    // Verify that the yellow band indicator is shown
    expect(find.text('Yellow Band (Lightest)'), findsOneWidget);

    // Verify that exercises are displayed
    expect(find.text('Shoulder Press'), findsOneWidget);
    expect(find.text('Lateral Raise'), findsOneWidget);
  });
}
