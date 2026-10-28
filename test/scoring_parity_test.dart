import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';

import 'support/fake_tts_service.dart';

/// Esegue sequenze congelate di regressione del punteggio,
/// preservate dopo la rimozione della vecchia implementazione React.
///
/// Avvio dalla root del progetto Flutter:
///   flutter test test/scoring_parity_test.dart
/// Per il progetto annidato: cd flutter_project && flutter test ...
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final file = File('test/fixtures/scoring_parity_cases.json');
  if (!file.existsSync()) {
    throw StateError('Fixture parità mancante: ${file.path}');
  }
  final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  if (payload['version'] != 1) {
    throw StateError('Versione fixture non supportata: ${payload['version']}');
  }
  final cases = payload['cases'] as List<dynamic>;

  for (final rawCase in cases) {
    final scenario = rawCase as Map<String, dynamic>;
    test('Punteggio - fixture: ${scenario['id']}', () {
      SharedPreferences.setMockInitialValues({});

      final provider = PadelScoreProvider(ttsService: FakeTtsService());
      addTearDown(provider.dispose);
      final initialServer = scenario['firstServerPlayerId'] as int;
      provider.setupMatch(
        team1: 'Squadra A',
        team2: 'Squadra B',
        player1: 'Alex',
        player2: 'Luigi',
        player3: 'Alex',
        player4: 'Marco',
        firstServerPlayerId: initialServer,
        goldenPoint: scenario['goldenPoint'] as bool,
        advantagesBeforeGoldenPoint: scenario['advantages'] as int,
        bestOfSets: scenario['bestOfSets'] as int,
        shortSets: scenario['shortSets'] == true,
      );

      final states = scenario['states'] as List<dynamic>;
      final actions = scenario['actions'] as List<dynamic>;
      expect(states.length, actions.length + 1,
          reason: 'Ogni azione deve avere un checkpoint, incluso quello iniziale');

      for (var step = 0; step <= actions.length; step++) {
        if (step > 0) {
          switch (actions[step - 1] as String) {
            case 'A':
              provider.addPoint(Team.teamA);
              break;
            case 'B':
              provider.addPoint(Team.teamB);
              break;
            case 'U':
              provider.undo();
              break;
            default:
              fail('Azione sconosciuta: ${actions[step - 1]}');
          }
        }

        final snapshot = provider.snapshot;
        final actual = <String, dynamic>{
          'rawPointsA': snapshot.rawPointsA,
          'rawPointsB': snapshot.rawPointsB,
          'deuceCount': snapshot.deuceCount,
          'currentGamesA': snapshot.currentGamesA,
          'currentGamesB': snapshot.currentGamesB,
          'servingTeam': snapshot.servingTeam.name,
          'servingRotationIndex': snapshot.servingRotationIndex,
          'serverPlayerId': provider.currentServerPlayerId,
          'initialSetServer': snapshot.initialSetServer.name,
          'isTieBreak': snapshot.isTieBreak,
          'tieBreakPointsA': snapshot.tieBreakPointsA,
          'tieBreakPointsB': snapshot.tieBreakPointsB,
          'tieBreakInitialRotationIndex': snapshot.tieBreakInitialRotationIndex,
          'matchWinner': snapshot.matchWinner?.name,
          'completedSets': snapshot.completedSets
              .map((set) => <String, dynamic>{
                    'gamesA': set.gamesA,
                    'gamesB': set.gamesB,
                    'tieBreakPointsA': set.tieBreakPointsA,
                    'tieBreakPointsB': set.tieBreakPointsB,
                    'winner': set.winner?.name,
                  })
              .toList(),
        };

        final expected = (states[step] as Map).cast<String, dynamic>();
        expect(actual, equals(expected),
            reason: 'Scenario ${scenario['id']}, step $step '
                '(azione: ${step == 0 ? 'iniziale' : actions[step - 1]})');
      }
    });
  }
}
