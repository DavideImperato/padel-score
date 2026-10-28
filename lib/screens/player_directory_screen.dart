import 'package:flutter/material.dart';
import '../widgets/app_content_safe_area.dart';
import '../services/player_directory.dart';

class PlayerDirectoryScreen extends StatefulWidget {
  const PlayerDirectoryScreen({super.key});
  @override
  State<PlayerDirectoryScreen> createState() => _PlayerDirectoryScreenState();
}

class _PlayerDirectoryScreenState extends State<PlayerDirectoryScreen> {
  Map<String, dynamic>? _data;
  bool _loaded = false;
  String? _error;
  final _name = TextEditingController();
  final _pairName = TextEditingController();
  String? _first;
  String? _second;

  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _name.dispose(); _pairName.dispose(); super.dispose(); }

  Future<void> _reload() async {
    final data = await PlayerDirectoryStore.load();
    if (mounted) setState(() { _data = data; _loaded = true; });
  }
  Future<void> _run(Future<String?> Function() action) async {
    final error = await action();
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) await _reload();
  }
  Future<String?> _askName(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: controller, autofocus: true, maxLength: 60),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salva'))]));
    controller.dispose();
    return value;
  }
  Future<bool> _confirm(String label) async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text('Eliminare $label?'), content: const Text('Le partite già archiviate manterranno i loro risultati.'),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina'))])) ?? false;

  @override
  Widget build(BuildContext context) {
    final players = (_data?['players'] as List? ?? []);
    final pairs = (_data?['pairs'] as List? ?? []);
    final validIds = players.map((p) => p['id']).toSet();
    if (!validIds.contains(_first)) _first = null;
    if (!validIds.contains(_second)) _second = null;
    return Scaffold(appBar: AppBar(title: const Text('Giocatori e coppie')), body: AppContentSafeArea(child: !_loaded
      ? const Center(child: CircularProgressIndicator())
      : _data == null ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Archivio non leggibile. Non verrà sovrascritto.')))
      : ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Rubrica offline. Le modifiche ai nomi non alterano le partite già concluse.', style: TextStyle(color: Colors.white70)),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 15),
          Text('GIOCATORI (${players.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCCFF00))),
          Row(children: [Expanded(child: TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(labelText: 'Nome giocatore'))),
            ElevatedButton(onPressed: () async { await _run(() => PlayerDirectoryStore.addPlayer(_name.text)); if (_error == null) _name.clear(); }, child: const Text('Aggiungi'))]),
          ...players.map((p) => ListTile(title: Text(p['name'] as String), trailing: Wrap(spacing: 8, children: [
            IconButton(tooltip: 'Rinomina', onPressed: () async { final v = await _askName('Rinomina giocatore', p['name'] as String); if (v != null) await _run(() => PlayerDirectoryStore.renamePlayer(p['id'] as String, v)); }, icon: const Icon(Icons.edit)),
            IconButton(tooltip: 'Elimina', onPressed: () async { if (await _confirm(p['name'] as String)) await _run(() => PlayerDirectoryStore.removePlayer(p['id'] as String)); }, icon: const Icon(Icons.delete_outline)),
          ]))),
          const Divider(height: 32),
          Text('COPPIE (${pairs.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
          TextField(controller: _pairName, maxLength: 60, decoration: const InputDecoration(labelText: 'Nome coppia')),
          Row(children: [Expanded(child: DropdownButton<String>(isExpanded: true, value: _first, hint: const Text('Primo giocatore'), items: players.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String))).toList(), onChanged: (value) => setState(() => _first = value))),
            const SizedBox(width: 15),
            Expanded(child: DropdownButton<String>(isExpanded: true, value: _second, hint: const Text('Secondo giocatore'), items: players.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String))).toList(), onChanged: (value) => setState(() => _second = value))) ]),
          ElevatedButton(onPressed: () async { await _run(() => PlayerDirectoryStore.addPair(_pairName.text, _first ?? '', _second ?? '')); if (_error == null) { _pairName.clear(); setState(() { _first = null; _second = null; }); } }, child: const Text('Salva coppia')),
          ...pairs.map((p) => ListTile(title: Text(p['name'] as String), subtitle: Text((p['playerIds'] as List).map((id) => players.firstWhere((player) => player['id'] == id)['name']).join(' + ')), trailing: IconButton(tooltip: 'Elimina coppia', onPressed: () async { if (await _confirm(p['name'] as String)) await _run(() => PlayerDirectoryStore.removePair(p['id'] as String)); }, icon: const Icon(Icons.delete_outline)))),
        ])));
  }
}
