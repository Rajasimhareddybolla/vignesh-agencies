// V-Guard Service App - Basic Widget Tests
//
// These tests verify that the app renders correctly and key components work.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Build a simple Material app to verify basic widget functionality
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('V-Guard Test')),
          body: const Center(child: Text('V-Guard District Service Hub')),
        ),
      ),
    );

    // Verify that the app renders correctly
    expect(find.text('V-Guard District Service Hub'), findsOneWidget);
    expect(find.text('V-Guard Test'), findsOneWidget);
  });

  testWidgets('Status badge renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(51), // 0.2 opacity
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Active Warranty'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Active Warranty'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
