import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/widgets/app_about_footer.dart';

void main() {
  testWidgets('Versione reale e sviluppatore con link corretto', (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AppAboutFooter(
        versionLoader: () async => '1.2.3 (45)',
        onOpenDeveloper: (uri) async {
          opened = uri;
          return true;
        },
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Versione 1.2.3 (45)'), findsOneWidget);
    expect(find.text('Sviluppatore: Davide Imperato'), findsOneWidget);
    await tester.tap(find.text('Sviluppatore: Davide Imperato'));
    await tester.pump();
    expect(opened.toString(), 'https://davideimperato.it/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Link non disponibile mostra un avviso', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AppAboutFooter(
        versionLoader: () async => '1.0.0 (1)',
        onOpenDeveloper: (_) async => false,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sviluppatore: Davide Imperato'));
    await tester.pumpAndSettle();
    expect(find.text('Impossibile aprire il sito dello sviluppatore.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
