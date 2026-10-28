import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/padel_score_provider.dart';
import '../services/app_orientation.dart';
import '../services/app_preferences.dart';
import '../widgets/app_about_footer.dart';
import 'app_settings_screen.dart';
import 'landscape_scoreboard_screen.dart';
import 'match_history_screen.dart';
import 'match_setup_screen.dart';
import 'match_statistics_screen.dart';
import 'player_directory_screen.dart';
import 'tournaments_screen.dart';

/// Home personale. Nessun account: il nome resta in SharedPreferences.
class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({super.key});
  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> with RouteAware {
  final TextEditingController _nameInput = TextEditingController();
  bool _saving = false;
  ModalRoute<dynamic>? _route;
  late PadelScoreProvider _provider;
  int _lastWatchStart = 0;
  bool _watchRouteScheduled = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PadelScoreProvider>();
    _lastWatchStart = _provider.watchStartSequence;
    _provider.addListener(_onWatchCommand);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (_route != next) {
      if (_route != null) homeRouteObserver.unsubscribe(this);
      _route = next;
      if (next != null) homeRouteObserver.subscribe(this, next);
    }
  }

  @override
  void didPopNext() {
    AppOrientation.home();
    setState(() {});
  }

  void _onWatchCommand() {
    if (!mounted) return;
    if (_lastWatchStart == _provider.watchStartSequence) return;
    _lastWatchStart = _provider.watchStartSequence;
    if (_watchRouteScheduled || ModalRoute.of(context)?.isCurrent != true) return;
    _watchRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AppOrientation.match();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LandscapeScoreboardScreen(),
      ));
      _watchRouteScheduled = false;
    });
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    _provider.removeListener(_onWatchCommand);
    _nameInput.dispose();
    super.dispose();
  }

  Future<void> _openMatchSetup() async {
    await AppOrientation.setup();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MatchSetupScreen(),
    ));
  }

  Future<void> _saveName(AppPreferences prefs) async {
    setState(() => _saving = true);
    final ok = await prefs.changeName(_nameInput.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome valido (massimo 40 caratteri).')),
      );
    }
  }

  Widget _tile({required String title, required String subtitle,
      required IconData icon, required VoidCallback onTap, bool primary = false}) {
    return Card(
      color: primary ? const Color(0xFFCAFF00) : const Color(0xFF182744),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          child: Row(children: [
            Icon(icon, size: 28, color: primary ? Colors.black : const Color(0xFFCAFF00)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, style: TextStyle(
                color: primary ? const Color(0xFF0C1730) : Colors.white,
                fontWeight: FontWeight.w900, fontSize: 15,
              )),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, style: TextStyle(
                color: primary ? const Color(0xFF24301C) : const Color(0xFFB6C2D6), fontSize: 11,
              )),
            ])),
            Icon(Icons.chevron_right, color: primary ? Colors.black : Colors.white70),
          ]),
        ),
      ),
    );
  }

  /// Card principali leggibili anche su iPhone compatti: icona e titolo
  /// occupano righe diverse, evitando parole tagliate a meta'.
  Widget _mainTile({required String title, required String subtitle,
      required IconData icon, required VoidCallback onTap, bool primary = false}) {
    final foreground = primary ? const Color(0xFF091326) : Colors.white;
    return Card(
      margin: EdgeInsets.zero,
      color: primary ? const Color(0xFFCAFF00) : const Color(0xFF182744),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 152,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(icon, color: foreground, size: 29),
                  Icon(Icons.arrow_forward_ios_rounded, color: foreground, size: 16),
                ]),
                const Spacer(),
                Text(title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground, fontSize: 16,
                    height: 1.12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11,
                    color: primary ? const Color(0xFF24301C) : const Color(0xFFB6C2D6))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final provider = context.watch<PadelScoreProvider>();
    final onboarding = !prefs.hasName;
    final dark = prefs.darkMode;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF091326) : const Color(0xFFF0F5FA),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 960 : 650),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isTablet ? 30 : 18, 20, isTablet ? 30 : 18, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 6),
            Center(
              child: Semantics(
                label: 'Logo Padel Score Board',
                image: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icon.png',
                    width: isTablet ? 220 : (MediaQuery.sizeOf(context).width < 380 ? 175 : 210),
                    height: isTablet ? 220 : (MediaQuery.sizeOf(context).width < 380 ? 175 : 210),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_tennis,
                      size: 85,
                      color: Color(0xFFCAFF00),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (onboarding) ...[
              Text('Benvenuto!', style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF101D38),
                fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Come ti chiami? Useremo il nome soltanto per personalizzare la Home.',
                style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 18),
              TextField(
                controller: _nameInput, maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Il tuo nome',
                  border: OutlineInputBorder()),
                onSubmitted: (_) { if (!_saving) _saveName(prefs); },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _saving ? null : () => _saveName(prefs),
                child: Text(_saving ? 'SALVATAGGIO…' : 'CONTINUA'),
              ),
              const SizedBox(height: 12),
              const Text('Non serve registrarsi. Il nome rimane sul dispositivo.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ] else ...[
              Text('Ciao, ${prefs.name}!', textAlign: TextAlign.center,
                style: TextStyle(color: dark ? Colors.white : const Color(0xFF101D38),
                  fontSize: 29, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('Pronto per la prossima partita?', textAlign: TextAlign.center,
                style: TextStyle(color: dark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 25),
              if (provider.hasSavedMatch) ...[
                _tile(title: 'RIPRENDI PARTITA', subtitle: 'Recupera il punteggio salvato',
                  icon: Icons.restore, primary: true, onTap: _openMatchSetup),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(child: _mainTile(title: 'INIZIA PARTITA', subtitle: 'Crea il match',
                  icon: Icons.play_circle_fill, primary: true, onTap: _openMatchSetup)),
                const SizedBox(width: 12),
                Expanded(child: _mainTile(title: 'STORICO PARTITE', subtitle: 'Risultati salvati',
                  icon: Icons.history, onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MatchHistoryScreen())))),
              ]),
              const SizedBox(height: 10),
              if (isTablet) ...[
                Row(children: [
                  Expanded(child: _tile(title: 'GIOCATORI E COPPIE', subtitle: 'Gestisci la tua rubrica',
                    icon: Icons.groups_2_outlined, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PlayerDirectoryScreen())))),
                  const SizedBox(width: 12),
                  Expanded(child: _tile(title: 'TORNEI', subtitle: 'Organizza tornei e iscrivi coppie',
                    icon: Icons.emoji_events_outlined, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const TournamentsScreen())))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _tile(title: 'STATISTICHE', subtitle: 'Vittorie, risultati e andamento',
                    icon: Icons.bar_chart_rounded, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const MatchStatisticsScreen())))),
                  const SizedBox(width: 12),
                  Expanded(child: _tile(title: 'IMPOSTAZIONI', subtitle: 'Watch, audio, aspetto e informazioni',
                    icon: Icons.settings_outlined, onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AppSettingsScreen())))),
                ]),
              ] else ...[
                _tile(title: 'GIOCATORI E COPPIE', subtitle: 'Gestisci la tua rubrica',
                  icon: Icons.groups_2_outlined, onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PlayerDirectoryScreen()))),
                const SizedBox(height: 10),
                _tile(title: 'TORNEI', subtitle: 'Organizza tornei e iscrivi coppie',
                  icon: Icons.emoji_events_outlined, onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TournamentsScreen()))),
                const SizedBox(height: 10),
                _tile(title: 'STATISTICHE', subtitle: 'Vittorie, risultati e andamento',
                  icon: Icons.bar_chart_rounded, onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MatchStatisticsScreen()))),
                const SizedBox(height: 10),
                _tile(title: 'IMPOSTAZIONI', subtitle: 'Watch, audio, aspetto e informazioni',
                  icon: Icons.settings_outlined, onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AppSettingsScreen()))),
              ],
            ],
            const SizedBox(height: 24),
            const AppAboutFooter(),
          ]),
        ),
      ))),
    );
  }
}
