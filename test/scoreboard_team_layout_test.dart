import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/widgets/scoreboard_team_layout.dart';

void main() {
  Future<void> render(WidgetTester tester, Size size, {bool swap = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ScoreboardTeamLayout(
            swapSides: swap,
            teamA: const ColoredBox(
              key: Key('squadra-a'),
              color: Colors.green,
            ),
            teamB: const ColoredBox(
              key: Key('squadra-b'),
              color: Colors.blue,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('Finestra orizzontale: squadre affiancate', (tester) async {
    await render(tester, const Size(900, 480));
    final a = tester.getRect(find.byKey(const Key('squadra-a')));
    final b = tester.getRect(find.byKey(const Key('squadra-b')));
    expect(a.center.dx, lessThan(b.center.dx));
    expect(a.center.dy, closeTo(b.center.dy, 1));
  });

  testWidgets('Finestra iPad stretta: squadre una sopra l’altra', (tester) async {
    await render(tester, const Size(480, 850));
    final a = tester.getRect(find.byKey(const Key('squadra-a')));
    final b = tester.getRect(find.byKey(const Key('squadra-b')));
    expect(a.center.dy, lessThan(b.center.dy));
    expect(a.center.dx, closeTo(b.center.dx, 1));
  });

  testWidgets('Cambio campo valido anche in finestra stretta', (tester) async {
    await render(tester, const Size(480, 850), swap: true);
    expect(
      tester.getRect(find.byKey(const Key('squadra-b'))).center.dy,
      lessThan(tester.getRect(find.byKey(const Key('squadra-a'))).center.dy),
    );
  });
}
