import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../services/match_result_share.dart';

/// Card in stile Padel Score Board: il nome è già presente nell'immagine del logo.
class MatchResultSocialCard extends StatelessWidget {
  final MatchResultShare result;
  const MatchResultSocialCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF071326);
    const lime = Color(0xFFD5FF00);
    const cyan = Color(0xFF00DDF2);
    return SizedBox(
      width: 320,
      height: 416,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: navy),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 14, 19, 14),
          child: Column(children: [
            Image.asset('assets/icon.png', width: 86, height: 86, fit: BoxFit.contain),
            const SizedBox(height: 8),
            const Text('RISULTATO FINALE', style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text('🏆 ${result.winner}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: lime, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _team(result.teamA, result.playerLineA,
                  result.wonSetsA, lime)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 7),
                child: Text('VS', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700))),
              Expanded(child: _team(result.teamB, result.playerLineB,
                  result.wonSetsB, cyan)),
            ]),
            const SizedBox(height: 13),
            Flexible(child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final line in result.setLines)
                Padding(padding: const EdgeInsets.only(bottom: 3),
                  child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ])),
            const Spacer(),
            Container(height: 1, color: const Color(0xFF2A3A53)),
            const SizedBox(height: 7),
            Text('${result.dateLabel}  •  ${result.durationLabel}',
              style: const TextStyle(color: Color(0xFFAAB6C8), fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _team(String name, String players, int sets, Color color) {
    return Column(children: [
      Text(name.toUpperCase(), maxLines: 2, textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(players, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60, fontSize: 9)),
      const SizedBox(height: 8),
      Text('$sets', style: const TextStyle(color: Colors.white,
        fontSize: 62, height: 1, fontWeight: FontWeight.w900)),
      const Text('SET', style: TextStyle(color: Colors.white54, fontSize: 9)),
    ]);
  }
}

/// Anteprima visibile: renderizza solo la card, non pulsanti o dati privati extra.
class MatchResultShareSheet {
  static Future<void> show(BuildContext context, Map<String, dynamic> record) async {
    MatchResultShare result;
    try {
      result = MatchResultShare.fromRecord(record);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)));
      }
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final availableHeight = size.height - MediaQuery.paddingOf(context).vertical - 42;
    final displayWidth = math.min(320.0, math.max(145.0, (availableHeight - 88) / 1.30));
    final previewKey = GlobalKey();
    var isSharing = false;

    await showDialog<void>(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (dialogContext, updateState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        backgroundColor: const Color(0xFF14223B),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
              key: previewKey,
              child: SizedBox(
                width: displayWidth,
                height: displayWidth * 1.30,
                child: FittedBox(fit: BoxFit.contain,
                  child: MatchResultSocialCard(result: result)),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: isSharing ? null : () => Navigator.pop(dialogContext),
                child: const Text('Chiudi')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.share_outlined, size: 17),
                label: Text(isSharing ? 'Preparazione…' : 'Condividi'),
                onPressed: isSharing ? null : () async {
                  updateState(() => isSharing = true);
                  try {
                    // Aspetta che il logo e la card siano stati dipinti.
                    await WidgetsBinding.instance.endOfFrame;
                    final boundary = previewKey.currentContext?.findRenderObject();
                    if (boundary is! RenderRepaintBoundary) {
                      throw StateError('Anteprima non disponibile');
                    }
                    final image = await boundary.toImage(pixelRatio: 1080 / displayWidth);
                    final data = await image.toByteData(format: ui.ImageByteFormat.png);
                    image.dispose();
                    if (data == null) throw StateError('Impossibile generare il PNG');
                    final Uint8List png = data.buffer.asUint8List();
                    if (!dialogContext.mounted) return;
                    final dialogBox = dialogContext.findRenderObject();
                    final origin = dialogBox is RenderBox
                        ? dialogBox.localToGlobal(Offset.zero) & dialogBox.size
                        : const Rect.fromLTWH(0, 0, 1, 1);
                    await SharePlus.instance.share(ShareParams(
                      files: [XFile.fromData(png, mimeType: 'image/png',
                        name: 'padel-score-board-risultato.png')],
                      fileNameOverrides: const ['padel-score-board-risultato.png'],
                      sharePositionOrigin: origin,
                    ));
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Condivisione non riuscita: $error')));
                    }
                  } finally {
                    if (dialogContext.mounted) updateState(() => isSharing = false);
                  }
                },
              ),
            ]),
          ]),
        ),
      ));
    });
  }
}
