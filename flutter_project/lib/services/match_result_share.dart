/// Modello di sola lettura per una card social basata su una partita conclusa.
/// Non altera lo storico e non deduce un vincitore da partite interrotte.
class MatchResultShare {
  final String teamA;
  final String teamB;
  final String winner;
  final String playerLineA;
  final String playerLineB;
  final int wonSetsA;
  final int wonSetsB;
  final List<String> setLines;
  final String dateLabel;
  final String durationLabel;

  const MatchResultShare({
    required this.teamA,
    required this.teamB,
    required this.winner,
    required this.playerLineA,
    required this.playerLineB,
    required this.wonSetsA,
    required this.wonSetsB,
    required this.setLines,
    required this.dateLabel,
    required this.durationLabel,
  });

  static MatchResultShare fromRecord(Map<String, dynamic> record) {
    final who = record['winner'];
    if (who != 'teamA' && who != 'teamB') {
      throw const FormatException('Si possono condividere solo risultati conclusi.');
    }
    final rawSets = record['sets'];
    if (rawSets is! List || rawSets.isEmpty) {
      throw const FormatException('Il risultato non contiene set validi.');
    }
    final teamA = record['teamAName'];
    final teamB = record['teamBName'];
    if (teamA is! String || teamB is! String) {
      throw const FormatException('Nomi delle squadre mancanti.');
    }
    final playerNames = record['players'];
    if (playerNames is! List || playerNames.length != 4 ||
        !playerNames.every((n) => n is String)) {
      throw const FormatException('Giocatori non validi.');
    }

    int wonA = 0;
    int wonB = 0;
    final lines = <String>[];
    for (var i = 0; i < rawSets.length; i++) {
      final source = rawSets[i];
      if (source is! Map) throw const FormatException('Set non valido.');
      final set = Map<String, dynamic>.from(source);
      final winner = set['winner'];
      if (winner == 'teamA') {
        wonA++;
      } else if (winner == 'teamB') {
        wonB++;
      } else {
        throw const FormatException('Set incompleto.');
      }
      final gamesA = set['gamesA'];
      final gamesB = set['gamesB'];
      if (gamesA is! int || gamesB is! int) {
        throw const FormatException('Punteggio del set non valido.');
      }
      final tbA = set['tieBreakPointsA'];
      final tbB = set['tieBreakPointsB'];
      final isMatchTb = set['isMatchTieBreak'] == true;
      if (isMatchTb && (tbA is! int || tbB is! int)) {
        throw const FormatException('Match tie-break incompleto.');
      }
      final score = isMatchTb
          ? 'MTB $tbA–$tbB'
          : '$gamesA–$gamesB${tbA is int && tbB is int ? ' (TB $tbA–$tbB)' : ''}';
      lines.add('SET ${i + 1}   $score');
    }
    final timestamp = record['completedAt'];
    final duration = record['durationSeconds'];
    if (timestamp is! int || timestamp < 0 || duration is! int || duration < 0) {
      throw const FormatException('Data o durata non valida.');
    }
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final hh = duration ~/ 3600;
    final mm = (duration % 3600) ~/ 60;
    final ss = duration % 60;
    final durationString = hh > 0
        ? '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}'
        : '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    return MatchResultShare(
      teamA: teamA.trim().isEmpty ? 'Squadra A' : teamA,
      teamB: teamB.trim().isEmpty ? 'Squadra B' : teamB,
      winner: who == 'teamA' ? teamA : teamB,
      playerLineA: '${playerNames[0]} / ${playerNames[1]}',
      playerLineB: '${playerNames[2]} / ${playerNames[3]}',
      wonSetsA: wonA,
      wonSetsB: wonB,
      setLines: List.unmodifiable(lines),
      dateLabel: date,
      durationLabel: durationString,
    );
  }

  String get accessibleSummary => '$teamA contro $teamB: $wonSetsA a $wonSetsB set. Vince $winner.';
}
