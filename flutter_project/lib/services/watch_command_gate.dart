import 'dart:async';

/// Serializza i comandi watchOS e memorizza gli esiti per commandId.
/// I comandi duplicati non possono modificare due volte il punteggio.
class WatchCommandGate {
  static const _actions = <String>{
    'point_a', 'point_b', 'undo', 'start_match',
    'pause_match', 'resume_match', 'end_match',
    'switch_sides', 'change_server', 'rule_golden', 'rule_star',
    'rule_one_advantage', 'rule_traditional',
  };

  Future<void> _tail = Future<void>.value();
  final Map<String, Map<String, dynamic>> _completed = {};

  Future<Map<String, dynamic>> accept(
    Map<dynamic, dynamic> raw, {
    required String Function() currentMatchId,
    required Future<Map<String, dynamic>> Function(String action) execute,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      final id = raw['commandId'];
      final matchId = raw['matchId'];
      final action = raw['action'];
      if (id is! String || id.isEmpty || id.length > 128 ||
          matchId is! String || matchId.isEmpty || matchId.length > 128 ||
          action is! String || !_actions.contains(action)) {
        completer.complete({'ok': false, 'code': 'invalid_command'});
        return;
      }
      final previous = _completed[id];
      if (previous != null) {
        completer.complete({...previous, 'duplicate': true});
        return;
      }
      Map<String, dynamic> result;
      if (matchId != currentMatchId()) {
        result = {'ok': false, 'code': 'stale_match'};
      } else {
        try {
          result = await execute(action);
        } catch (_) {
          result = {'ok': false, 'code': 'execution_failed'};
        }
      }
      final answer = <String, dynamic>{'commandId': id, ...result};
      _completed[id] = answer;
      // Mantiene limitata la memoria anche con migliaia di tap.
      if (_completed.length > 256) _completed.remove(_completed.keys.first);
      completer.complete(answer);
    }).catchError((Object _) {
      if (!completer.isCompleted) {
        completer.complete({'ok': false, 'code': 'internal_error'});
      }
    });
    return completer.future;
  }
}
