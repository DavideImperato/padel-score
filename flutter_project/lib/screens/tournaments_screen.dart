import 'package:flutter/material.dart';
import '../services/player_directory.dart';
import '../services/tournament_store.dart';
import '../services/tournament_draw.dart';
import 'tournament_draw_screen.dart';
import '../widgets/app_content_safe_area.dart';
import 'player_directory_screen.dart';

const _lime = Color(0xFFCCFF00);
const _cyan = Color(0xFF00E5FF);

String _dateLabel(String value) {
  if (value.isEmpty) return 'Data da definire';
  final parts = value.split('-');
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
String _formatLabel(String value) =>
    value == 'knockout' ? 'Eliminazione diretta' : 'Gironi';

/// Gestione offline dei tornei, gironi e tabelloni.
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});
  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    final data = await TournamentStore.load();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const TournamentEditorScreen()));
    if (saved == true) await _reload();
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TournamentDetailScreen(tournamentId: id)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tournaments = List<Map<String, dynamic>>.from(
      (_data?['tournaments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    tournaments.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
    return Scaffold(
      appBar: AppBar(title: const Text('Tornei')),
      floatingActionButton: _data == null ? null : FloatingActionButton.extended(
        onPressed: _create, icon: const Icon(Icons.add), label: const Text('Nuovo torneo')),
      body: AppContentSafeArea(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Padding(padding: EdgeInsets.all(24),
                  child: Text('Archivio tornei non leggibile. Non verrà sovrascritto.')))
              : tournaments.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                      mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.emoji_events_outlined, size: 70, color: _lime),
                        const SizedBox(height: 16),
                        const Text('Organizza il tuo primo torneo',
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text('Crea un torneo offline, iscrivi le coppie e genera gironi o tabellone.', textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Crea torneo')),
                      ])))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
                      const Text('I tornei restano sul dispositivo. Le iscrizioni sono indipendenti dai risultati già salvati.',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 16),
                      for (final tournament in tournaments)
                        Card(child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          leading: const Icon(Icons.emoji_events_outlined, color: _lime),
                          title: Text(tournament['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${tournament['draw'] == null ? 'Bozza' : 'Calendario creato'} · ${_formatLabel(tournament['format'] as String)}\n${(tournament['entries'] as List).length} coppie · ${_dateLabel(tournament['date'] as String)}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(tournament['id'] as String),
                        )),
                    ])),
    );
  }
}

class TournamentEditorScreen extends StatefulWidget {
  const TournamentEditorScreen({super.key, this.tournament});
  final Map<String, dynamic>? tournament;

  @override
  State<TournamentEditorScreen> createState() => _TournamentEditorScreenState();
}

