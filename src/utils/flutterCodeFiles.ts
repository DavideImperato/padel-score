export interface FlutterFileItem {
  path: string;
  filename: string;
  description: string;
  language: string;
  content: string;
}

export const FLUTTER_CODE_FILES: FlutterFileItem[] = [
  {
    path: 'pubspec.yaml',
    filename: 'pubspec.yaml',
    description: 'Dipendenze (flutter_tts, provider, shared_preferences, wakelock_plus)',
    language: 'yaml',
    content: `name: padel_scorebot
description: "Tabellone segnapunti Padel 100% offline stile ScoreBot con supporto telecomando Bluetooth, TTS in italiano e Wakelock."
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_tts: ^4.2.2
  provider: ^6.1.2
  shared_preferences: ^2.5.2
  wakelock_plus: ^1.2.8
  volume_controller: ^2.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  image_path: "assets/icon.png"
  ios: true
  android: true

flutter:
  uses-material-design: true
  assets:
    - assets/icon.png
`
  },
  {
    path: 'lib/screens/match_setup_screen.dart',
    filename: 'match_setup_screen.dart',
    description: 'Schermata Iniziale Setup Match: nomi squadre, 4 giocatori, selettore 1° servizio e rotazione a 4',
    language: 'dart',
    content: `import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/padel_score_provider.dart';
import 'landscape_scoreboard_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _team1Controller;
  late TextEditingController _team2Controller;
  late TextEditingController _player1Controller;
  late TextEditingController _player2Controller;
  late TextEditingController _player3Controller;
  late TextEditingController _player4Controller;

  int _selectedFirstServerId = 1; // 1, 2, 3 o 4
  // 0 = vantaggi tradizionali, 1 = punto d'oro, 2 = Star Point.
  int _scoringMode = 1;
  int _bestOfSets = 3;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PadelScoreProvider>();
    _team1Controller = TextEditingController(text: provider.teamAName);
    _team2Controller = TextEditingController(text: provider.teamBName);
    _player1Controller = TextEditingController(text: provider.player1Name);
    _player2Controller = TextEditingController(text: provider.player2Name);
    _player3Controller = TextEditingController(text: provider.player3Name);
    _player4Controller = TextEditingController(text: provider.player4Name);
    _selectedFirstServerId = provider.firstServerPlayerId;
    _scoringMode = !provider.isGoldenPoint
        ? 0
        : (provider.advantagesBeforeGoldenPoint >= 2 ? 2 : 1);
    _bestOfSets = provider.bestOfSets;
  }

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _player1Controller.dispose();
    _player2Controller.dispose();
    _player3Controller.dispose();
    _player4Controller.dispose();
    super.dispose();
  }

  void _startMatch() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.heavyImpact();

    final provider = context.read<PadelScoreProvider>();
    provider.setupMatch(
      team1: _team1Controller.text,
      team2: _team2Controller.text,
      player1: _player1Controller.text,
      player2: _player2Controller.text,
      player3: _player3Controller.text,
      player4: _player4Controller.text,
      firstServerPlayerId: _selectedFirstServerId,
      goldenPoint: _scoringMode != 0,
      advantagesBeforeGoldenPoint: _scoringMode == 2 ? 2 : 0,
      bestOfSets: _bestOfSets,
    );

    // Naviga al tabellone orizzontale
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LandscapeScoreboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFF00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_tennis, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'PADEL SCOREBOT — SETUP PARTITA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sezione 1: Coppie e Giocatori (2 Card affiancate o stacked)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SQUADRA 1 (Sinistra - Verde Fluo)
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 1,
                            accentColor: const Color(0xFFCCFF00),
                            teamController: _team1Controller,
                            playerAController: _player1Controller,
                            playerBController: _player2Controller,
                            playerALabel: 'Giocatore 1',
                            playerBLabel: 'Giocatore 2',
                            playerAId: 1,
                            playerBId: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // SQUADRA 2 (Destra - Ciano Elettrico)
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 2,
                            accentColor: const Color(0xFF00E5FF),
                            teamController: _team2Controller,
                            playerAController: _player3Controller,
                            playerBController: _player4Controller,
                            playerALabel: 'Giocatore 3',
                            playerBLabel: 'Giocatore 4',
                            playerAId: 3,
                            playerBId: 4,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Sezione 2: Primo Servizio e Rotazione Ufficiale
                    _buildServingRotationCard(),

                    const SizedBox(height: 24),

                    // Sezione 3: Regolamento (Punto d'Oro e Set)
                    _buildRulesCard(),

                    const SizedBox(height: 32),

                    // GROSSO PULSANTE CENTRALE "INIZIA PARTITA"
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFFCCFF00).withValues(alpha: 0.5),
                      ),
                      onPressed: _startMatch,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill, size: 28, color: Colors.black),
                          SizedBox(width: 10),
                          Text(
                            'INIZIA PARTITA',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard({
    required int teamNumber,
    required Color accentColor,
    required TextEditingController teamController,
    required TextEditingController playerAController,
    required TextEditingController playerBController,
    required String playerALabel,
    required String playerBLabel,
    required int playerAId,
    required int playerBId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'SQUADRA $teamNumber',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nome Squadra
          TextFormField(
            controller: teamController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Nome Squadra $teamNumber',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome squadra' : null,
          ),
          const SizedBox(height: 12),

          // Giocatore A
          TextFormField(
            controller: playerAController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerALabel,
              prefixIcon: const Icon(Icons.person, color: Color(0xFF64748B), size: 18),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome giocatore' : null,
          ),
          const SizedBox(height: 10),

          // Giocatore B
          TextFormField(
            controller: playerBController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerBLabel,
              prefixIcon: const Icon(Icons.person, color: Color(0xFF64748B), size: 18),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome compagno' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildServingRotationCard() {
    final p1 = _player1Controller.text.trim().isEmpty ? 'Giocatore 1' : _player1Controller.text;
    final p2 = _player2Controller.text.trim().isEmpty ? 'Giocatore 2' : _player2Controller.text;
    final p3 = _player3Controller.text.trim().isEmpty ? 'Giocatore 3' : _player3Controller.text;
    final p4 = _player4Controller.text.trim().isEmpty ? 'Giocatore 4' : _player4Controller.text;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_tennis, color: Color(0xFFCCFF00), size: 20),
              SizedBox(width: 8),
              Text(
                'CHI SERVE PER PRIMO? (ROTAZIONE A 4 GIOCATORI)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Seleziona il giocatore che apre il servizio. L\\'app gestirà rigorosamente la rotazione ufficiale del Padel ad ogni game.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Selettore Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF475569)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedFirstServerId,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCCFF00)),
                items: [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1° Servizio: $p1 (Squadra 1)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('1° Servizio: $p2 (Squadra 1)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('1° Servizio: $p3 (Squadra 2)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('1° Servizio: $p4 (Squadra 2)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFirstServerId = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Visualizzatore Ordine Ufficiale Turni
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_alt, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getRotationPreviewText(p1, p2, p3, p4),
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRotationPreviewText(String p1, String p2, String p3, String p4) {
    if (_selectedFirstServerId == 1) {
      return 'Sequenza Game: Turno 1: $p1 ➔ Turno 2: $p3 ➔ Turno 3: $p2 ➔ Turno 4: $p4 (poi ciclico).';
    } else if (_selectedFirstServerId == 2) {
      return 'Sequenza Game: Turno 1: $p2 ➔ Turno 2: $p3 ➔ Turno 3: $p1 ➔ Turno 4: $p4 (poi ciclico).';
    } else if (_selectedFirstServerId == 3) {
      return 'Sequenza Game: Turno 1: $p3 ➔ Turno 2: $p1 ➔ Turno 3: $p4 ➔ Turno 4: $p2 (poi ciclico).';
    } else {
      return 'Sequenza Game: Turno 1: $p4 ➔ Turno 2: $p1 ➔ Turno 3: $p3 ➔ Turno 4: $p2 (poi ciclico).';
    }
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sistema di punteggio',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _scoringChoiceChip(0, 'Vantaggi tradizionali'),
              _scoringChoiceChip(1, 'Punto d\\'Oro'),
              _scoringChoiceChip(2, 'Star Point FIP 2026'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _scoringMode == 0
                ? 'Sul 40-40 si continua con vantaggio e parità, fino a due punti consecutivi.'
                : _scoringMode == 1
                    ? 'Sul primo 40-40 il punto successivo decide il game.'
                    : 'Dopo due cicli di vantaggio e ritorno alla parità, il punto successivo decide il game.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const Divider(color: Color(0xFF1E293B)),
          // Formato Set
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Formato Partita:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                children: [
                  _setChoiceChip(1, '1 Set'),
                  const SizedBox(width: 8),
                  _setChoiceChip(3, '3 Set (Consigliato)'),
                  const SizedBox(width: 8),
                  _setChoiceChip(5, '5 Set'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoringChoiceChip(int mode, String label) {
    final selected = _scoringMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFCCFF00),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontWeight: selected ? FontWeight.w900 : FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _scoringMode = mode),
    );
  }

  Widget _setChoiceChip(int count, String label) {
    final isSelected = _bestOfSets == count;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFCCFF00),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _bestOfSets = count),
    );
  }
}
`
  },
  {
    path: 'lib/models/padel_match_state.dart',
    filename: 'padel_match_state.dart',
    description: 'Modello immutabile con PlayerId (1..4), FIP 2026 rotation e deuceCount per Star Point',
    language: 'dart',
    content: `import 'package:flutter/foundation.dart';

enum Team {
  teamA,
  teamB;

  Team get opposite => this == Team.teamA ? Team.teamB : Team.teamA;
}

typedef PlayerId = int; // 1, 2, 3, o 4

/// Associa stabilmente l'ID giocatore alla squadra di appartenenza (Regolamento FIP).
/// Giocatore 1 e 2 -> Squadra A
/// Giocatore 3 e 4 -> Squadra B
Team getTeamForPlayerId(int playerId) {
  return (playerId == 1 || playerId == 2) ? Team.teamA : Team.teamB;
}

/// Restituisce la sequenza ciclica di rotazione dei 4 battitori (ID stabili)
/// in base al primo battitore scelto (identica al motore TypeScript).
List<int> getRotationOrder(int firstServerPlayerId) {
  switch (firstServerPlayerId) {
    case 1:
      return const [1, 3, 2, 4];
    case 2:
      return const [2, 3, 1, 4];
    case 3:
      return const [3, 1, 4, 2];
    case 4:
      return const [4, 1, 3, 2];
    default:
      return const [1, 3, 2, 4];
  }
}

/// Determina l'ID del giocatore attualmente al servizio.
/// Nel Tie-break la sequenza è 1-2-2-2...
/// Nei game ordinari è ciclica sulla rotazione dei 4 battitori.
int getCurrentServerPlayerId(PadelMatchSnapshot snapshot, int firstServerPlayerId) {
  final rotation = getRotationOrder(firstServerPlayerId);
  if (snapshot.isTieBreak) {
    final int initialIdx =
        snapshot.tieBreakInitialRotationIndex ?? snapshot.servingRotationIndex;
    final int totalPoints = snapshot.tieBreakPointsA + snapshot.tieBreakPointsB;
    final int shift = totalPoints == 0 ? 0 : ((totalPoints + 1) ~/ 2);
    return rotation[(initialIdx + shift) % rotation.length];
  }
  return rotation[snapshot.servingRotationIndex % rotation.length];
}

/// Determina la squadra al servizio direttamente dall'ID del battitore attivo.
Team getCurrentServingTeam(PadelMatchSnapshot snapshot, int firstServerPlayerId) {
  final playerId = getCurrentServerPlayerId(snapshot, firstServerPlayerId);
  return getTeamForPlayerId(playerId);
}

/// Rappresenta il punteggio di un singolo set completato o in corso
@immutable
class SetScore {
  final int gamesA;
  final int gamesB;
  final int? tieBreakPointsA;
  final int? tieBreakPointsB;
  final bool isCompleted;
  final Team? winner;

  const SetScore({
    required this.gamesA,
    required this.gamesB,
    this.tieBreakPointsA,
    this.tieBreakPointsB,
    this.isCompleted = false,
    this.winner,
  });

  SetScore copyWith({
    int? gamesA,
    int? gamesB,
    int? tieBreakPointsA,
    int? tieBreakPointsB,
    bool? isCompleted,
    Team? winner,
  }) {
    return SetScore(
      gamesA: gamesA ?? this.gamesA,
      gamesB: gamesB ?? this.gamesB,
      tieBreakPointsA: tieBreakPointsA ?? this.tieBreakPointsA,
      tieBreakPointsB: tieBreakPointsB ?? this.tieBreakPointsB,
      isCompleted: isCompleted ?? this.isCompleted,
      winner: winner ?? this.winner,
    );
  }

  @override
  String toString() {
    if (tieBreakPointsA != null && tieBreakPointsB != null) {
      return '$gamesA-$gamesB ($tieBreakPointsA-$tieBreakPointsB)';
    }
    return '$gamesA-$gamesB';
  }
}

/// Snapshot immutabile dello stato della partita, fondamentale per il sistema Undo
@immutable
class PadelMatchSnapshot {
  // Differenzia un campo omesso da un null passato esplicitamente a copyWith.
  static const Object _notProvided = Object();
  /// Punti del game corrente: 0 -> 0, 1 -> 15, 2 -> 30, 3 -> 40, 4 -> Vantaggio (AV)
  final int rawPointsA;
  final int rawPointsB;

  /// Conteggio ritorni a 40-40 nel game corrente (per Star Point FIP 2026)
  final int deuceCount;

  /// Game vinti nel set corrente
  final int currentGamesA;
  final int currentGamesB;

  /// Lista dei set completati finora
  final List<SetScore> completedSets;

  /// Squadra attualmente al servizio
  final Team servingTeam;

  /// Indice nella rotazione ciclica dei 4 battitori (0..3 cumulativo)
  final int servingRotationIndex;

  /// Chi ha iniziato a servire nel set corrente
  final Team initialSetServer;

  /// Flag se siamo in Tie-Break
  final bool isTieBreak;

  /// Punti numerici del Tie-Break
  final int tieBreakPointsA;
  final int tieBreakPointsB;

  /// Indice di rotazione battitore all'inizio del Tie-Break
  final int? tieBreakInitialRotationIndex;

  /// Vincitore della partita (null se in corso)
  final Team? matchWinner;

  /// Messaggio descrittivo dell'ultimo evento
  final String lastEventMessage;

  const PadelMatchSnapshot({
    required this.rawPointsA,
    required this.rawPointsB,
    this.deuceCount = 0,
    required this.currentGamesA,
    required this.currentGamesB,
    required this.completedSets,
    required this.servingTeam,
    required this.servingRotationIndex,
    required this.initialSetServer,
    required this.isTieBreak,
    required this.tieBreakPointsA,
    required this.tieBreakPointsB,
    this.tieBreakInitialRotationIndex,
    this.matchWinner,
    this.lastEventMessage = '',
  });

  /// Crea lo snapshot iniziale di una nuova partita
  factory PadelMatchSnapshot.initial({
    Team initialServer = Team.teamA,
    int initialRotationIndex = 0,
  }) {
    return PadelMatchSnapshot(
      rawPointsA: 0,
      rawPointsB: 0,
      deuceCount: 0,
      currentGamesA: 0,
      currentGamesB: 0,
      completedSets: const [],
      servingTeam: initialServer,
      servingRotationIndex: initialRotationIndex,
      initialSetServer: initialServer,
      isTieBreak: false,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: null,
      matchWinner: null,
      lastEventMessage: 'Inizio Partita',
    );
  }

  /// Stringa visuale del punteggio game (es. '0', '15', '30', '40', 'AV')
  String get displayPointA {
    if (isTieBreak) return tieBreakPointsA.toString();
    return _formatStandardPoint(rawPointsA);
  }

  String get displayPointB {
    if (isTieBreak) return tieBreakPointsB.toString();
    return _formatStandardPoint(rawPointsB);
  }

  static String _formatStandardPoint(int point) {
    switch (point) {
      case 0:
        return '0';
      case 1:
        return '15';
      case 2:
        return '30';
      case 3:
        return '40';
      case 4:
        return 'AV';
      default:
        return '0';
    }
  }

  /// Verifica se è punto d'oro (40-40 con regola Punto d'Oro o Star Point)
  bool isGoldenPointSituation(bool goldenPointEnabled, [int advantagesBeforeGoldenPoint = 0]) {
    if (isTieBreak) return false;
    return goldenPointEnabled &&
        rawPointsA == 3 &&
        rawPointsB == 3 &&
        deuceCount >= advantagesBeforeGoldenPoint;
  }

  /// Verifica parità 40-40 (Deuce)
  bool get isDeuce => !isTieBreak && rawPointsA == 3 && rawPointsB == 3;

  /// Copia con override dei campi
  PadelMatchSnapshot copyWith({
    int? rawPointsA,
    int? rawPointsB,
    int? deuceCount,
    int? currentGamesA,
    int? currentGamesB,
    List<SetScore>? completedSets,
    Team? servingTeam,
    int? servingRotationIndex,
    Team? initialSetServer,
    bool? isTieBreak,
    int? tieBreakPointsA,
    int? tieBreakPointsB,
    Object? tieBreakInitialRotationIndex = _notProvided,
    Object? matchWinner = _notProvided,
    String? lastEventMessage,
  }) {
    return PadelMatchSnapshot(
      rawPointsA: rawPointsA ?? this.rawPointsA,
      rawPointsB: rawPointsB ?? this.rawPointsB,
      deuceCount: deuceCount ?? this.deuceCount,
      currentGamesA: currentGamesA ?? this.currentGamesA,
      currentGamesB: currentGamesB ?? this.currentGamesB,
      completedSets: completedSets ?? List.unmodifiable(this.completedSets),
      servingTeam: servingTeam ?? this.servingTeam,
      servingRotationIndex: servingRotationIndex ?? this.servingRotationIndex,
      initialSetServer: initialSetServer ?? this.initialSetServer,
      isTieBreak: isTieBreak ?? this.isTieBreak,
      tieBreakPointsA: tieBreakPointsA ?? this.tieBreakPointsA,
      tieBreakPointsB: tieBreakPointsB ?? this.tieBreakPointsB,
      tieBreakInitialRotationIndex: identical(tieBreakInitialRotationIndex, _notProvided)
          ? this.tieBreakInitialRotationIndex
          : tieBreakInitialRotationIndex as int?,
      matchWinner: identical(matchWinner, _notProvided)
          ? this.matchWinner
          : matchWinner as Team?,
      lastEventMessage: lastEventMessage ?? this.lastEventMessage,
    );
  }
}
`
  },
  {
    path: 'lib/providers/padel_score_provider.dart',
    filename: 'padel_score_provider.dart',
    description: 'Rotazione ufficiale FIP 2026, ID stabili 1..4, Star Point e visual switchSides',
    language: 'dart',
    content: `import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/padel_match_state.dart';
import '../services/tts_service.dart';

class PadelScoreProvider extends ChangeNotifier {
  final TtsService _ttsService;

  // Snapshot corrente e cronologia per Undo
  PadelMatchSnapshot _currentSnapshot = PadelMatchSnapshot.initial();
  final List<PadelMatchSnapshot> _history = [];

  // Squadre e 4 Giocatori
  String _teamAName = 'Gli Smashtori';
  String _teamBName = 'I Timemasters';

  String _player1Name = 'Mario Rossi';
  String _player2Name = 'Luigi Verdi';
  String _player3Name = 'Paolo Bianchi';
  String _player4Name = 'Marco Neri';

  // Identificativo del primo battitore (1, 2, 3 o 4)
  int _firstServerPlayerId = 1;

  // Impostazioni regolamento
  bool _isGoldenPoint = true;
  int _advantagesBeforeGoldenPoint = 0; // 0 = subito punto d'oro, 1 = 1 vantaggio poi punto d'oro, 2 = Star Point FIP 2026
  int _bestOfSets = 3;

  // Evita che il caricamento asincrono delle preferenze sostituisca
  // le impostazioni o lo snapshot dopo una nuova partita.
  int _configurationVersion = 0;

  // Stato UI visivo indipendente per cambio campo (inversione lati senza alterare dati sportivi)
  bool _isSidesSwapped = false;

  PadelScoreProvider({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _loadPreferences();
  }

  // Getters
  PadelMatchSnapshot get snapshot => _currentSnapshot;
  String get teamAName => _teamAName;
  String get teamBName => _teamBName;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  String get player3Name => _player3Name;
  String get player4Name => _player4Name;
  int get firstServerPlayerId => _firstServerPlayerId;
  bool get isGoldenPoint => _isGoldenPoint;
  int get advantagesBeforeGoldenPoint => _advantagesBeforeGoldenPoint;
  int get bestOfSets => _bestOfSets;
  bool get canUndo => _history.isNotEmpty;
  bool get isMuted => _ttsService.isMuted;
  bool get isMatchOver => _currentSnapshot.matchWinner != null;
  bool get isSidesSwapped => _isSidesSwapped;

  String getTeamName(Team team) => team == Team.teamA ? _teamAName : _teamBName;

  /// Restituisce l'ID del giocatore attualmente al servizio
  int get currentServerPlayerId {
    return getCurrentServerPlayerId(_currentSnapshot, _firstServerPlayerId);
  }

  /// Restituisce il nome visualizzato del battitore in base al suo ID stabile (1..4)
  String getPlayerNameById(int playerId) {
    switch (playerId) {
      case 1:
        return _player1Name.trim().isEmpty ? 'Giocatore 1' : _player1Name.trim();
      case 2:
        return _player2Name.trim().isEmpty ? 'Giocatore 2' : _player2Name.trim();
      case 3:
        return _player3Name.trim().isEmpty ? 'Giocatore 3' : _player3Name.trim();
      case 4:
        return _player4Name.trim().isEmpty ? 'Giocatore 4' : _player4Name.trim();
      default:
        return 'Giocatore $playerId';
    }
  }

  /// Restituisce il nome del giocatore attualmente al servizio
  String get currentServingPlayerName {
    return getPlayerNameById(currentServerPlayerId);
  }

  /// Setup completo del match dalla schermata iniziale
  void setupMatch({
    required String team1,
    required String team2,
    required String player1,
    required String player2,
    required String player3,
    required String player4,
    required int firstServerPlayerId, // 1, 2, 3 o 4
    required bool goldenPoint,
    int advantagesBeforeGoldenPoint = 0,
    required int bestOfSets,
  }) {
    _configurationVersion++;
    _teamAName = team1.trim().isEmpty ? 'Squadra 1' : team1.trim();
    _teamBName = team2.trim().isEmpty ? 'Squadra 2' : team2.trim();
    _player1Name = player1.trim().isEmpty ? 'Giocatore 1' : player1.trim();
    _player2Name = player2.trim().isEmpty ? 'Giocatore 2' : player2.trim();
    _player3Name = player3.trim().isEmpty ? 'Giocatore 3' : player3.trim();
    _player4Name = player4.trim().isEmpty ? 'Giocatore 4' : player4.trim();
    _firstServerPlayerId = (firstServerPlayerId >= 1 && firstServerPlayerId <= 4)
        ? firstServerPlayerId
        : 1;
    _isGoldenPoint = goldenPoint;
    _advantagesBeforeGoldenPoint = advantagesBeforeGoldenPoint;
    _bestOfSets = bestOfSets;
    _isSidesSwapped = false;

    final Team initialTeam = getTeamForPlayerId(_firstServerPlayerId);

    _history.clear();
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: initialTeam,
      initialRotationIndex: 0,
    );

    _savePreferences();
    notifyListeners();

    // Annuncio arbitrale di inizio match
    _ttsService.speak(
      'Inizio partita. $_teamAName contro $_teamBName. Serve $currentServingPlayerName.',
    );
  }

  Future<void> _loadPreferences() async {
    final versionAtStart = _configurationVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (versionAtStart != _configurationVersion) return;
      _isGoldenPoint = prefs.getBool('isGoldenPoint') ?? true;
      _advantagesBeforeGoldenPoint = prefs.getInt('advantagesBeforeGoldenPoint') ?? 0;
      _teamAName = prefs.getString('teamAName') ?? 'Gli Smashtori';
      _teamBName = prefs.getString('teamBName') ?? 'I Timemasters';
      _player1Name = prefs.getString('player1Name') ?? 'Mario Rossi';
      _player2Name = prefs.getString('player2Name') ?? 'Luigi Verdi';
      _player3Name = prefs.getString('player3Name') ?? 'Paolo Bianchi';
      _player4Name = prefs.getString('player4Name') ?? 'Marco Neri';
      _firstServerPlayerId = prefs.getInt('firstServerPlayerId') ?? 1;

      final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
      _currentSnapshot = PadelMatchSnapshot.initial(
        initialServer: initialTeam,
        initialRotationIndex: 0,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGoldenPoint', _isGoldenPoint);
      await prefs.setInt('advantagesBeforeGoldenPoint', _advantagesBeforeGoldenPoint);
      await prefs.setString('teamAName', _teamAName);
      await prefs.setString('teamBName', _teamBName);
      await prefs.setString('player1Name', _player1Name);
      await prefs.setString('player2Name', _player2Name);
      await prefs.setString('player3Name', _player3Name);
      await prefs.setString('player4Name', _player4Name);
      await prefs.setInt('firstServerPlayerId', _firstServerPlayerId);
    } catch (_) {}
  }

  // ===========================================================================
  // LOGICA DI PUNTEGGIO PADEL (ALLINEATA AL REGOLAMENTO FIP 2026 E AL MOTORE REACT)
  // ===========================================================================

  void addPoint(Team scoringTeam) {
    if (isMatchOver) return;
    _configurationVersion++;

    _history.add(_currentSnapshot);

    if (_currentSnapshot.isTieBreak) {
      _processTieBreakPoint(scoringTeam);
      return;
    }
    _processStandardPoint(scoringTeam);
  }

  void _processStandardPoint(Team scoringTeam) {
    int pA = _currentSnapshot.rawPointsA;
    int pB = _currentSnapshot.rawPointsB;
    int deuceCount = _currentSnapshot.deuceCount;

    // Situazione Punto d'Oro o Star Point
    final bool isGoldenPointNow = _isGoldenPoint &&
        pA == 3 &&
        pB == 3 &&
        deuceCount >= _advantagesBeforeGoldenPoint;

    if (scoringTeam == Team.teamA) {
      if (pA < 3) {
        pA++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      } else if (pA == 3 && pB < 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 3) {
        if (isGoldenPointNow) {
          _winGame(Team.teamA);
        } else {
          pA = 4; // Vantaggio Squadra A
          _commitPointChange(pA, pB, deuceCount, scoringTeam);
        }
      } else if (pA == 4 && pB == 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 4) {
        pB = 3; // Ritorno a 40 pari
        deuceCount++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      }
    } else {
      if (pB < 3) {
        pB++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      } else if (pB == 3 && pA < 3) {
        _winGame(Team.teamB);
      } else if (pA == 3 && pB == 3) {
        if (isGoldenPointNow) {
          _winGame(Team.teamB);
        } else {
          pB = 4; // Vantaggio Squadra B
          _commitPointChange(pA, pB, deuceCount, scoringTeam);
        }
      } else if (pB == 4 && pA == 3) {
        _winGame(Team.teamB);
      } else if (pB == 3 && pA == 4) {
        pA = 3; // Ritorno a 40 pari
        deuceCount++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      }
    }
  }

  void _commitPointChange(int newPA, int newPB, int newDeuceCount, Team scorer) {
    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: newPA,
      rawPointsB: newPB,
      deuceCount: newDeuceCount,
      lastEventMessage: 'Punto \${getTeamName(scorer)}',
    );
    notifyListeners();
    _announceRefereePointScore();
  }

  void _winGame(Team winner) {
    int gA = _currentSnapshot.currentGamesA;
    int gB = _currentSnapshot.currentGamesB;

    if (winner == Team.teamA) {
      gA++;
    } else {
      gB++;
    }

    final rotation = getRotationOrder(_firstServerPlayerId);
    final int nextRotationIndex = _currentSnapshot.servingRotationIndex + 1;
    final int nextServerId = rotation[nextRotationIndex % rotation.length];
    final Team nextServerTeam = getTeamForPlayerId(nextServerId);

    // Sul 6-6 scatta il Tie-Break
    if (gA == 6 && gB == 6) {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        deuceCount: 0,
        currentGamesA: 6,
        currentGamesB: 6,
        isTieBreak: true,
        tieBreakPointsA: 0,
        tieBreakPointsB: 0,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        tieBreakInitialRotationIndex: nextRotationIndex,
        lastEventMessage: 'Tie-break!',
      );
      notifyListeners();
      _ttsService.speak('Sei pari. Tie-break. Serve $currentServingPlayerName.');
      return;
    }

    // Controllo vittoria set (6 con 2 di margine, oppure 7-5)
    final bool setWonA = (gA >= 6 && (gA - gB) >= 2);
    final bool setWonB = (gB >= 6 && (gB - gA) >= 2);

    if (setWonA || setWonB) {
      _winSet(setWonA ? Team.teamA : Team.teamB, gA, gB, null, null);
    } else {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        deuceCount: 0,
        currentGamesA: gA,
        currentGamesB: gB,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        lastEventMessage: 'Game \${getTeamName(winner)}',
      );
      notifyListeners();

      _ttsService.speak(
        'Game per la squadra \${getTeamName(winner)}. $gA a $gB. Serve $currentServingPlayerName.',
      );
    }
  }

  void _processTieBreakPoint(Team scoringTeam) {
    int tbA = _currentSnapshot.tieBreakPointsA;
    int tbB = _currentSnapshot.tieBreakPointsB;

    if (scoringTeam == Team.teamA) {
      tbA++;
    } else {
      tbB++;
    }

    final int totalPoints = tbA + tbB;

    // Controllo vittoria tie-break: 7 punti con 2 di scarto
    final bool tbWonA = (tbA >= 7 && (tbA - tbB) >= 2);
    final bool tbWonB = (tbB >= 7 && (tbB - tbA) >= 2);

    if (tbWonA || tbWonB) {
      final Team setWinner = tbWonA ? Team.teamA : Team.teamB;
      _winSet(setWinner, tbWonA ? 7 : 6, tbWonB ? 7 : 6, tbA, tbB);
    } else {
      // Rotazione battitore durante tiebreak con sequenza 1-2-2-2...
      final rotation = getRotationOrder(_firstServerPlayerId);
      final int initialIdx =
          _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      final int shift = ((totalPoints + 1) ~/ 2);
      final int nextPlayerId = rotation[(initialIdx + shift) % rotation.length];
      final Team nextTeam = getTeamForPlayerId(nextPlayerId);

      _currentSnapshot = _currentSnapshot.copyWith(
        tieBreakPointsA: tbA,
        tieBreakPointsB: tbB,
        servingTeam: nextTeam,
        lastEventMessage: 'Tie-break $tbA - $tbB',
      );
      notifyListeners();
      _ttsService.speak('$tbA a $tbB. Serve $currentServingPlayerName.');
    }
  }

  void _winSet(Team setWinner, int gA, int gB, int? tbA, int? tbB) {
    final completedSet = SetScore(
      gamesA: gA,
      gamesB: gB,
      tieBreakPointsA: tbA,
      tieBreakPointsB: tbB,
      isCompleted: true,
      winner: setWinner,
    );

    final updatedSets = List<SetScore>.from(_currentSnapshot.completedSets)..add(completedSet);
    final setNumber = updatedSets.length;
    final int setsWonA = updatedSets.where((s) => s.winner == Team.teamA).length;
    final int setsWonB = updatedSets.where((s) => s.winner == Team.teamB).length;
    final int setsToWin = (_bestOfSets / 2).ceil();

    Team? matchWinner;
    if (setsWonA >= setsToWin) matchWinner = Team.teamA;
    if (setsWonB >= setsToWin) matchWinner = Team.teamB;

    final rotation = getRotationOrder(_firstServerPlayerId);
    int nextRotIndex;

    if (_currentSnapshot.isTieBreak) {
      // Regola Ufficiale FIP Tie-Break:
      // La coppia che ha iniziato a servire nel tie-break riceverà nel primo game del set successivo.
      // Il servizio del primo game del nuovo set tocca alla squadra opposta che segue nella rotazione.
      final int tbStartRot =
          _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      nextRotIndex = tbStartRot + 1;
    } else {
      // Regola Ufficiale FIP Set standard:
      // Continua la naturale alternanza di servizio in base ai game totali giocati.
      nextRotIndex = _currentSnapshot.servingRotationIndex + 1;
    }

    final int nextServerPlayerId = rotation[nextRotIndex % rotation.length];
    final Team nextSetServerTeam = getTeamForPlayerId(nextServerPlayerId);

    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: 0,
      rawPointsB: 0,
      deuceCount: 0,
      currentGamesA: 0,
      currentGamesB: 0,
      completedSets: updatedSets,
      servingTeam: nextSetServerTeam,
      servingRotationIndex: nextRotIndex,
      initialSetServer: nextSetServerTeam,
      isTieBreak: false,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: null,
      matchWinner: matchWinner,
      lastEventMessage: matchWinner != null
          ? 'Partita vinta da \${getTeamName(matchWinner)}!'
          : 'Set vinto da \${getTeamName(setWinner)}',
    );
    notifyListeners();

    final String setOrdinal = setNumber == 1 ? 'primo' : (setNumber == 2 ? 'secondo' : (setNumber == 3 ? 'terzo' : (setNumber == 4 ? 'quarto' : 'quinto')));
    if (matchWinner != null) {
      _ttsService.speak(
        'Game, set e partita per la squadra \${getTeamName(matchWinner)}! Risultato finale: $setsWonA set a $setsWonB.',
      );
    } else {
      _ttsService.speak(
        'Game e $setOrdinal set per la squadra \${getTeamName(setWinner)}. $gA game a $gB.',
      );
    }
  }

  /// Annuncio arbitrale fluido e naturale
  void _announceRefereePointScore() {
    int pA = _currentSnapshot.rawPointsA;
    int pB = _currentSnapshot.rawPointsB;
    int deuceCount = _currentSnapshot.deuceCount;

    // CASI DI PARITÀ
    if (pA == pB) {
      if (pA == 0) {
        _ttsService.speak('Zero pari.');
      } else if (pA == 1) {
        _ttsService.speak('Quindici pari.');
      } else if (pA == 2) {
        _ttsService.speak('Trenta pari.');
      } else if (pA == 3) {
        if (_isGoldenPoint && deuceCount >= _advantagesBeforeGoldenPoint) {
          _ttsService.speak(_advantagesBeforeGoldenPoint == 2
              ? 'Quaranta pari. Star Point.'
              : 'Quaranta pari. Punto d\\'oro.');
        } else {
          _ttsService.speak('Quaranta pari. Parità.');
        }
      }
      return;
    }

    // CASI DI VANTAGGIO
    if (pA == 4) {
      _ttsService.speak('Vantaggio per la squadra $_teamAName.');
      return;
    }
    if (pB == 4) {
      _ttsService.speak('Vantaggio per la squadra $_teamBName.');
      return;
    }

    // PUNTI NORMALI
    final String labelA = _pointToItalian(pA);
    final String labelB = _pointToItalian(pB);
    final String server = currentServingPlayerName;

    _ttsService.speak('$labelA a $labelB. Serve $server.');
  }

  String _pointToItalian(int p) {
    switch (p) {
      case 0:
        return 'Zero';
      case 1:
        return 'Quindici';
      case 2:
        return 'Trenta';
      case 3:
        return 'Quaranta';
      default:
        return 'Zero';
    }
  }

  void announceTimeUp() {
    _ttsService.speak('Tempo scaduto, riprendere il gioco!');
  }

  void undo() {
    if (_history.isEmpty) return;
    _currentSnapshot = _history.removeLast();
    notifyListeners();
    _ttsService.speak('Punto annullato.');
  }

  void resetMatch() {
    _history.clear();
    _isSidesSwapped = false;
    final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: initialTeam,
      initialRotationIndex: 0,
    );
    notifyListeners();
    _ttsService.speak('Partita resettata. Serve $currentServingPlayerName.');
  }

  void toggleServingTeam() {
    _history.add(_currentSnapshot);
    final nextRot = _currentSnapshot.servingRotationIndex + 1;
    final rotation = getRotationOrder(_firstServerPlayerId);
    final nextPlayerId = rotation[nextRot % rotation.length];
    final newServerTeam = getTeamForPlayerId(nextPlayerId);
    _currentSnapshot = _currentSnapshot.copyWith(
      servingTeam: newServerTeam,
      servingRotationIndex: nextRot,
    );
    notifyListeners();
    _ttsService.speak('Cambio battitore. Serve $currentServingPlayerName.');
  }

  /// Inverte esclusivamente la visualizzazione dei lati del tabellone.
  /// Non altera in alcun modo punteggio, game, set, battitore o storico sportivo.
  void switchSides() {
    _isSidesSwapped = !_isSidesSwapped;
    notifyListeners();
    _ttsService.speak('Cambio campo.');
  }

  void setGoldenPoint(bool enabled, [int advantagesBefore = 0]) {
    // Compatibilità API: le modalità si scelgono nella schermata di setup.
    _configurationVersion++;
    _isGoldenPoint = enabled;
    _advantagesBeforeGoldenPoint = advantagesBefore;
    _savePreferences();
    notifyListeners();
    _ttsService.speak(!enabled
        ? 'Vantaggi tradizionali attivati.'
        : advantagesBefore == 2
            ? 'Star Point attivato.'
            : 'Punto d\\'oro attivato.');
  }

  void toggleMute() {
    _ttsService.setMuted(!_ttsService.isMuted);
    notifyListeners();
  }
}
`
  },
  {
    path: 'lib/services/tts_service.dart',
    filename: 'tts_service.dart',
    description: 'Motore vocale con rate 0.48 e cadenza fluida da arbitro professionista',
    language: 'dart',
    content: `import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servizio di sintesi vocale (TTS) 100% offline in lingua italiana
/// Ottimizzato con cadenza naturale da arbitro ufficiale di Padel
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  /// Inizializza il motore TTS con voce italiana, pitch naturale e velocità arbitrale
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('it-IT');
      // Velocità ridotta e naturale (0.48) per massima chiarezza e cadenza da arbitro
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);     // Volume pieno per udibilità a 15 metri
      await _flutterTts.setPitch(1.0);      // Tono naturale umano

      // Configurazione categoria audio iOS (Duck/Mix)
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      await _flutterTts.awaitSpeakCompletion(true);
      _isInitialized = true;
      debugPrint('[TtsService] Inizializzato con successo (it-IT, rate 0.48)');
    } catch (e) {
      debugPrint('[TtsService] Errore inizializzazione TTS: $e');
    }
  }

  /// Pronuncia una frase in modo fluido e naturale
  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.stop();
      // Il punto fermo e le pause creano una cadenza naturale da arbitro
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Errore riproduzione vocale: $e');
    }
  }

  /// Attiva o disattiva l'audio
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _flutterTts.stop();
    }
  }

  /// Ferma la voce corrente
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  void dispose() {
    _flutterTts.stop();
  }
}
`
  },
  {
    path: 'lib/services/bluetooth_key_service.dart',
    filename: 'bluetooth_key_service.dart',
    description: 'Intercettazione comandi Volume Up (1x/2x 400ms) e Volume Down (Undo)',
    language: 'dart',
    content: `import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'volume/volume_service.dart';

/// Servizio centralizzato per la gestione degli input da:
/// - Tasti volume hardware fisici del dispositivo nativo (iOS / Android)
/// - Telecomandi selfie Bluetooth (impulsi Volume Up / Volume Down)
/// - Tastiere fisiche, presenter e controller Bluetooth HID (Web e Nativo)
///
/// Implementa la logica centralizzata dei clic con timer debounce a 350ms:
/// - 1 Clic singolo -> SQUADRA A
/// - 2 Clic rapidi (Doppio Clic) -> SQUADRA B
/// - Pressione prolungata (Hold) o tasto Undo dedicato (Volume Down, Escape, Backspace) -> UNDO
class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final void Function(String actionType, String label)? onFeedback;

  /// FocusNode associato al widget KeyboardListener
  final FocusNode focusNode = FocusNode();

  // Gestione Debounce per 1 Clic vs 2 Clic entro 350ms
  Timer? _debounceTimer;
  int _clickCount = 0;
  static const Duration debounceDuration = Duration(milliseconds: 350);

  // Gestione Pressione Prolungata (Hold) per Undo
  Timer? _holdTimer;
  bool _isHoldTriggered = false;
  static const Duration holdDuration = Duration(milliseconds: 550);

  // Deduplicazione tra VolumeService nativo e HardwareKeyboard (evita falsi doppi clic entro 50ms)
  int _lastImpulseTimestamp = 0;
  int _lastKeyEventTimestamp = 0;
  LogicalKeyboardKey? _lastHandledKey;

  BluetoothKeyService({
    required this.onTeamAPoint,
    required this.onTeamBPoint,
    required this.onUndo,
    this.onFeedback,
  });

  /// Inizializza l'ascolto su piattaforme native (iOS/Android) e su Web
  void init() {
    // 1. Inizializza il listener per i tasti del volume hardware nativi
    // Su iOS TestFlight e Android APK cattura gli eventi hardware reali
    VolumeService.instance.init(
      onVolumeUp: () {
        debugPrint('[BluetoothKeyService] Hardware Volume UP ricevuto da VolumeService');
        _registerClick();
      },
      onVolumeDown: () {
        debugPrint('[BluetoothKeyService] Hardware Volume DOWN ricevuto da VolumeService -> UNDO');
        _triggerUndo();
      },
    );

    // 2. Registra listener globale su HardwareKeyboard (cattura tasti fisici ovunque nell'app)
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareEvent);

    // 3. Richiede il focus al KeyboardListener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// Handler per HardwareKeyboard.instance.addHandler
  bool _handleGlobalHardwareEvent(KeyEvent event) {
    final result = _processKeyEvent(event);
    return result == KeyEventResult.handled;
  }

  /// Handler per il widget KeyboardListener dell'interfaccia
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    return _processKeyEvent(event);
  }

  /// Elaborazione unificata degli eventi tastiera con deduplicazione
  KeyEventResult _processKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Deduplica se lo stesso evento viene processato contemporaneamente da entrambi i listener
    if (_lastHandledKey == key && (now - _lastKeyEventTimestamp) < 15) {
      return KeyEventResult.handled;
    }
    _lastHandledKey = key;
    _lastKeyEventTimestamp = now;

    // 1. TASTI DI UNDO IMMEDIATO: Escape, Backspace, Volume Down
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      if (event is KeyDownEvent) {
        _triggerUndo();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // 2. TASTI IMPULSO STANDARD (Telecomando selfie Bluetooth, Volume Up, Presenter, Frecce, Spazio, Invio)
    final bool isImpulseKey =
        key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaPlayPause;

    if (isImpulseKey) {
      if (event is KeyDownEvent) {
        // Avvia il timer di Hold (>550ms) per attivare l'UNDO
        _holdTimer?.cancel();
        _isHoldTriggered = false;
        _holdTimer = Timer(holdDuration, () {
          _isHoldTriggered = true;
          _triggerUndo();
        });
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        // Tasto rilasciato prima dell'Hold -> registra impulso clic (singolo o doppio)
        _holdTimer?.cancel();
        if (_isHoldTriggered) {
          _isHoldTriggered = false;
        } else {
          _registerClick();
        }
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        // Pressione continuata prolungata -> attiva subito UNDO
        if (!_isHoldTriggered) {
          _holdTimer?.cancel();
          _isHoldTriggered = true;
          _triggerUndo();
        }
        return KeyEventResult.handled;
      }
    }

    // 3. SCORCIATOIE RAPIDE DA TASTIERA PER TEST / ARBITRO
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.digit1) {
        onFeedback?.call('teamA', '+1 SQUADRA A');
        onTeamAPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.digit2) {
        onFeedback?.call('teamB', '+1 SQUADRA B');
        onTeamBPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyU || key == LogicalKeyboardKey.keyZ) {
        _triggerUndo();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// LOGICA CENTRALIZZATA DEI CLIC (TIMER DEBOUNCE ~350ms):
  /// - 1 Clic singolo: se entro 350ms non arriva un secondo impulso -> Aumenta il punteggio della SQUADRA A.
  /// - 2 Clic rapidi (Doppio Clic): se arriva un secondo impulso entro 350ms -> Annulla il singolo clic e aumenta il punteggio della SQUADRA B.
  void _registerClick() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Filtro antirimbalzo per evitare doppie registrazioni da listener simultanei (hardware volume + keyboard event)
    if ((now - _lastImpulseTimestamp) < 50) {
      return;
    }
    _lastImpulseTimestamp = now;

    _clickCount++;

    if (_clickCount == 1) {
      // 1° Clic: avvia timer di debounce di 350ms
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () {
        if (_clickCount == 1) {
          debugPrint('[BluetoothKeyService] Clic Singolo confermato (<350ms) -> +1 SQUADRA A');
          onFeedback?.call('teamA', '+1 SQUADRA A');
          onTeamAPoint();
        }
        _clickCount = 0;
        _debounceTimer = null;
      });
    } else if (_clickCount >= 2) {
      // 2° Clic arrivato entro 350ms: annulla singolo e assegna SQUADRA B
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _clickCount = 0;
      debugPrint('[BluetoothKeyService] Doppio Clic confermato (<350ms) -> +1 SQUADRA B');
      onFeedback?.call('teamB', '+1 SQUADRA B');
      onTeamBPoint();
    }
  }

  /// Pressione Prolungata (Hold) o tasto Undo dedicato (Volume Down, Escape, Backspace) -> UNDO
  void _triggerUndo() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _clickCount = 0;
    debugPrint('[BluetoothKeyService] Azione UNDO confermata');
    onFeedback?.call('undo', 'PUNTO ANNULLATO (UNDO)');
    onUndo();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _holdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareEvent);
    VolumeService.instance.dispose();
    focusNode.dispose();
  }
}
`
  },
  {
    path: 'lib/screens/landscape_scoreboard_screen.dart',
    filename: 'landscape_scoreboard_screen.dart',
    description: 'Tabellone orizzontale con visualizzazione chiara IN BATTUTA: [NOME GIOCATORE]',
    language: 'dart',
    content: `import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/padel_match_state.dart';
import '../providers/padel_score_provider.dart';
import '../services/bluetooth_key_service.dart';
import 'match_setup_screen.dart';

class LandscapeScoreboardScreen extends StatefulWidget {
  const LandscapeScoreboardScreen({super.key});

  @override
  State<LandscapeScoreboardScreen> createState() => _LandscapeScoreboardScreenState();
}

class _LandscapeScoreboardScreenState extends State<LandscapeScoreboardScreen> {
  late BluetoothKeyService _keyService;

  // Cronometro durata del match
  Timer? _matchTimer;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = true;

  // Timer Cambio Campo (90s regolamentari FIP / 120s a fine set)
  Timer? _breakTimer;
  int _breakSecondsLeft = 0;
  bool _isBreakActive = false;

  @override
  void initState() {
    super.initState();
    // 1. FORZATURA ORIENTAMENTO ESCLUSIVAMENTE ORIZZONTALE (LANDSCAPE)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Nasconde la barra di navigazione e di stato per massima immersività
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. Inizializzazione del servizio telecomando Bluetooth con debounce e feedback visivo
    final provider = context.read<PadelScoreProvider>();
    _keyService = BluetoothKeyService(
      onTeamAPoint: () {
        HapticFeedback.heavyImpact();
        provider.addPoint(Team.teamA);
      },
      onTeamBPoint: () {
        HapticFeedback.heavyImpact();
        provider.addPoint(Team.teamB);
      },
      onUndo: () {
        HapticFeedback.mediumImpact();
        provider.undo();
      },
      onFeedback: (type, label) {
        _showRemoteFeedback(type, label);
      },
    );

    _keyService.init();

    // 3. Avvio cronometro partita
    _startMatchTimer();
  }

  // Feedback visivo a schermo per azioni da telecomando/tastiera
  String? _remoteFeedbackText;
  Color _remoteFeedbackColor = const Color(0xFFCCFF00);
  Timer? _feedbackDismissTimer;

  void _showRemoteFeedback(String type, String message) {
    _feedbackDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _remoteFeedbackText = message;
      if (type == 'teamA') {
        _remoteFeedbackColor = const Color(0xFFCCFF00); // Giallo Fluo
      } else if (type == 'teamB') {
        _remoteFeedbackColor = const Color(0xFF00E5FF); // Ciano Elettrico
      } else {
        _remoteFeedbackColor = const Color(0xFFF43F5E); // Rosa / Rosso Undo
      }
    });

    _feedbackDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _remoteFeedbackText = null;
        });
      }
    });
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTimerRunning && mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _startBreakTimer({int duration = 90}) {
    HapticFeedback.vibrate();
    _breakTimer?.cancel();
    setState(() {
      _breakSecondsLeft = duration;
      _isBreakActive = true;
    });

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_breakSecondsLeft > 1) {
        setState(() {
          _breakSecondsLeft--;
        });
      } else {
        _stopBreakTimer();
        HapticFeedback.vibrate();
        context.read<PadelScoreProvider>().announceTimeUp();
      }
    });
  }

  void _stopBreakTimer() {
    _breakTimer?.cancel();
    if (mounted) {
      setState(() {
        _isBreakActive = false;
        _breakSecondsLeft = 0;
      });
    }
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '\${hours.toString().padLeft(2, '0')}:\${minutes.toString().padLeft(2, '0')}:\${seconds.toString().padLeft(2, '0')}';
    }
    return '\${minutes.toString().padLeft(2, '0')}:\${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _breakTimer?.cancel();
    _feedbackDismissTimer?.cancel();
    _keyService.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PadelScoreProvider>();
    final snapshot = provider.snapshot;

    return KeyboardListener(
      focusNode: _keyService.focusNode,
      autofocus: true,
      onKeyEvent: (event) => _keyService.handleKeyEvent(_keyService.focusNode, event),
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Stack(
            children: [
              // CORPO PRINCIPALE: DUE COLONNE (SQUADRA A vs SQUADRA B)
              Column(
                children: [
                  // Barra Superiore
                  _buildHeaderBar(context, provider, snapshot),

                  // Area Punteggio a 2 Macro Colonne
                  // Area Punteggio a 2 Macro Colonne (Invertibili visivamente al cambio campo)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final teamACol = Expanded(
                          child: _buildTeamColumn(
                            context: context,
                            provider: provider,
                            team: Team.teamA,
                            teamName: provider.teamAName,
                            player1: provider.player1Name,
                            player2: provider.player2Name,
                            scoreText: snapshot.displayPointA,
                            isServing: snapshot.servingTeam == Team.teamA,
                            gamesWon: snapshot.currentGamesA,
                            isTieBreak: snapshot.isTieBreak,
                            accentColor: const Color(0xFFCCFF00), // Giallo Fluorescente Padel
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              provider.addPoint(Team.teamA);
                            },
                          ),
                        );

                        final divider = Container(
                          width: 3,
                          color: const Color(0xFF1E293B),
                        );

                        final teamBCol = Expanded(
                          child: _buildTeamColumn(
                            context: context,
                            provider: provider,
                            team: Team.teamB,
                            teamName: provider.teamBName,
                            player1: provider.player3Name,
                            player2: provider.player4Name,
                            scoreText: snapshot.displayPointB,
                            isServing: snapshot.servingTeam == Team.teamB,
                            gamesWon: snapshot.currentGamesB,
                            isTieBreak: snapshot.isTieBreak,
                            accentColor: const Color(0xFF00E5FF), // Ciano Elettrico
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              provider.addPoint(Team.teamB);
                            },
                          ),
                        );

                        return Row(
                          children: provider.isSidesSwapped
                              ? [teamBCol, divider, teamACol]
                              : [teamACol, divider, teamBCol],
                        );
                      },
                    ),
                  ),

                  // Barra Inferiore: Storico Set Completo
                  _buildSetsHistoryBar(provider, snapshot),
                ],
              ),

              // OVERLAY CONTROLLI RAPIDI
              _buildTopFloatingControls(context, provider),

              // OVERLAY NOTIFICHE (Tie-Break, Punto d'Oro, Vittoria Match)
              if (snapshot.isTieBreak || snapshot.isGoldenPointSituation(provider.isGoldenPoint, provider.advantagesBeforeGoldenPoint) || provider.isMatchOver)
                _buildMatchStatusBanner(provider, snapshot),

              // OVERLAY TIMER CAMBIO CAMPO (90s / 120s FIP)
              if (_isBreakActive)
                _buildBreakTimerOverlay(),

              // OVERLAY FEEDBACK VISIVO TELECOMANDO BLUETOOTH (Punto A, Punto B, Undo)
              if (_remoteFeedbackText != null)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B14).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _remoteFeedbackColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _remoteFeedbackColor.withOpacity(0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _remoteFeedbackColor == const Color(0xFFF43F5E)
                                ? Icons.undo_rounded
                                : Icons.radio_button_checked,
                            color: _remoteFeedbackColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _remoteFeedbackText!,
                            style: TextStyle(
                              color: _remoteFeedbackColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra superiore con indicatori modalità, cronometro, setup button e guida telecomando
  Widget _buildHeaderBar(
    BuildContext context,
    PadelScoreProvider provider,
    PadelMatchSnapshot snapshot,
  ) {
    final currentSetNumber = snapshot.completedSets.length + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tasto Ritorno a Setup + Regola Punto d'Oro + Cronometro
          Row(
            children: [
              // Pulsante per tornare al Setup o cambiare giocatori
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
                tooltip: 'Torna al Setup Match',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),

              GestureDetector(
                // La modalità sportiva è informativa: si sceglie nel setup.
                onTap: null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: provider.isGoldenPoint ? const Color(0x22FACC15) : const Color(0x2238BDF8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isGoldenPoint ? Icons.stars_rounded : Icons.swap_horiz_rounded,
                        size: 15,
                        color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        !provider.isGoldenPoint
                            ? 'VANTAGGI CLASSICI'
                            : provider.advantagesBeforeGoldenPoint == 2
                                ? 'STAR POINT'
                                : 'PUNTO D\\'ORO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Cronometro Match
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isTimerRunning = !_isTimerRunning;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTimerRunning ? Icons.timer_outlined : Icons.pause_circle_outline,
                        size: 13,
                        color: _isTimerRunning ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Indicatore Set Corrente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              snapshot.isTieBreak
                  ? 'SET $currentSetNumber: TIE-BREAK'
                  : 'SET $currentSetNumber IN CORSO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Guida Telecomando & Tasto Pausa 90s
          Row(
            children: [
              GestureDetector(
                onTap: () => _startBreakTimer(duration: 90),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, size: 13, color: Color(0xFF00E5FF)),
                      SizedBox(width: 4),
                      Text(
                        'Pausa 90s',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_connected, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 5),
                    Text(
                      'Vol+: Sq.1 (x1) | Sq.2 (x2) | Vol-: Undo',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Colonna Squadra ad alto contrasto per visibilità a 15 metri
  Widget _buildTeamColumn({
    required BuildContext context,
    required PadelScoreProvider provider,
    required Team team,
    required String teamName,
    required String player1,
    required String player2,
    required String scoreText,
    required bool isServing,
    required int gamesWon,
    required bool isTieBreak,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final servingPlayerName = provider.currentServingPlayerName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. INTESTAZIONE: Nome Squadra + Nomi Coppia
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          teamName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$player1 & $player2',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 2. INDICATORE SERVIZIO ULTRA CHIARO: "IN BATTUTA: [NOME GIOCATORE]"
                  if (isServing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCCFF00).withValues(alpha: 0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_tennis, size: 16, color: Colors.black),
                          const SizedBox(width: 6),
                          Text(
                            'IN BATTUTA: \${servingPlayerName.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Placeholder invisibile per mantenere la perfetta centratura verticale
                    const SizedBox(height: 27),
                ],
              ),

              // 3. PUNTEGGIO GAME GIGANTE AL CENTRO (Visibile a 15 metri sotto il sole)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        scoreText,
                        style: TextStyle(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          color: scoreText == 'AV'
                              ? const Color(0xFFF59E0B)
                              : Colors.white,
                          height: 0.9,
                          shadows: [
                            Shadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Riquadro Game Vinti nel Set Corrente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'GAME NEL SET: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$gamesWon',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra inferiore con il riepilogo di tutti i Set giocati
  Widget _buildSetsHistoryBar(
    PadelScoreProvider provider,
    PadelMatchSnapshot snapshot,
  ) {
    final sets = snapshot.completedSets;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0B132B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.scoreboard_outlined, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          const Text(
            'RISULTATO SET: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),

          if (sets.isEmpty)
            const Text(
              'Primo set in corso',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontStyle: FontStyle.italic),
            )
          else
            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: set.winner == Team.teamA
                        ? const Color(0xFFCCFF00).withValues(alpha: 0.5)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Set \${index + 1}: \${set.toString()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

          // Set corrente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x33CCFF00),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCCFF00)),
            ),
            child: Text(
              'Set \${sets.length + 1} (in corso): \${snapshot.currentGamesA} - \${snapshot.currentGamesB}',
              style: const TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Toolbar fluttuante rapida
  Widget _buildTopFloatingControls(BuildContext context, PadelScoreProvider provider) {
    return Positioned(
      bottom: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xDD0F172A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UNDO
            IconButton(
              tooltip: 'Annulla ultimo punto (Undo)',
              icon: Icon(
                Icons.undo_rounded,
                color: provider.canUndo ? Colors.white : Colors.white24,
                size: 24,
              ),
              onPressed: provider.canUndo ? () {
                HapticFeedback.mediumImpact();
                provider.undo();
              } : null,
            ),

            // Scambia Battitore
            IconButton(
              tooltip: 'Avanza rotazione battitore',
              icon: const Icon(Icons.sports_tennis, color: Color(0xFFCCFF00), size: 22),
              onPressed: () => provider.toggleServingTeam(),
            ),

            // Scambia Campo
            IconButton(
              tooltip: 'Scambia campo (e avvia pausa 90s)',
              icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 24),
              onPressed: () {
                provider.switchSides();
                _startBreakTimer(duration: 90);
              },
            ),

            // Mute TTS
            IconButton(
              tooltip: provider.isMuted ? 'Attiva voce TTS' : 'Disattiva voce TTS',
              icon: Icon(
                provider.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: provider.isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 24,
              ),
              onPressed: () => provider.toggleMute(),
            ),

            // Reset
            IconButton(
              tooltip: 'Nuova partita (Reset)',
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFEF4444), size: 24),
              onPressed: () => _confirmResetDialog(context, provider),
            ),

            // Modifica Setup
            IconButton(
              tooltip: 'Modifica Nomi e Setup',
              icon: const Icon(Icons.tune, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Overlay conto alla rovescia Cambio Campo (90s)
  Widget _buildBreakTimerOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, size: 48, color: Color(0xFF00E5FF)),
              const SizedBox(height: 12),
              const Text(
                'CAMBIO CAMPO (REGOLA FIP)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$_breakSecondsLeft',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Riprendi Gioco'),
                onPressed: _stopBreakTimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner animato per eventi salienti
  Widget _buildMatchStatusBanner(PadelScoreProvider provider, PadelMatchSnapshot snapshot) {
    String message = '';
    Color bannerColor = const Color(0xFFF59E0B);

    if (provider.isMatchOver) {
      final winner = snapshot.matchWinner!;
      message = '🏆 VITTORIA MATCH: \${provider.getTeamName(winner).toUpperCase()}! 🏆';
      bannerColor = const Color(0xFF10B981);
    } else if (snapshot.isTieBreak) {
      message = '⚡ TIE-BREAK A 7 PUNTI ⚡';
      bannerColor = const Color(0xFF8B5CF6);
    } else if (snapshot.isGoldenPointSituation(provider.isGoldenPoint, provider.advantagesBeforeGoldenPoint)) {
      message = provider.advantagesBeforeGoldenPoint == 2
          ? '🔥 40 PARI: STAR POINT DECISIVO! 🔥'
          : '🔥 40 PARI: PUNTO D\\'ORO DECISIVO! 🔥';
      bannerColor = const Color(0xFFEF4444);
    }

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmResetDialog(BuildContext context, PadelScoreProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Resettare la Partita?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tutti i punti, i set e il cronometro verranno azzerati. Sei sicuro?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Azzera Tutto', style: TextStyle(color: Colors.white)),
            onPressed: () {
              provider.resetMatch();
              setState(() {
                _elapsedSeconds = 0;
              });
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
`
  },
  {
    path: 'lib/main.dart',
    filename: 'main.dart',
    description: 'Entry point con avvio da MatchSetupScreen e WakelockPlus',
    language: 'dart',
    content: `import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/padel_score_provider.dart';
import 'screens/match_setup_screen.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Forza orientamento Landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 2. Mantiene lo schermo sempre acceso per tutta la durata del match a bordo campo
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  // 3. Inizializza TTS offline in lingua italiana
  final ttsService = TtsService();
  await ttsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PadelScoreProvider(ttsService: ttsService),
        ),
      ],
      child: const PadelScoreBotApp(),
    ),
  );
}

class PadelScoreBotApp extends StatelessWidget {
  const PadelScoreBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padel ScoreBot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFCCFF00),   // Giallo Fluorescente Padel
          secondary: Color(0xFF00E5FF), // Ciano Elettrico
          surface: Color(0xFF0F172A),
        ),
        fontFamily: 'Roboto',
      ),
      // Avvia l'app dalla Schermata Iniziale di Setup Match
      home: const MatchSetupScreen(),
    );
  }
}
`
  },
  {
    path: 'android/app/src/main/AndroidManifest.xml',
    filename: 'AndroidManifest.xml',
    description: 'AndroidManifest con Landscape forzato e permessi WAKE_LOCK e BLUETOOTH',
    language: 'xml',
    content: `<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.padel.scorebot">

    <!-- Permessi per Audio, Wake Lock (schermo sempre attivo a bordo campo) e Bluetooth -->
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <application
        android:label="Padel ScoreBot"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:screenOrientation="landscape"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
`
  },
  {
    path: 'ios/Runner/Info.plist',
    filename: 'Info.plist',
    description: 'Info.plist iOS con Landscape esclusivo e audio in background',
    language: 'xml',
    content: `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Padel Score Board</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>padel_score_board</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
		<string>bluetooth-central</string>
	</array>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UIRequiresFullScreen</key>
	<true/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
</dict>
</plist>
`
  }
];
