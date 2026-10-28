/// Calendari e tabelloni offline. Dati deterministici: nessun server o
/// dipendenza dal motore punteggio. I nomi delle coppie restano snapshot 6A.
class TournamentDraw {
  static const maxPairs = 32;

  static List<String> pairIds(Map<String, dynamic> tournament) =>
      (tournament['entries'] as List)
          .map((e) => (e as Map)['pairId'] as String).toList();

  static Map<String, dynamic> create(Map<String, dynamic> tournament,
      {int groupSize = 4, int? timestamp}) => fresh(tournament,
          groupSize: groupSize, timestamp: timestamp);

  static Map<String, dynamic> _match(String id, String? groupId,
      int round, int slot, String? home, String? away) => {
    'id': id, 'groupId': groupId, 'round': round, 'slot': slot,
    'homeId': home, 'awayId': away, 'result': null,
  };

  /// Una partita è al meglio dei tre set (2-0 o 2-1).
  /// I parziali possono includere 7-6, mini-set o match tie-break 10-8.
  /// Una coppia non può vincere due set se l'altra ne ha già vinti due.
  static bool validResult(dynamic value) {
    if (value is! Map || value.length != 1 || value['sets'] is! List) return false;
    final sets = value['sets'] as List;
    if (sets.length < 2 || sets.length > 3) return false;
    var home = 0;
    var away = 0;
    for (final set in sets) {
      if (set is! List || set.length != 2 ||
          set[0] is! int || set[1] is! int) return false;
      final a = set[0] as int;
      final b = set[1] as int;
      if (a < 0 || b < 0 || a > 30 || b > 30 || a == b) return false;
      final high = a > b ? a : b;
      final low = a > b ? b : a;
      // Set tradizionale, mini-set a quattro game o deciding tie-break.
      final standard = (high == 6 && low <= 4) ||
          (high == 7 && (low == 5 || low == 6));
      final mini = (high == 4 && low <= 2) || (high == 5 && (low == 3 || low == 4));
      final deciding = high >= 10 && high - low >= 2 && sets.length == 3 &&
          identical(set, sets.last);
      if (!standard && !mini && !deciding) return false;
      if (a > b) { home++; } else { away++; }
      if (home == 2 || away == 2) {
        if (!identical(set, sets.last)) return false;
      }
    }
    return (home == 2 && away <= 1) || (away == 2 && home <= 1);
  }

  static String? winner(Map match) {
    final result = match['result'];
    if (!validResult(result)) return null;
    final sets = result['sets'] as List;
    final winsHome = sets.where((s) => (s as List)[0] > s[1]).length;
    return winsHome == 2 ? match['homeId'] as String? : match['awayId'] as String?;
  }

  static bool isBye(Map match) => match['round'] == 1 &&
      ((match['homeId'] == null) != (match['awayId'] == null)) &&
      (match['groupId'] == null);

  static String? advancing(Map match) => isBye(match)
      ? (match['homeId'] ?? match['awayId']) as String? : winner(match);