class _TournamentEditorScreenState extends State<TournamentEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _venue;
  late String _format;
  String _date = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.tournament;
    _name = TextEditingController(text: current?['name'] as String? ?? '');
    _venue = TextEditingController(text: current?['venue'] as String? ?? '');
    _format = current?['format'] as String? ?? 'groups';
    _date = current?['date'] as String? ?? '';
  }

  @override
  void dispose() { _name.dispose(); _venue.dispose(); super.dispose(); }

  Future<void> _selectDate() async {
    final parsed = DateTime.tryParse(_date);
    final initial = parsed != null && parsed.year >= 1900 && parsed.year <= 2100
        ? parsed : DateTime.now();
    final chosen = await showDatePicker(context: context, initialDate: initial,
      firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (chosen != null && mounted) {
      setState(() => _date = '${chosen.year.toString().padLeft(4, '0')}-${chosen.month.toString().padLeft(2, '0')}-${chosen.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    final error = widget.tournament == null
      ? await TournamentStore.create(name: _name.text, format: _format,
          venue: _venue.text, date: _date)
      : await TournamentStore.update(id: widget.tournament!['id'] as String,
          name: _name.text, format: _format, venue: _venue.text, date: _date);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _saving = false; _error = error; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.tournament == null ? 'Crea torneo' : 'Modifica torneo')),
    body: AppContentSafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('DATI TORNEO', style: TextStyle(color: _lime, fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      TextField(controller: _name, maxLength: 60, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome torneo *', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _format, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Formula del torneo', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'groups', child: Text('Gironi')),
          DropdownMenuItem(value: 'knockout', child: Text('Eliminazione diretta')),
        ],
        onChanged: _saving || widget.tournament?['draw'] != null ? null : (value) => setState(() => _format = value ?? 'groups')),
      const SizedBox(height: 18),
      TextField(controller: _venue, maxLength: 100,
        decoration: const InputDecoration(labelText: 'Circolo / luogo (facoltativo)', border: OutlineInputBorder())),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _selectDate, icon: const Icon(Icons.event),
            label: Text(_dateLabel(_date)))),
        if (_date.isNotEmpty) IconButton(tooltip: 'Rimuovi data',
            onPressed: () => setState(() => _date = ''), icon: const Icon(Icons.clear)),
      ]),
      const SizedBox(height: 16),
      const Text('Dopo aver iscritto le coppie, genera il calendario nel dettaglio del torneo. La formula non può cambiare finché esiste il tabellone.',
          style: TextStyle(fontSize: 12)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 14),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Salvataggio…' : 'Salva torneo')),
    ])),
  );
}

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});
  final String tournamentId;
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  Map<String, dynamic>? _tournament;
  bool _loaded = false;
  bool _corrupted = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    final store = await TournamentStore.load();
    if (!mounted) return;
    final tournaments = store?['tournaments'] as List? ?? [];
    final found = tournaments.where((t) => t['id'] == widget.tournamentId);
    setState(() {
      _loaded = true;
      _corrupted = store == null;
      _tournament = found.isEmpty ? null : Map<String, dynamic>.from(found.first as Map);
    });
  }

  Future<void> _change(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    final result = await action();
    if (!mounted) return;
    setState(() { _busy = false; _error = result; });
    if (result == null) await _reload();
  }

  Future<void> _addPair() async {
    final data = await PlayerDirectoryStore.load();
    if (!mounted) return;
    if (data == null) {
      setState(() => _error = 'Rubrica non leggibile: impossibile iscrivere coppie.');
      return;
    }
    final entries = (_tournament?['entries'] as List? ?? []);
    final usedPlayers = <String>{};
    final usedPairs = <String>{};
    for (final entry in entries) {
      usedPairs.add(entry['pairId'] as String);
      usedPlayers.addAll(List<String>.from(entry['playerIds'] as List));
    }
    final players = {for (final p in data['players'] as List) p['id'] as String : p['name'] as String};
    final candidates = (data['pairs'] as List).where((p) =>
        !usedPairs.contains(p['id']) &&
        !(p['playerIds'] as List).any(usedPlayers.contains)).toList();
    if (candidates.isEmpty) {
      final gotoDirectory = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Nessuna coppia disponibile'),
        content: const Text('Crea una coppia nella rubrica, oppure libera giocatori già iscritti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Chiudi')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Apri rubrica')),
        ],
      ));
      if (gotoDirectory == true && mounted) {
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const PlayerDirectoryScreen()));
      }
      return;
    }
    final selected = await showModalBottomSheet<String>(context: context,
      isScrollControlled: true, showDragHandle: true, builder: (sheet) => SafeArea(
        child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 480),
          child: ListView(shrinkWrap: true, children: [
            const ListTile(title: Text('Iscrivi una coppia', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final pair in candidates)
              ListTile(leading: const Icon(Icons.groups_2_outlined, color: _cyan),
                title: Text(pair['name'] as String),
                subtitle: Text((pair['playerIds'] as List)
                    .map((id) => players[id] ?? 'Giocatore sconosciuto').join(' + ')),
                onTap: () => Navigator.pop(sheet, pair['id'] as String)),
          ]))),
      );
    if (selected != null && mounted) {
      await _change(() => TournamentStore.enroll(widget.tournamentId, selected));
    }
  }

  Future<void> _removePair(Map entry) async {
    final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Rimuovere la coppia?'),
      content: Text(entry['pairName'] as String),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Rimuovi'))],
    ));
    if (confirm == true && mounted) {
      await _change(() => TournamentStore.removeEntry(widget.tournamentId, entry['pairId'] as String));
    }
  }

  Future<void> _deleteTournament() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Eliminare il torneo?'),
      content: const Text('Il torneo e tutte le sue iscrizioni saranno eliminati. La rubrica dei giocatori non verrà modificata.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Elimina'))],
    ));
    if (confirmed != true || !mounted) return;
    final result = await TournamentStore.delete(widget.tournamentId);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result);
    }
  }

  Future<void> _generateDraw() async {
    final current = _tournament;
    if (current == null) return;
    var groupSize = 4;
    final chosen = await showDialog<int>(context: context, builder: (dialog) =>
      StatefulBuilder(builder: (dialog, update) => AlertDialog(
        title: Text(current['format'] == 'groups' ? 'Genera gironi' : 'Genera tabellone'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Le iscrizioni verranno bloccate. Puoi azzerare il calendario in seguito, perdendo tutti i risultati.'),
          if (current['format'] == 'groups') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: groupSize,
              decoration: const InputDecoration(labelText: 'Massimo coppie per girone'),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 coppie')),
                DropdownMenuItem(value: 4, child: Text('4 coppie')),
              ],
              onChanged: (value) => update(() => groupSize = value ?? 4),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialog, groupSize),
              child: const Text('Genera')),
        ],
      )),
    );
    if (chosen == null || !mounted) return;
    await _change(() => TournamentStore.generateDraw(widget.tournamentId, groupSize: chosen));
  }

  Future<void> _resetDraw() async {
    final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Azzerare il calendario?'),
      content: const Text('Tutti gli incontri, le classifiche e i risultati del torneo saranno eliminati. Le coppie iscritte resteranno.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Azzera')),
      ],
    ));
    if (confirm == true && mounted) {
      await _change(() => TournamentStore.resetDraw(widget.tournamentId));
    }
  }

  Future<void> _openDraw() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TournamentDrawScreen(tournamentId: widget.tournamentId),
    ));
    await _reload();
  }

  Future<void> _editTournament() async {
    final current = _tournament;
    if (current == null) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TournamentEditorScreen(tournament: current)));
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final current = _tournament;
    final entries = current?['entries'] as List? ?? [];
    final draw = current?['draw'] as Map?;
    final champion = draw == null ? null : TournamentDraw.champion(draw);
    return Scaffold(
      appBar: AppBar(title: const Text('Dettagli torneo'), actions: [
        if (current != null) PopupMenuButton<String>(onSelected: (action) {
          if (action == 'edit') _editTournament();
          if (action == 'delete') _deleteTournament();
        }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Modifica torneo')),
          PopupMenuItem(value: 'delete', child: Text('Elimina torneo')),
        ]),
      ]),
      body: AppContentSafeArea(child: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : current == null
          ? Center(child: Text(_corrupted ? 'Archivio tornei non leggibile.' : 'Torneo non trovato.'))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 40), children: [
            const Icon(Icons.emoji_events, size: 54, color: _lime),
            const SizedBox(height: 8),
            Center(child: Chip(label: Text(draw == null ? 'BOZZA' : champion == null ? 'CALENDARIO ATTIVO' : 'TORNEO CONCLUSO'))),
            Text(current['name'] as String, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text('${_formatLabel(current['format'] as String)} · ${_dateLabel(current['date'] as String)}',
              textAlign: TextAlign.center),
            if ((current['venue'] as String).isNotEmpty)
              Text(current['venue'] as String, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('ISCRIZIONI', style: TextStyle(fontWeight: FontWeight.bold, color: _lime)),
                Text('${entries.length} / ${TournamentStore.maxPairsPerTournament} coppie'),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: entries.length / TournamentStore.maxPairsPerTournament,
                  minHeight: 7, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 12),
              Text(entries.length < 2
                ? 'Servono almeno due coppie per creare gli incontri.'
                : draw == null ? 'Iscrizioni pronte: genera il calendario.' : 'Iscrizioni bloccate finché è attivo il calendario.'),
            ]))),
            if (_error != null) Padding(padding: const EdgeInsets.all(10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _busy || draw != null || entries.length >= TournamentStore.maxPairsPerTournament ? null : _addPair,
              icon: const Icon(Icons.person_add_alt_1), label: const Text('Iscrivi coppia')),
            OutlinedButton.icon(onPressed: _busy ? null : () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => const PlayerDirectoryScreen()));
            }, icon: const Icon(Icons.groups_2_outlined), label: const Text('Gestisci rubrica coppie')),
            const SizedBox(height: 14),
            if (entries.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Nessuna coppia iscritta. Aggiungi le coppie dalla rubrica.', textAlign: TextAlign.center)),
            for (var i = 0; i < entries.length; i++)
              Card(child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(entries[i]['pairName'] as String),
                subtitle: Text((entries[i]['playerNames'] as List).join(' + ')),
                trailing: IconButton(tooltip: 'Rimuovi coppia', onPressed: _busy || draw != null ? null : () => _removePair(entries[i] as Map),
                  icon: const Icon(Icons.close)),
              )),
            const SizedBox(height: 20),
            const Divider(),
            if (draw == null)
              FilledButton.icon(
                onPressed: _busy || entries.length < 2 ? null : _generateDraw,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(current['format'] == 'groups' ? 'Genera gironi e calendario' : 'Genera tabellone'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _openDraw,
                icon: const Icon(Icons.emoji_events_outlined),
                label: Text(current['format'] == 'groups' ? 'Apri gironi e classifiche' : 'Apri tabellone'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _busy ? null : _resetDraw,
                icon: const Icon(Icons.restart_alt), label: const Text('Azzera calendario')),
            ],
          ])),
    );
  }
}
