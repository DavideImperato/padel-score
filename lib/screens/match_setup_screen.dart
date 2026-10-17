import 'package:flutter/material.dart';
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
  bool _isGoldenPoint = true;
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
    _isGoldenPoint = provider.isGoldenPoint;
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
      goldenPoint: _isGoldenPoint,
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
            'Seleziona il giocatore che apre il servizio. L\'app gestirà rigorosamente la rotazione ufficiale del Padel ad ogni game.',
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
          // Switch Punto d'Oro
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Regola Punto d\'Oro (Golden Point)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'Sul 40-40 chi conquista il punto successivo vince direttamente il Game.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            value: _isGoldenPoint,
            activeColor: const Color(0xFFCCFF00),
            onChanged: (val) => setState(() => _isGoldenPoint = val),
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