  /// Ricostruisce sempre il tabellone dai seed originali. Conserva un
  /// risultato soltanto se entrambe le coppie coincidono con lo slot attuale.
  /// Cambiare un risultato precedente invalida automaticamente il seguito.
  static Map<String, dynamic> rebuild(Map<String, dynamic> tournament, Map raw) {
    final isGroups = tournament['format'] == 'groups';
    final groupSize = raw['groupSize'];
    if (raw['version'] != 1 || raw['createdAt'] is! int ||
        (raw['createdAt'] as int) <= 0 || groupSize is! int ||
        (isGroups ? (groupSize != 3 && groupSize != 4) : groupSize != 0) ||
        raw['matches'] is! List) {
      throw const FormatException('Tabellone non valido.');
    }
    // Rebuild dei seed, senza usare il vecchio calendario come sorgente.
    final base = _seeds(tournament, groupSize: groupSize);
    final old = <String, Map>{};
    for (final candidate in raw['matches'] as List) {
      if (candidate is! Map || candidate['id'] is! String ||
          old.containsKey(candidate['id'])) throw const FormatException('Incontri duplicati.');
      old[candidate['id'] as String] = candidate;
    }
    final matches = base['matches'] as List;
    if (old.length != matches.length) throw const FormatException('Calendario incompleto.');
    final indexed = <String, Map>{
      for (final m in matches) (m as Map)['id'] as String: m,
    };
    for (final match in matches) {
      final record = match as Map;
      final id = record['id'] as String;
      final previous = old[id];
      if (previous == null) throw const FormatException('Incontro mancante.');
      final samePlayers = previous['homeId'] == record['homeId'] &&
          previous['awayId'] == record['awayId'];
      if (samePlayers && previous['result'] != null) {
        if (!validResult(previous['result']) || record['homeId'] == null ||
            record['awayId'] == null) {
          throw const FormatException('Risultato non valido.');
        }
        record['result'] = previous['result'];
      }
      if (!isGroups) {
        final winnerId = advancing(record);
        if (winnerId != null) {
          final nextId = 'K_R${(record['round'] as int) + 1}_M${(record['slot'] as int) ~/ 2 + 1}';
          final next = indexed[nextId];
          if (next != null) {
            next[(record['slot'] as int).isEven ? 'homeId' : 'awayId'] = winnerId;
          }
        }
      }
    }
    base['createdAt'] = raw['createdAt'];
    return base;
  }

  // Generazione priva di richiamo ricorsivo a rebuild().
  static Map<String, dynamic> _seeds(Map<String, dynamic> tournament,
      {required int groupSize}) {
    final pairs = pairIds(tournament);
    final isGroups = tournament['format'] == 'groups';
    final groups = <Map<String, dynamic>>[];
    final matches = <Map<String, dynamic>>[];
    if (isGroups) {
      final count = (pairs.length + groupSize - 1) ~/ groupSize;
      final buckets = List.generate(count, (_) => <String>[]);
      for (var i = 0; i < pairs.length; i++) {
        final j = i % (count * 2);
        buckets[j < count ? j : count * 2 - 1 - j].add(pairs[i]);
      }
      for (var g = 0; g < buckets.length; g++) {
        final gid = 'G${g + 1}';
        groups.add({'id': gid, 'pairIds': buckets[g]});
        final teams = <String?>[...buckets[g]];
        if (teams.length.isOdd) teams.add(null);
        for (var round = 1; round < teams.length; round++) {
          var slot = 0;
          for (var i = 0; i < teams.length ~/ 2; i++) {
            final a = teams[i]; final b = teams[teams.length - i - 1];
            if (a != null && b != null) {
              matches.add(_match('${gid}_R${round}_M${slot + 1}', gid,
                  round, slot++, a, b));
            }
          }
          teams.insert(1, teams.removeLast());
        }
      }
    } else {
      var size = 2;
      while (size < pairs.length) size *= 2;
      var seeds = <int>[1, 2];
      while (seeds.length < size) {
        final complement = seeds.length * 2 + 1;
        seeds = [for (final s in seeds) ...[s, complement - s]];
      }
      final seeded = <String?>[for (final s in seeds) s <= pairs.length ? pairs[s - 1] : null];
      for (var width = size, round = 1; width >= 2; width ~/= 2, round++) {
        for (var slot = 0; slot < width ~/ 2; slot++) {
          matches.add(_match('K_R${round}_M${slot + 1}', null, round, slot,
              round == 1 ? seeded[slot * 2] : null,
              round == 1 ? seeded[slot * 2 + 1] : null));
        }
      }
    }
    return {'version': 1, 'createdAt': 1,
      'groupSize': isGroups ? groupSize : 0, 'groups': groups, 'matches': matches};
  }

  static Map<String, dynamic> fresh(Map<String, dynamic> tournament,
      {int groupSize = 4, int? timestamp}) {
    final n = pairIds(tournament).length;
    if (n < 2 || n > maxPairs) throw const FormatException('Servono da 2 a 32 coppie.');
    if (!{'groups', 'knockout'}.contains(tournament['format'])) {
      throw const FormatException('Formato sconosciuto.');
    }
    if (tournament['format'] == 'groups' && groupSize != 3 && groupSize != 4) {
      throw const FormatException('Gironi non validi.');
    }
    final draw = _seeds(tournament, groupSize: groupSize);
    draw['createdAt'] = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return rebuild(tournament, draw);
  }

