import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/main.dart';

void main() {
  testWidgets('App starts with login page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login page is displayed
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeast(1));
    expect(find.byType(ElevatedButton), findsAtLeast(1));
  });

  testWidgets('Login page has email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that email and password fields exist
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    
    // Verify that login button exists
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
  });

  testWidgets('Register navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap the register button
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Verify that we navigated to register page
    expect(find.text('Register'), findsOneWidget);
  });
}