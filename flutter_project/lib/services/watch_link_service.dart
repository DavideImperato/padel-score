import 'package:flutter/services.dart';

/// Stato di connessione watchOS. `reachable` indica disponibilità per messaggi
/// in tempo reale: NON garantisce una connessione costante in background.
class WatchLinkStatus {
  final bool supported;
  final bool activated;
  final bool paired;
  final bool installed;
  final bool reachable;
  final DateTime? lastWatchPing;

  const WatchLinkStatus({
    required this.supported,
    required this.activated,
    required this.paired,
    required this.installed,
    required this.reachable,
    this.lastWatchPing,
  });

  factory WatchLinkStatus.fromMap(Map<dynamic, dynamic> map) {
    bool flag(String key) => map[key] == true;
    final millis = map['lastWatchPing'];
    return WatchLinkStatus(
      supported: flag('supported'),
      activated: flag('activated'),
      paired: flag('paired'),
      installed: flag('installed'),
      reachable: flag('reachable'),
      lastWatchPing: millis is int
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : null,
    );
  }

  String get label {
    if (!supported) {
      return 'Disponibile solo su iPhone';
    }
    if (!activated) {
      return 'Connessione in avvio';
    }
    if (!paired) {
      return 'Nessun Apple Watch abbinato';
    }
    if (!installed) {
      return 'Installa l’app su Apple Watch';
    }
    if (!reachable) {
      return 'Apri l’app sull’Apple Watch';
    }
    return 'Apple Watch raggiungibile';
  }
}

class WatchLinkService {
  static const MethodChannel _methods =
      MethodChannel('padel_score_board/watch_link');
  static const EventChannel _events =
      EventChannel('padel_score_board/watch_link_events');

  const WatchLinkService();

  Stream<WatchLinkStatus> get statuses => _events.receiveBroadcastStream().map(
        (event) => WatchLinkStatus.fromMap(event as Map),
      );

  Future<WatchLinkStatus> status() async {
    final map = await _methods.invokeMapMethod<dynamic, dynamic>('getStatus');
    return WatchLinkStatus.fromMap(map ?? {});
  }

  Future<WatchLinkStatus> activate() async {
    final map = await _methods.invokeMapMethod<dynamic, dynamic>('activate');
    return WatchLinkStatus.fromMap(map ?? {});
  }

  /// Ping diagnostico senza modificare il punteggio o lo storico.
  Future<int> ping() async {
    final map = await _methods.invokeMapMethod<dynamic, dynamic>('ping');
    if (map?['ok'] != true || map?['roundTripMs'] is! int) {
      throw const FormatException('Risposta Ping/Pong Watch non valida');
    }
    return map!['roundTripMs'] as int;
  }
}
