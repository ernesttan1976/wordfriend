// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wordfriend_app/main.dart';

void main() {
  testWidgets('shows sign-in screen when not authenticated', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const WordFriendApp());

    // By default there is no token, so the sign-in screen should be visible.
    expect(find.text('Sign in to WordFriend'), findsOneWidget);
  });
}
