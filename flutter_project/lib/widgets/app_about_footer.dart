import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Informazioni centralizzate, condivise da Home e Impostazioni.
/// Legge la versione del pacchetto installato, non una stringa scritta a mano.
class AppAboutFooter extends StatefulWidget {
  const AppAboutFooter({
    super.key,
    this.versionLoader,
    this.onOpenDeveloper,
  });

  /// Parametri facoltativi per verificare il widget senza plugin nativi nei test.
  final Future<String> Function()? versionLoader;
  final Future<bool> Function(Uri)? onOpenDeveloper;

  static final Uri developerUrl = Uri.parse('https://davideimperato.it/');

  @override
  State<AppAboutFooter> createState() => _AppAboutFooterState();
}

class _AppAboutFooterState extends State<AppAboutFooter> {
  late Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersion();
  }

  Future<String> _loadVersion() async {
    if (widget.versionLoader != null) return widget.versionLoader!();
    try {
      final info = await PackageInfo.fromPlatform();
      final name = info.version.trim();
      final build = info.buildNumber.trim();
      if (name.isEmpty) return 'non disponibile';
      return build.isEmpty ? name : '$name ($build)';
    } catch (_) {
      return 'non disponibile';
    }
  }

  Future<void> _openDeveloperWebsite() async {
    var launched = false;
    try {
      launched = await (widget.onOpenDeveloper?.call(AppAboutFooter.developerUrl) ??
          launchUrl(AppAboutFooter.developerUrl, mode: LaunchMode.externalApplication));
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il sito dello sviluppatore.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? const Color(0xFFB6C2D6) : const Color(0xFF506078);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Divider(color: secondary.withValues(alpha: .22)),
        const SizedBox(height: 7),
        FutureBuilder<String>(
          future: _versionFuture,
          builder: (context, snapshot) => Text(
            'Versione ${snapshot.data ?? '…'}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ),
        const SizedBox(height: 3),
        TextButton.icon(
          onPressed: _openDeveloperWebsite,
          icon: Icon(Icons.open_in_new, size: 14, color: secondary),
          label: Text('Sviluppatore: Davide Imperato',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondary,
              decoration: TextDecoration.underline,
              decorationColor: secondary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(48, 44),
          ),
        ),
      ],
    );
  }
}
