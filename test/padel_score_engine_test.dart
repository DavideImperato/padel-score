import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'support/fake_tts_service.dart';

PadelScoreProvider createTestProvider({
  int firstServerPlayerId = 1,
  bool goldenPoint = true,
  int advantagesBeforeGoldenPoint = 0,
  int bestOfSets = 3,
  String p1 = 'Mario',
  String p2 = 'Luigi',
  String p3 = 'Paolo',
  String p4 = 'Marco',
}) {
  final mockTts = FakeTtsService();
  final provider = PadelScoreProvider(ttsService: mockTts);
  provider.setupMatch(
    team1: 'Squadra A',
    team2: 'Squadra B',
    player1: p1,
    player2: p2,
    player3: p3,
    player4: p4,
    firstServerPlayerId: firstServerPlayerId,
    goldenPoint: goldenPoint,
    advantagesBeforeGoldenPoint: advantagesBeforeGoldenPoint,
    bestOfSets: bestOfSets,
  );
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stato nullable e configurazione — Fase 2B.3A.1', () {
    test('copyWith conserva gli stati nullable omessi', () {
      final previous = PadelMatchSnapshot.initial().copyWith(
        tieBreakInitialRotationIndex: 3,
        matchWinner: Team.teamB,
      );
      final next = previous.copyWith(rawPointsA: 1);
      expect(next.tieBreakInitialRotationIndex, 3);
      expect(next.matchWinner, Team.teamB);
    });

    test('copyWith permette di azzerare esplicitamente entrambi i nullable', () {
      final previous = PadelMatchSnapshot.initial().copyWith(
        tieBreakInitialRotationIndex: 3,
        matchWinner: Team.teamB,
      );
      final next = previous.copyWith(
        tieBreakInitialRotationIndex: null,
        matchWinner: null,
      );
      expect(next.tieBreakInitialRotationIndex, isNull);
      expect(next.matchWinner, isNull);
    });

    test('il setup memorizza realmente la modalità Star Point', () {
      final provider = createTestProvider(
        goldenPoint: true,
        advantagesBeforeGoldenPoint: 2,
      );
      expect(provider.isGoldenPoint, isTrue);
      expect(provider.advantagesBeforeGoldenPoint, 2);
      expect(provider.snapshot.isGoldenPointSituation(true, 2), isFalse);
      provider.dispose();
    });
  });

  group('PADEL SCORE ENGINE — FASE 2B.3A FLUTTER TESTS', () {
    // 1. Battitore iniziale 1, 2, 3 e 4
    test('1. Battitore iniziale 1, 2, 3 e 4', () {
      final p1 = createTestProvider(firstServerPlayerId: 1);
      expect(p1.currentServerPlayerId, equals(1));
      expect(p1.snapshot.servingTeam, equals(Team.teamA));

      final p2 = createTestProvider(firstServerPlayerId: 2);
      expect(p2.currentServerPlayerId, equals(2));
      expect(p2.snapshot.servingTeam, equals(Team.teamA));

      final p3 = createTestProvider(firstServerPlayerId: 3);
      expect(p3.currentServerPlayerId, equals(3));
      expect(p3.snapshot.servingTeam, equals(Team.teamB));

      final p4 = createTestProvider(firstServerPlayerId: 4);
      expect(p4.currentServerPlayerId, equals(4));
      expect(p4.snapshot.servingTeam, equals(Team.teamB));
    });

    // 2. Due giocatori con lo stesso nome
    test('2. Due giocatori con lo stesso nome in squadre opposte', () {
      final provider = createTestProvider(
        firstServerPlayerId: 1,
        p1: 'Alex',
        p2: 'Luigi',
        p3: 'Alex', // Stesso nome di p1
        p4: 'Marco',
      );

      expect(provider.currentServerPlayerId, equals(1));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
      expect(provider.currentServingPlayerName, equals('Alex'));

      // Vinci Game 1 (4 punti per Team A)
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamA);
      }

      // Ora tocca a Giocatore 3 (Squadra B) che si chiama anch'esso "Alex"
      expect(provider.snapshot.currentGamesA, equals(1));
      expect(provider.currentServerPlayerId, equals(3));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      expect(provider.currentServingPlayerName, equals('Alex'));
    });

    // 3. Rotazione dei battitori FIP
    test('3. Rotazione dei 4 battitori (Game 1..4)', () {
      final provider = createTestProvider(firstServerPlayerId: 1);

      // Game 1: P1 (Team A)
      expect(provider.currentServerPlayerId, equals(1));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamA);
      }

      // Game 2: P3 (Team B)
      expect(provider.currentServerPlayerId, equals(3));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamB);
      }

      // Game 3: P2 (Team A)
      expect(provider.currentServerPlayerId, equals(2));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamA);
      }

      // Game 4: P4 (Team B)
      expect(provider.currentServerPlayerId, equals(4));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamB);
      }

      // Game 5: Ritorna ciclicamente a P1 (Team A)
      expect(provider.currentServerPlayerId, equals(1));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
    });

    // 4. Game vinto
    test('4. Game vinto con progressione standard 0-15-30-40-Vinto', () {
      final provider = createTestProvider();

      expect(provider.snapshot.displayPointA, equals('0'));
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('15'));
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('30'));
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('40'));
      provider.addPoint(Team.teamA);

      // Game assegnato
      expect(provider.snapshot.currentGamesA, equals(1));
      expect(provider.snapshot.displayPointA, equals('0'));
      expect(provider.snapshot.displayPointB, equals('0'));
    });

    // 5. Set concluso 6-4 e 6-3 (Regola FIP servizio nel set successivo)
    test('5. Set concluso 6-4 (10 game) e 6-3 (9 game) con alternanza FIP', () {
      // Caso A: 6-4 (10 game totali)
      final pA = createTestProvider(firstServerPlayerId: 1);
      // Gioca 10 game: 6 a Team A, 4 a Team B
      for (int g = 0; g < 4; g++) {
        for (int p = 0; p < 4; p++) {
          pA.addPoint(Team.teamA);
        }
        for (int p = 0; p < 4; p++) {
          pA.addPoint(Team.teamB);
        }
      }
      // Punteggio 4-4 (8 game). Vinci altri 2 game per Team A -> 6-4
      for (int p = 0; p < 4; p++) {
        pA.addPoint(Team.teamA);
      } // 5-4
      for (int p = 0; p < 4; p++) {
        pA.addPoint(Team.teamA);
      } // 6-4 Set 1 concluso!

      expect(pA.snapshot.completedSets.length, equals(1));
      expect(pA.snapshot.completedSets[0].gamesA, equals(6));
      expect(pA.snapshot.completedSets[0].gamesB, equals(4));
      // Dopo 10 game serviti, il 1° game del Set 2 spetta a Squadra A (P2)
      expect(pA.snapshot.servingTeam, equals(Team.teamA));
      expect(pA.currentServerPlayerId, equals(2));

      // Caso B: 6-3 (9 game totali)
      final pB = createTestProvider(firstServerPlayerId: 1);
      for (int g = 0; g < 3; g++) {
        for (int p = 0; p < 4; p++) {
          pB.addPoint(Team.teamA);
        }
        for (int p = 0; p < 4; p++) {
          pB.addPoint(Team.teamB);
        }
      }
      // 3-3 (6 game). Vinci altri 3 game con Team A -> 6-3
      for (int p = 0; p < 4; p++) {
        pB.addPoint(Team.teamA);
      } // 4-3
      for (int p = 0; p < 4; p++) {
        pB.addPoint(Team.teamA);
      } // 5-3
      for (int p = 0; p < 4; p++) {
        pB.addPoint(Team.teamA);
      } // 6-3 Set 1 concluso!

      expect(pB.snapshot.completedSets.length, equals(1));
      expect(pB.snapshot.completedSets[0].gamesA, equals(6));
      expect(pB.snapshot.completedSets[0].gamesB, equals(3));
      // Dopo 9 game serviti, il 1° game del Set 2 spetta a Squadra B (P3)
      expect(pB.snapshot.servingTeam, equals(Team.teamB));
      expect(pB.currentServerPlayerId, equals(3));
    });

    // 6. Tie-break e relativo ordine di servizio (sequenza 1-2-2-2)
    test('6. Tie-break sul 6-6 e sequenza di battuta 1-2-2-2', () {
      final provider = createTestProvider(firstServerPlayerId: 1);
      // Arriva a 6-6 (12 game)
      for (int g = 0; g < 6; g++) {
        for (int p = 0; p < 4; p++) {
          provider.addPoint(Team.teamA);
        }
        for (int p = 0; p < 4; p++) {
          provider.addPoint(Team.teamB);
        }
      }

      expect(provider.snapshot.currentGamesA, equals(6));
      expect(provider.snapshot.currentGamesB, equals(6));
      expect(provider.snapshot.isTieBreak, isTrue);

      // Tie-Break: 12 game trascorsi -> tocca al battitore del Turno 12 % 4 = Turno 0 (Giocatore 1, Team A)
      expect(provider.currentServerPlayerId, equals(1));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));

      // Punto 1: batte P1 (Team A)
      provider.addPoint(Team.teamA); // 1-0
      // Punti 2 & 3: batte P3 (Team B)
      expect(provider.currentServerPlayerId, equals(3));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      provider.addPoint(Team.teamB); // 1-1
      expect(provider.currentServerPlayerId, equals(3));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));

      // Punti 4 & 5: batte P2 (Team A)
      provider.addPoint(Team.teamA); // 2-1
      expect(provider.currentServerPlayerId, equals(2));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
    });

    // 7. Servizio dopo tie-break (Regola FIP)
    test('7. Servizio nel 1° game del set successivo dopo un tie-break', () {
      final provider = createTestProvider(firstServerPlayerId: 1);
      // Arriva a 6-6
      for (int g = 0; g < 6; g++) {
        for (int p = 0; p < 4; p++) {
          provider.addPoint(Team.teamA);
        }
        for (int p = 0; p < 4; p++) {
          provider.addPoint(Team.teamB);
        }
      }
      expect(provider.snapshot.isTieBreak, isTrue);
      // Tie-break iniziato da Team A (P1)
      // Vinci il tie-break 7-0 con Team A
      for (int tb = 0; tb < 7; tb++) {
        provider.addPoint(Team.teamA);
      }

      expect(provider.snapshot.completedSets.length, equals(1));
      expect(provider.snapshot.completedSets[0].gamesA, equals(7));
      expect(provider.snapshot.completedSets[0].gamesB, equals(6));
      expect(provider.snapshot.isTieBreak, isFalse);

      // FIP: la squadra che ha iniziato il tie-break (Team A) RICEVE nel 1° game del Set 2.
      // Il servizio spetta quindi a Team B (P3)!
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      expect(provider.currentServerPlayerId, equals(3));
    });

    // 8. Vantaggi tradizionali
    test('8. Vantaggi tradizionali (40-40, Vantaggio, Parità, Vittoria)', () {
      final provider = createTestProvider(goldenPoint: false);

      // Arriva a 40-40
      for (int i = 0; i < 3; i++) {
        provider.addPoint(Team.teamA);
      }
      for (int i = 0; i < 3; i++) {
        provider.addPoint(Team.teamB);
      }
      expect(provider.snapshot.isDeuce, isTrue);
      expect(provider.snapshot.displayPointA, equals('40'));
      expect(provider.snapshot.displayPointB, equals('40'));

      // Vantaggio A
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('AV'));
      expect(provider.snapshot.displayPointB, equals('40'));

      // Ritorno a 40-40
      provider.addPoint(Team.teamB);
      expect(provider.snapshot.displayPointA, equals('40'));
      expect(provider.snapshot.displayPointB, equals('40'));
      expect(provider.snapshot.deuceCount, equals(1));

      // Due punti consecutivi per vincere
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('AV'));
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.currentGamesA, equals(1));
    });

    // 9. Punto d'oro
    test('9. Punto d\'oro immediato al primo 40-40', () {
      final provider = createTestProvider(goldenPoint: true, advantagesBeforeGoldenPoint: 0);

      for (int i = 0; i < 3; i++) {

        provider.addPoint(Team.teamA);

      }
      for (int i = 0; i < 3; i++) {
        provider.addPoint(Team.teamB);
      }
      expect(provider.snapshot.isDeuce, isTrue);
      expect(provider.snapshot.isGoldenPointSituation(true, 0), isTrue);

      // Punto decisivo vince subito il game
      provider.addPoint(Team.teamB);
      expect(provider.snapshot.currentGamesB, equals(1));
    });

    // 10. Star Point FIP 2026
    test('10. Star Point FIP 2026 (2 vantaggi poi punto d\'oro al 3° deuce)', () {
      final provider = createTestProvider(goldenPoint: true, advantagesBeforeGoldenPoint: 2);

      // 1° Deuce (deuceCount = 0)
      for (int i = 0; i < 3; i++) {
        provider.addPoint(Team.teamA);
      }
      for (int i = 0; i < 3; i++) {
        provider.addPoint(Team.teamB);
      }
      expect(provider.snapshot.deuceCount, equals(0));

      // 1° Vantaggio A poi contro-punto B -> 2° Deuce (deuceCount = 1)
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('AV'));
      provider.addPoint(Team.teamB);
      expect(provider.snapshot.deuceCount, equals(1));

      // 2° Vantaggio B poi contro-punto A -> 3° Deuce (deuceCount = 2, Star Point attivo!)
      provider.addPoint(Team.teamB);
      expect(provider.snapshot.displayPointB, equals('AV'));
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.deuceCount, equals(2));
      expect(provider.snapshot.isGoldenPointSituation(true, 2), isTrue);

      // Sul 3° deuce, il punto vince immediatamente il game
      provider.addPoint(Team.teamA);
      expect(provider.snapshot.currentGamesA, equals(1));
    });

    // 11. Undo dopo punto, game e set
    test('11. Undo dopo punto, game e set', () {
      final provider = createTestProvider();

      provider.addPoint(Team.teamA);
      expect(provider.snapshot.displayPointA, equals('15'));
      provider.undo();
      expect(provider.snapshot.displayPointA, equals('0'));

      // Vinci un game
      for (int i = 0; i < 4; i++) {
        provider.addPoint(Team.teamA);
      }
      expect(provider.snapshot.currentGamesA, equals(1));
      expect(provider.currentServerPlayerId, equals(3));

      // Undo del game vinto ripristina 40-0 del game 1 con battitore 1
      provider.undo();
      expect(provider.snapshot.currentGamesA, equals(0));
      expect(provider.snapshot.displayPointA, equals('40'));
      expect(provider.currentServerPlayerId, equals(1));
    });

    // 12. Reset e nuova partita
    test('12. Reset preserva firstServerPlayerId e azzera cronologia', () {
      final provider = createTestProvider(firstServerPlayerId: 3);
      provider.addPoint(Team.teamA);
      provider.addPoint(Team.teamB);
      expect(provider.canUndo, isTrue);

      provider.resetMatch();
      expect(provider.canUndo, isFalse);
      expect(provider.snapshot.rawPointsA, equals(0));
      expect(provider.snapshot.rawPointsB, equals(0));
      expect(provider.snapshot.currentGamesA, equals(0));
      expect(provider.snapshot.servingTeam, equals(Team.teamB));
      expect(provider.currentServerPlayerId, equals(3));
    });

    // 13. Cambio campo senza alterare il punteggio
    test('13. Cambio campo inverte esclusivamente isSidesSwapped', () {
      final provider = createTestProvider();
      provider.addPoint(Team.teamA);
      provider.addPoint(Team.teamA);
      provider.addPoint(Team.teamB);

      expect(provider.isSidesSwapped, isFalse);
      expect(provider.snapshot.rawPointsA, equals(2)); // 30
      expect(provider.snapshot.rawPointsB, equals(1)); // 15
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
      expect(provider.currentServerPlayerId, equals(1));

      // Esegui cambio campo
      provider.switchSides();

      expect(provider.isSidesSwapped, isTrue);
      // Punti, battitore e squadra rimangono INVARIATI
      expect(provider.snapshot.rawPointsA, equals(2));
      expect(provider.snapshot.rawPointsB, equals(1));
      expect(provider.snapshot.servingTeam, equals(Team.teamA));
      expect(provider.currentServerPlayerId, equals(1));

      // Secondo cambio campo torna normale
      provider.switchSides();
      expect(provider.isSidesSwapped, isFalse);
    });

    // 14. Blocco dei punti dopo vittoria
    test('14. Blocco dei punti dopo vittoria del match', () {
      final provider = createTestProvider(bestOfSets: 1);

      // Vinci 6 game per Team A -> Vittoria match
      for (int g = 0; g < 6; g++) {
        for (int p = 0; p < 4; p++) {
          provider.addPoint(Team.teamA);
        }
      }

      expect(provider.isMatchOver, isTrue);
      expect(provider.snapshot.matchWinner, equals(Team.teamA));
      final histLen = provider.snapshot.completedSets.length;

      // Tentativo di aggiungere ulteriori punti
      provider.addPoint(Team.teamA);
      provider.addPoint(Team.teamB);

      // Nessun cambiamento
      expect(provider.snapshot.completedSets.length, equals(histLen));
      expect(provider.snapshot.currentGamesA, equals(0));
      expect(provider.snapshot.currentGamesB, equals(0));
      expect(provider.snapshot.matchWinner, equals(Team.teamA));
    });
  });
}
