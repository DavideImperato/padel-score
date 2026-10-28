import 'package:flutter/material.dart';

/// Impaginazione del segnapunti adattiva alla dimensione reale della finestra.
///
/// Su iPadOS 26 in modalità "App in finestre" il sistema può negare la
/// rotazione richiesta: in quel caso le squadre restano sempre utilizzabili.
/// In una finestra larga (e su iPhone landscape) rimangono affiancate.
class ScoreboardTeamLayout extends StatelessWidget {
  const ScoreboardTeamLayout({
    super.key,
    required this.teamA,
    required this.teamB,
    this.swapSides = false,
  });

  final Widget teamA;
  final Widget teamB;
  final bool swapSides;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxHeight > constraints.maxWidth;
        final first = swapSides ? teamB : teamA;
        final second = swapSides ? teamA : teamB;
        final divider = ColoredBox(
          color: const Color(0xFF1E293B),
          child: SizedBox(
            width: stack ? double.infinity : 3,
            height: stack ? 3 : double.infinity,
          ),
        );
        final children = <Widget>[
          Expanded(child: first),
          divider,
          Expanded(child: second),
        ];
        return stack
            ? Column(children: children)
            : Row(children: children);
      },
    );
  }
}
