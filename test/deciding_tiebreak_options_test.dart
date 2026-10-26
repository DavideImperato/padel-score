import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PadelScoreProvider createAtDecider(int points, {int bestOfSets = 3}) {
    SharedPreferences.setMockInitialValues({});
    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    provider.setupMatch(
      team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: bestOfSets,
      decidingMatchTieBreak: true, decidingTieBreakPoints: points,
    );
    addTearDown(provider.dispose);
    final winners = bestOfSets == 5
        ? [Team.teamA, Team.teamB, Team.teamA, Team.teamB]
        : [Team.teamA, Team.teamB];
    for (final winner in winners) {
      for (var game = 0; game < 6; game++) {
        for (var point = 0; point < 4; point++) {
          provider.addPoint(winner);
        }
      }
    }
    expect(provider.snapshot.isMatchTieBreak, isTrue);
    return provider;
  }

  for (final bestOf in [3, 5]) {
    for (final target in [7, 10]) {
      test('Decisivo a $target in $bestOf set: vittoria, Undo, risultato', () {
        final provider = createAtDecider(target, bestOfSets: bestOf);
        expect(provider.decidingTieBreakPoints, target);
        for (var i = 0; i < target - 2; i++) {
          provider.addPoint(Team.teamA);
          provider.addPoint(Team.teamB);
        }
        expect(provider.snapshot.matchWinner, isNull);
        provider.addPoint(Team.teamA);
        expect(provider.snapshot.matchWinner, isNull);
        provider.addPoint(Team.teamA);
        expect(provider.snapshot.matchWinner, Team.teamA);
        final result = provider.snapshot.completedSets.last;
        expect(result.isMatchTieBreak, isTrue);
        expect(result.tieBreakPointsA, target);
        expect(result.tieBreakPointsB, target - 2);
        expect([result.gamesA, result.gamesB], [0, 0]);
        provider.undo();
        expect(provider.snapshot.matchWinner, isNull);
        expect(provider.snapshot.isMatchTieBreak, isTrue);
        provider.addPoint(Team.teamA);
        expect(provider.snapshot.matchWinner, Team.teamA);
      });
    }
  }

  for (final target in [7, 10]) {
    test('Parità ${target - 1}-${target - 1}: servono sempre due punti di margine', () {
      final provider = createAtDecider(target);
      for (var i = 0; i < target - 1; i++) {
        provider.addPoint(Team.teamA);
        provider.addPoint(Team.teamB);
      }
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.matchWinner, isNull);
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.matchWinner, Team.teamA);
    });
  }
}
