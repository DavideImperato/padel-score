import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/widgets/app_content_safe_area.dart';

void main() {
  Future<void> pumpWithInsets(
    WidgetTester tester, {
    required double left,
    required double right,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 450),
          // Simula immersiveSticky: padding azzerato, viewPadding reale.
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.fromLTRB(left, 0, right, 0),
        ),
        child: const Scaffold(
          body: AppContentSafeArea(
            child: SizedBox.expand(key: Key('page-content')),
          ),
        ),
      ),
    ));
  }

  testWidgets('Rispetta Dynamic Island a sinistra in landscape', (tester) async {
    await pumpWithInsets(tester, left: 72, right: 12);
    final rect = tester.getRect(find.byKey(const Key('page-content')));
    expect(rect.left, greaterThanOrEqualTo(72));
    expect(rect.right, lessThanOrEqualTo(800 - 12));
  });

  testWidgets('Rispetta il ritaglio dopo rotazione del telefono', (tester) async {
    await pumpWithInsets(tester, left: 12, right: 72);
    final rect = tester.getRect(find.byKey(const Key('page-content')));
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(800 - 72));
  });

  testWidgets('Senza ritagli il contenuto occupa tutta la larghezza', (tester) async {
    await pumpWithInsets(tester, left: 0, right: 0);
    final rect = tester.getRect(find.byKey(const Key('page-content')));
    expect(rect.left, 0);
    expect(rect.right, 800);
  });
}
