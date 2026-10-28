import 'package:flutter/material.dart';

/// Mantiene i contenuti delle schermate di gestione fuori dalle aree
/// occupate da Dynamic Island, notch, angoli arrotondati e Home Indicator.
///
/// Il tabellone di gioco resta deliberatamente a tutto schermo: questa
/// protezione è destinata a setup, rubrica, storico e statistiche.
class AppContentSafeArea extends StatelessWidget {
  const AppContentSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // In modalità immersiveSticky padding può essere ridotto anche quando
    // il ritaglio hardware rimane: viewPadding conserva gli inset del device.
    final physicalSafeArea = MediaQuery.viewPaddingOf(context);

    return SafeArea(
      minimum: EdgeInsets.only(
        left: physicalSafeArea.left,
        right: physicalSafeArea.right,
      ),
      child: child,
    );
  }
}
