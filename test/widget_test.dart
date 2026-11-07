import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EventHub basic widget test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('EventHub'),
          ),
        ),
      ),
    );

    expect(find.text('EventHub'), findsOneWidget);
  });
}