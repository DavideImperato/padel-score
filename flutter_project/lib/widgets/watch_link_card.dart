import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/watch_link_service.dart';

/// Solo diagnostica della Fase 4A. Nessun comando modifica il match.
class WatchLinkCard extends StatefulWidget {
  const WatchLinkCard({super.key});

  @override
  State<WatchLinkCard> createState() => _WatchLinkCardState();
}

class _WatchLinkCardState extends State<WatchLinkCard> {
  final WatchLinkService _link = const WatchLinkService();
  StreamSubscription<WatchLinkStatus>? _subscription;
  WatchLinkStatus? _status;
  String? _feedback;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      _subscription = _link.statuses.listen(
        (status) {
          if (mounted) {
            setState(() => _status = status);
          }
        },
        onError: (Object error) {
          if (mounted) {
            setState(() => _feedback = _describeError(error));
          }
        },
      );
      _refresh();
    }
  }

  String _describeError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return 'Collegamento non disponibile: $error';
  }

  Future<void> _refresh() async {
    try {
      final status = await _link.activate();
      if (mounted) {
        setState(() {
          _status = status;
          _feedback = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _feedback = _describeError(error));
      }
    }
  }

  Future<void> _ping() async {
    setState(() { _busy = true; _feedback = null; });
    try {
      final roundTrip = await _link.ping();
      if (mounted) {
        setState(() => _feedback = 'Ping/Pong riuscito: $roundTrip ms');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _feedback = _describeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) {
      return const SizedBox.shrink();
    }
    final status = _status;
    final connected = status?.reachable == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.watch, color: connected ? const Color(0xFF4ADE80) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          const Expanded(child: Text('APPLE WATCH — COLLEGAMENTO (FASE 4A)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          IconButton(tooltip: 'Aggiorna collegamento', icon: const Icon(Icons.refresh), onPressed: _refresh),
        ]),
        Text(status?.label ?? 'Verifica collegamento…',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        if (status?.lastWatchPing != null)
          Text('Ultimo ping dal Watch: ${status!.lastWatchPing!.toLocal()}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: connected && !_busy ? _ping : null,
          icon: const Icon(Icons.sync),
          label: Text(_busy ? 'Verifica in corso…' : 'PROVA PING/PONG'),
        ),
        if (_feedback != null)
          Text(_feedback!, style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 12)),
        const Text('Test di connessione soltanto: nessun punto viene assegnato dall’orologio.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]),
    );
  }
}
