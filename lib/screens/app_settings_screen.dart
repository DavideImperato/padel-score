import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_preferences.dart';
import '../providers/padel_score_provider.dart';
import '../widgets/watch_link_card.dart';
import '../widgets/app_about_footer.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _name = TextEditingController();
  @override
  void initState() {
    super.initState();
    _name.text = context.read<AppPreferences>().name;
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final dark = prefs.darkMode;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF091326) : const Color(0xFFF1F5FA),
      appBar: AppBar(title: const Text('Impostazioni')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('IL TUO PROFILO', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nome',
              suffixIcon: IconButton(tooltip: 'Salva nome', icon: const Icon(Icons.check),
                onPressed: () async {
                  final ok = await prefs.changeName(_name.text);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                    ok ? 'Nome aggiornato.' : 'Inserisci un nome valido (massimo 40 caratteri).')));
                }),
            ),
          ),
          const SizedBox(height: 12),
          const Text('ASPETTO', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile.adaptive(
            title: const Text('Tema scuro'),
            subtitle: const Text('Per Home e Impostazioni. Il tabellone mantiene il contrasto sportivo.'),
            value: prefs.darkMode,
            onChanged: prefs.setDarkMode,
          ),
          const Divider(),
          const Text('AUDIO', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile.adaptive(
            title: const Text('Annunci vocali'),
            subtitle: const Text('Voce arbitrale in italiano'),
            value: !context.watch<PadelScoreProvider>().isMuted,
            onChanged: (enabled) async {
              final provider = context.read<PadelScoreProvider>();
              if (provider.isMuted == enabled) provider.toggleMute();
              await prefs.setVoiceEnabled(enabled);
            },
          ),
          const Divider(height: 26),
          const Text('APPLE WATCH', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xFFCAFF00)),
            ),
            child: const WatchLinkCard(),
          ),
          const SizedBox(height: 9),
          Text('L’abbinamento del Watch si effettua dall’app Watch di iPhone; qui puoi verificare la connessione.',
            style: TextStyle(fontSize: 12,
              color: dark ? const Color(0xFFB6C2D6) : const Color(0xFF546578))),
          const Divider(height: 32),
          const Text('INFORMAZIONI', style: TextStyle(fontWeight: FontWeight.bold)),
          const ListTile(leading: Icon(Icons.info_outline),
            title: Text('Padel Score Board'),
            subtitle: Text('Segnapunti offline per iPhone, iPad e Apple Watch')),
          const SizedBox(height: 6),
          const AppAboutFooter(),
          const SizedBox(height: 10),
          const ListTile(leading: Icon(Icons.star_border),
            title: Text('Lascia una recensione sull’App Store'),
            subtitle: Text('Il collegamento sarà attivato con l’ID pubblico dell’app.'),
            enabled: false),
          const SizedBox(height: 16),
        ]),
      ))),
    );
  }
}
