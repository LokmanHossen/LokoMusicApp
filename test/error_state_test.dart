import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

void main() {
  testWidgets('ErrorState fits a short section and keeps retry available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 120,
              child: ErrorState(
                message: 'Too many requests. Please wait a moment.',
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
  });
}
