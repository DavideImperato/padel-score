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

  int _selectedFirstServerId = 1;
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LandscapeScoreboardScreen()),
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
        title: const Text(
          'PADEL SCOREBOT — SETUP MATCH',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 1,
                            accentColor: const Color(0xFFCCFF00),
                            teamController: _team1Controller,
                            playerAController: _player1Controller,
                            playerBController: _player2Controller,
                            playerALabel: 'Giocatore 1',
                            playerBLabel: 'Giocatore 2',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 2,
                            accentColor: const Color(0xFF00E5FF),
                            teamController: _team2Controller,
                            playerAController: _player3Controller,
                            playerBController: _player4Controller,
                            playerALabel: 'Giocatore 3',
                            playerBLabel: 'Giocatore 4',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildServingRotationCard(),
                    const SizedBox(height: 24),
                    _buildRulesCard(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      onPressed: _startMatch,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill, size: 28, color: Colors.black),
                          SizedBox(width: 10),
                          Text(
                            'INIZIA PARTITA',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard({required int teamNumber, required Color accentColor, required TextEditingController teamController, required TextEditingController playerAController, required TextEditingController playerBController, required String playerALabel, required String playerBLabel}) {
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
          Text('SQUADRA $teamNumber', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          TextFormField(
            controller: teamController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Nome Squadra $teamNumber',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome squadra' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: playerAController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerALabel,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome giocatore' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: playerBController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerBLabel,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci compagno' : null,
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
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CHI SERVE PER PRIMO? (ROTAZIONE A 4 GIOCATORI)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 12),
          DropdownButton<int>(
            value: _selectedFirstServerId,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            items: [
              DropdownMenuItem(value: 1, child: Text('1° Servizio: $p1 (Squadra 1)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 2, child: Text('1° Servizio: $p2 (Squadra 1)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 3, child: Text('1° Servizio: $p3 (Squadra 2)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 4, child: Text('1° Servizio: $p4 (Squadra 2)', style: const TextStyle(color: Colors.white))),
            ],
            onChanged: (val) => setState(() => _selectedFirstServerId = val ?? 1),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFirstServerId == 1
                ? 'Turni Ufficiali: 1: $p1 ➔ 2: $p3 ➔ 3: $p2 ➔ 4: $p4 (ciclico)'
                : 'Turni Ufficiali: sequenza a coppie alternate FIP',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text('Punto d'Oro sul 40-40', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        value: _isGoldenPoint,
        activeColor: const Color(0xFFCCFF00),
        onChanged: (v) => setState(() => _isGoldenPoint = v),
      ),
    );
  }
}
