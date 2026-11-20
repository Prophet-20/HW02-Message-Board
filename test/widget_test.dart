import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/main.dart';

void main() {
  testWidgets('Splash remains visible until initialization finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Launch(Completer<void>().future)),
    );
    expect(find.text('Common Room'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
