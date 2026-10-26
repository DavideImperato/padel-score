import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PadelScoreProvider createProvider({int bestOfSets = 3, bool enabled = true}) {
    SharedPreferences.setMockInitialValues({});
    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    provider.setupMatch(
      team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: bestOfSets,
      decidingMatchTieBreak: enabled,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  void sixZero(PadelScoreProvider provider, Team winner) {
    for (var game = 0; game < 6; game++) {
      for (var point = 0; point < 4; point++) {
        provider.addPoint(winner);
      }
    }
  }

  PadelScoreProvider atDecider({int bestOfSets = 3, bool enabled = true}) {
    final provider = createProvider(bestOfSets: bestOfSets, enabled: enabled);
    sixZero(provider, Team.teamA);
    sixZero(provider, Team.teamB);
    if (bestOfSets == 5) {
      sixZero(provider, Team.teamA);
      sixZero(provider, Team.teamB);
    }
    return provider;
  }

  for (final bestOf in [3, 5]) {
    test('Match TB $bestOf set: servizio, 10-8, Undo e blocco finale', () {
      final provider = atDecider(bestOfSets: bestOf);
      expect(provider.snapshot.isTieBreak, isTrue);
      expect(provider.snapshot.isMatchTieBreak, isTrue);
      expect(provider.snapshot.completedSets.length, bestOf - 1);
      final rotation = getRotationOrder(1);
      final startIndex = provider.snapshot.tieBreakInitialRotationIndex!;
      expect(provider.currentServerPlayerId, rotation[startIndex % 4]);
      provider.addPoint(Team.teamA);
      expect(provider.currentServerPlayerId, rotation[(startIndex + 1) % 4]);
      provider.addPoint(Team.teamB);
      expect(provider.currentServerPlayerId, rotation[(startIndex + 1) % 4]);
      provider.undo();
      provider.undo();
      expect(provider.snapshot.tieBreakPointsA, 0);
      expect(provider.snapshot.tieBreakPointsB, 0);
      for (var i = 0; i < 9; i++) { provider.addPoint(Team.teamA); }
      for (var i = 0; i < 8; i++) { provider.addPoint(Team.teamB); }
      expect(provider.snapshot.matchWinner, isNull);
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.matchWinner, Team.teamA);
      expect(provider.snapshot.completedSets.length, bestOf);
      final decidingSet = provider.snapshot.completedSets.last;
      expect(decidingSet.isMatchTieBreak, isTrue);
      expect([decidingSet.gamesA, decidingSet.gamesB], [0, 0]);
      expect([decidingSet.tieBreakPointsA, decidingSet.tieBreakPointsB], [10, 8]);
      provider.addPoint(Team.teamB);
      expect(provider.snapshot.matchWinner, Team.teamA);
      provider.undo();
      expect(provider.snapshot.matchWinner, isNull);
      expect(provider.snapshot.isMatchTieBreak, isTrue);
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.matchWinner, Team.teamA);
    });
  }

  test('Sul 9-9 si prosegue fino a 11-9', () {
    final provider = atDecider();
    for (var i = 0; i < 9; i++) {
      provider.addPoint(Team.teamA);
      provider.addPoint(Team.teamB);
    }
    expect(provider.snapshot.matchWinner, isNull);
    provider.addPoint(Team.teamA);
    expect(provider.snapshot.matchWinner, isNull);
    provider.addPoint(Team.teamA);
    expect(provider.snapshot.matchWinner, Team.teamA);
    expect(provider.snapshot.completedSets.last.tieBreakPointsA, 11);
    expect(provider.snapshot.completedSets.last.tieBreakPointsB, 9);
  });

  test('Modalità disattivata mantiene il set tradizionale', () {
    final provider = atDecider(enabled: false);
    expect(provider.snapshot.isTieBreak, isFalse);
    expect(provider.snapshot.isMatchTieBreak, isFalse);
  });

  test('Al meglio di 1 set non avvia match TB', () {
    final provider = createProvider(bestOfSets: 1);
    sixZero(provider, Team.teamA);
    expect(provider.snapshot.matchWinner, Team.teamA);
  });
}