  static Map<String, dynamic> withResult(Map<String, dynamic> tournament,
      Map draw, String matchId, List<List<int>>? sets) {
    final matches = draw['matches'] as List;
    final index = matches.indexWhere((m) => m['id'] == matchId);
    if (index < 0) throw const FormatException('Incontro non trovato.');
    final match = matches[index] as Map;
    if (match['homeId'] == null || match['awayId'] == null) {
      throw const FormatException('Le due coppie non sono ancora definite.');
    }
    if (sets != null && !validResult({'sets': sets})) {
      throw const FormatException('Risultato non valido (servono 2 set vinti).');
    }
    // Evita di mutare il tabellone originale se l'operazione fallisce.
    final updated = <String, dynamic>{...draw,
      'matches': [for (final m in matches)
        if (m['id'] == matchId) {...(m as Map), 'result': sets == null ? null : {'sets': sets}}
        else {...(m as Map)}],
    };
    return rebuild(tournament, updated);
  }

  static Map<String, dynamic> standing(Map group, Map draw) {
    final ids = List<String>.from(group['pairIds'] as List);
    final rows = <String, Map<String, dynamic>>{
      for (final id in ids) id: {
        'pairId': id, 'played': 0, 'wins': 0, 'losses': 0,
        'points': 0, 'setsFor': 0, 'setsAgainst': 0,
        'gamesFor': 0, 'gamesAgainst': 0,
      },
    };
    for (final raw in draw['matches'] as List) {
      final match = raw as Map;
      if (match['groupId'] != group['id'] || match['result'] == null) continue;
      final home = rows[match['homeId']]!;
      final away = rows[match['awayId']]!;
      home['played'] = (home['played'] as int) + 1;
      away['played'] = (away['played'] as int) + 1;
      final victor = winner(match);
      for (final row in [home, away]) {
        final won = row == home ? victor == match['homeId'] : victor == match['awayId'];
        row[won ? 'wins' : 'losses'] = (row[won ? 'wins' : 'losses'] as int) + 1;
        if (won) row['points'] = (row['points'] as int) + 3;
      }
      for (final set in (match['result']['sets'] as List)) {
        final a = set[0] as int; final b = set[1] as int;
        home['gamesFor'] = (home['gamesFor'] as int) + a;
        home['gamesAgainst'] = (home['gamesAgainst'] as int) + b;
        away['gamesFor'] = (away['gamesFor'] as int) + b;
        away['gamesAgainst'] = (away['gamesAgainst'] as int) + a;
        final homeWon = a > b;
        home[homeWon ? 'setsFor' : 'setsAgainst'] =
            (home[homeWon ? 'setsFor' : 'setsAgainst'] as int) + 1;
        away[homeWon ? 'setsAgainst' : 'setsFor'] =
            (away[homeWon ? 'setsAgainst' : 'setsFor'] as int) + 1;
      }
    }
    final ranking = rows.values.toList();
    ranking.sort((a, b) {
      int compare(int x, int y) => y.compareTo(x);
      var diff = compare(a['points'] as int, b['points'] as int);
      if (diff != 0) return diff;
      diff = compare((a['setsFor'] as int) - (a['setsAgainst'] as int),
          (b['setsFor'] as int) - (b['setsAgainst'] as int));
      if (diff != 0) return diff;
      diff = compare((a['gamesFor'] as int) - (a['gamesAgainst'] as int),
          (b['gamesFor'] as int) - (b['gamesAgainst'] as int));
      if (diff != 0) return diff;
      return ids.indexOf(a['pairId']).compareTo(ids.indexOf(b['pairId']));
    });
    return {'groupId': group['id'], 'rows': ranking};
  }

  static String? champion(Map draw) {
    final matches = draw['matches'] as List;
    if (matches.isEmpty || draw['groupSize'] != 0) return null;
    return winner(matches.last as Map);
  }
}
