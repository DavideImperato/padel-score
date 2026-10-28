import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/padel_score_provider.dart';
import '../services/app_orientation.dart';
import '../services/tournament_match_link.dart';
import 'landscape_scoreboard_screen.dart';
import '../services/tournament_draw.dart';
import '../services/tournament_store.dart';
import '../widgets/app_content_safe_area.dart';

const _lime = Color(0xFFCCFF00);
const _cyan = Color(0xFF00E5FF);

String _roundLabel(int round, int total) {
  if (round == total) return 'Finale';
  if (round == total - 1) return 'Semifinali';
  if (round == total - 2) return 'Quarti di finale';
  return 'Turno $round';
}

class TournamentDrawScreen extends StatefulWidget {
  const TournamentDrawScreen({super.key, required this.tournamentId});
  final String tournamentId;
  @override
  State<TournamentDrawScreen> createState() => _TournamentDrawScreenState();
}

class _TournamentDrawScreenState extends State<TournamentDrawScreen> {
  Map<String, dynamic>? _tournament;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    await TournamentStore.reconcileFinishedMatches(widget.tournamentId);
    final data = await TournamentStore.load();
    if (!mounted) return;
    final matches = (data?['tournaments'] as List? ?? [])
        .where((t) => t['id'] == widget.tournamentId);
    setState(() {
      _loaded = true;
      _tournament = matches.isEmpty ? null : Map<String, dynamic>.from(matches.first as Map);
    });
  }

  Future<void> _change(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    final error = await action();
    if (!mounted) return;
    setState(() { _busy = false; _error = error; });
    if (error == null) await _reload();
  }

  String _pairName(String? id) {
    if (id == null) return 'Da definire';
    for (final entry in _tournament?['entries'] as List? ?? []) {
      if (entry['pairId'] == id) return entry['pairName'] as String;
    }
    return 'Coppia non trovata';
  }

  String _resultLabel(Map match) {
    if (TournamentDraw.isBye(match)) return 'Passa il turno (BYE)';
    if (match['homeId'] == null || match['awayId'] == null) return 'In attesa dei turni precedenti';
    if (match['result'] == null) return 'Da giocare';
    return (match['result']['sets'] as List)
        .map((s) => '${s[0]}–${s[1]}').join('  ·  ');
  }

  Map<String, dynamic>? _entryFor(String id) {
    for (final item in _tournament?['entries'] as List? ?? []) {
      if (item['pairId'] == id) return Map<String, dynamic>.from(item as Map);
    }
    return null;
  }

  Future<void> _openFixture(Map match) async {
    if (_busy || match['homeId'] == null || match['awayId'] == null) return;
    final played = match['result'] != null;
    final choice = await showModalBottomSheet<String>(
      context: context, showDragHandle: true,
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_pairName(match['homeId'] as String?)}  vs  ${_pairName(match['awayId'] as String?)}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!played) ListTile(
            leading: const Icon(Icons.play_circle_fill, color: _lime),
            title: const Text('Gioca partita'),
            subtitle: const Text('Segnapunti con iPhone, telecomando e Apple Watch'),
            onTap: () => Navigator.of(sheet).pop('play')),
          ListTile(
            leading: const Icon(Icons.edit_note, color: _cyan),
            title: Text(played ? 'Modifica risultato' : 'Inserisci risultato'),
            subtitle: const Text('Parziali manuali dei set'),
            onTap: () => Navigator.of(sheet).pop('manual')),
          ListTile(leading: const Icon(Icons.close), title: const Text('Annulla'),
            onTap: () => Navigator.of(sheet).pop()),
        ]),
      )),
    );
    if (!mounted) return;
    if (choice == 'manual') await _editResult(match);
    if (choice == 'play') await _playFixture(match);
  }

  Future<void> _playFixture(Map match) async {
    final provider = context.read<PadelScoreProvider>();
    if (provider.hasActiveMatch || provider.hasSavedMatch) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hai già una partita in corso o da recuperare. Concludila prima di iniziare un incontro del torneo.')));
      return;
    }
    // Ricontrollo lo slot contro la versione su disco: una modifica a un turno
    // precedente può aver cambiato i partecipanti mentre il popup era aperto.
    final data = await TournamentStore.load();
    if (!mounted || data == null) return;
    final tournaments = (data['tournaments'] as List).where((t) => t['id'] == widget.tournamentId);
    if (tournaments.isEmpty) return;
    final current = tournaments.first as Map;
    final slots = ((current['draw'] as Map)['matches'] as List).where((m) => m['id'] == match['id']);
    if (slots.isEmpty || slots.first['homeId'] != match['homeId'] ||
        slots.first['awayId'] != match['awayId'] || slots.first['result'] != null) {
      await _reload();
      return;
    }
    final home = _entryFor(match['homeId'] as String);
    final away = _entryFor(match['awayId'] as String);
    if (home == null || away == null) return;
    final playersA = List<String>.from(home['playerNames'] as List);
    final playersB = List<String>.from(away['playerNames'] as List);
    final idsA = List<String>.from(home['playerIds'] as List);
    final idsB = List<String>.from(away['playerIds'] as List);
    // Il battitore si sceglie prima del match, senza modificare le coppie.
    final server = await showDialog<int>(context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Chi serve per primo?'),
        children: [
          for (var i = 0; i < 4; i++) SimpleDialogOption(
            onPressed: () => Navigator.of(dialog).pop(i + 1),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(i < 2 ? playersA[i] : playersB[i - 2])),
          ),
          SimpleDialogOption(onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Annulla')),
        ],
      ),
    );
    if (!mounted || server == null) return;
    if (provider.hasActiveMatch || provider.hasSavedMatch) return;
    provider.setupMatch(
      team1: home['pairName'] as String, team2: away['pairName'] as String,
      player1: playersA[0], player2: playersA[1],
      player3: playersB[0], player4: playersB[1],
      playerIds: [...idsA, ...idsB], firstServerPlayerId: server,
      goldenPoint: provider.isGoldenPoint,
      advantagesBeforeGoldenPoint: provider.advantagesBeforeGoldenPoint,
      bestOfSets: 3, shortSets: false, decidingMatchTieBreak: false,
      tournamentLink: TournamentMatchLink.build(
        tournamentId: widget.tournamentId, fixtureId: match['id'] as String,
        homeId: match['homeId'] as String, awayId: match['awayId'] as String,
        drawCreatedAt: (current['draw'] as Map)['createdAt'] as int),
    );
    await AppOrientation.match();
    if (!mounted) return;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LandscapeScoreboardScreen(),
      ));
    } finally {
      await AppOrientation.home();
      if (mounted) await _reload();
    }
  }

  Future<void> _editResult(Map match) async {
    if (_busy || match['homeId'] == null || match['awayId'] == null) return;
    final saved = (match['result']?['sets'] as List?) ?? [];
    // TextFormField gestisce da sé i controller: nessun dispose anticipato
    // durante l'animazione di chiusura del dialogo.
    final values = List.generate(3, (i) => List.generate(2, (j) =>
        i < saved.length ? '${saved[i][j]}' : (j == 0 ? '6' : '4')));
    var useThird = saved.length == 3;
    String? validation;
    // Il future di showDialog termina su Navigator.pop, prima della fine
    // della transizione. Aspettiamo invece la rimozione completa dell'overlay
    // prima di ricostruire il tabellone e scrivere il risultato.
    final route = DialogRoute<List<List<int>>?>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, update) => AlertDialog(
        title: const Text('Risultato incontro'),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_pairName(match['homeId'] as String?)}  vs  ${_pairName(match['awayId'] as String?)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Inserisci i game di ogni set, dalla prospettiva delle due coppie.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            for (var i = 0; i < (useThird ? 3 : 2); i++) ...[
              Text('SET ${i + 1}', style: const TextStyle(color: _lime, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(children: [
                for (var j = 0; j < 2; j++) Expanded(child: Padding(
                  padding: EdgeInsets.only(right: j == 0 ? 10 : 0),
                  child: TextFormField(
                    initialValue: values[i][j],
                    onChanged: (text) => values[i][j] = text,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: j == 0 ? 'Coppia A' : 'Coppia B',
                      counterText: '',
                    ),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Terzo set'),
              value: useThird,
              onChanged: (value) => update(() { useThird = value; validation = null; }),
            ),
            const Text('Sono ammessi i risultati al meglio dei tre set, compresi mini-set e match tie-break decisivo.',
                style: TextStyle(fontSize: 12)),
            if (validation != null) Padding(padding: const EdgeInsets.only(top: 10),
              child: Text(validation!, style: const TextStyle(color: Colors.redAccent))),
          ],
        ))),
        actions: [
          if (saved.isNotEmpty) TextButton(
            onPressed: () => Navigator.pop(dialog, <List<int>>[]),
            child: const Text('Cancella risultato')),
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            final sets = <List<int>>[];
            for (var i = 0; i < (useThird ? 3 : 2); i++) {
              final a = int.tryParse(values[i][0]);
              final b = int.tryParse(values[i][1]);
              if (a == null || b == null) {
                update(() => validation = 'Inserisci soltanto numeri interi.');
                return;
              }
              sets.add([a, b]);
            }
            if (!TournamentDraw.validResult({'sets': sets})) {
              update(() => validation = 'Risultato non valido: una coppia deve vincere 2 set.');
              return;
            }
            Navigator.pop(dialog, sets);
          }, child: const Text('Salva')),
        ],
      )),
    );
    final command = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    if (!mounted || command == null) return;
    if (command.isEmpty) {
      final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Cancellare il risultato?'),
        content: const Text('Se modifica il vincitore di un turno, anche i risultati dei turni successivi che dipendono da esso saranno annullati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Conferma')),
        ],
      ));
      if (confirm != true || !mounted) return;
    }
    await _change(() => TournamentStore.saveResult(widget.tournamentId,
        match['id'] as String, command.isEmpty ? null : command));
  }

  Widget _fixture(Map match) {
    final a = match['homeId'] as String?;
    final b = match['awayId'] as String?;
    final winner = TournamentDraw.advancing(match);
    final canScore = a != null && b != null;
    return Card(child: InkWell(
      onTap: _busy || !canScore ? null : () => _openFixture(match),
      borderRadius: BorderRadius.circular(14),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Incontro ${(match['slot'] as int) + 1}',
                style: const TextStyle(fontSize: 12, color: _cyan))),
            if (canScore) const Icon(Icons.more_horiz, size: 21, color: _lime),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            if (winner == a && a != null) const Icon(Icons.emoji_events, size: 17, color: _lime),
            Expanded(child: Text(_pairName(a), style: TextStyle(
                fontWeight: winner == a && a != null ? FontWeight.w900 : FontWeight.normal))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            if (winner == b && b != null) const Icon(Icons.emoji_events, size: 17, color: _lime),
            Expanded(child: Text(_pairName(b), style: TextStyle(
                fontWeight: winner == b && b != null ? FontWeight.w900 : FontWeight.normal))),
          ]),
          const SizedBox(height: 9),
          Text(_resultLabel(match), style: const TextStyle(fontSize: 13, color: _cyan)),
        ],
      )),
    ));
  }

  Widget _standings(Map group, Map draw) {
    final ranking = TournamentDraw.standing(group, draw);
    final rows = ranking['rows'] as List;
    return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
      const Text('CLASSIFICA', style: TextStyle(fontWeight: FontWeight.bold, color: _lime)),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        horizontalMargin: 8, columnSpacing: 12,
        columns: const [
          DataColumn(label: Text('Coppia')),
          DataColumn(label: Text('G')),
          DataColumn(label: Text('V')),
          DataColumn(label: Text('Pti')),
          DataColumn(label: Text('Diff. set')),
          DataColumn(label: Text('Diff. game')),
        ],
        rows: [for (final row in rows)
          DataRow(cells: [
            DataCell(SizedBox(width: 105, child: Text(_pairName(row['pairId'] as String),
                maxLines: 2, overflow: TextOverflow.ellipsis))),
            DataCell(Text('${row['played']}')),
            DataCell(Text('${row['wins']}')),
            DataCell(Text('${row['points']}')),
            DataCell(Text('${(row['setsFor'] as int) - (row['setsAgainst'] as int)}')),
            DataCell(Text('${(row['gamesFor'] as int) - (row['gamesAgainst'] as int)}')),
          ]),
        ],
      )),
      const SizedBox(height: 6),
      const Text('Vittoria = 3 punti. In parità: differenza set, poi differenza game.',
        style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final current = _tournament;
    final draw = current?['draw'] as Map?;
    final groups = draw?['groups'] as List? ?? [];
    final matches = draw?['matches'] as List? ?? [];
    final isGroups = current?['format'] == 'groups';
    final completed = matches.where((m) => m['result'] != null).length;
    final playable = matches.where((m) => !TournamentDraw.isBye(m as Map)).length;
    final champion = draw == null ? null : TournamentDraw.champion(draw);
    final rounds = matches.map((m) => m['round'] as int).toSet().toList()..sort();
    final pages = <Widget>[
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!,
        style: const TextStyle(color: Colors.redAccent))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text(current?['name'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('$completed / $playable incontri completati'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: playable == 0 ? 0 : completed / playable,
          minHeight: 8, borderRadius: BorderRadius.circular(8)),
        if (champion != null) Padding(padding: const EdgeInsets.only(top: 14),
          child: Column(children: [const Icon(Icons.emoji_events, size: 34, color: _lime),
            Text('VINCITORI: ${_pairName(champion)}', textAlign: TextAlign.center,
              style: const TextStyle(color: _lime, fontWeight: FontWeight.bold))])),
        if (isGroups && completed == playable) const Padding(
          padding: EdgeInsets.only(top: 12), child: Text('Gironi completati!', style: TextStyle(color: _lime))),
      ]))),
      if (isGroups) ...[
        for (final group in groups) ...[
          const SizedBox(height: 20),
          Text('GIRONE ${String.fromCharCode(64 + int.parse((group['id'] as String).substring(1)))}',
            style: const TextStyle(color: _lime, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _standings(group as Map, draw!),
          const SizedBox(height: 10),
          const Text('INCONTRI', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final m in matches.where((m) => m['groupId'] == group['id']))
            _fixture(m as Map),
        ],
      ] else ...[
        for (final r in rounds) ...[
          const SizedBox(height: 20),
          Text(_roundLabel(r, rounds.length).toUpperCase(),
            style: const TextStyle(color: _lime, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final m in matches.where((m) => m['round'] == r))
            _fixture(m as Map),
        ],
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(isGroups ? 'Gironi e classifiche' : 'Tabellone torneo')),
      body: AppContentSafeArea(child: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : current == null || draw == null
          ? const Center(child: Text('Torneo o calendario non disponibile.'))
          : ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 36), children: pages)),
    );
  }
}
