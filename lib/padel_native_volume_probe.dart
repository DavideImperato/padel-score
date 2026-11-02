import 'dart:async';

import 'package:flutter/material.dart';
import 'package:padel_volume_diagnostic/padel_volume_diagnostic.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

/// Entry point di prova: flutter run --debug -t lib/padel_native_volume_probe.dart
/// NON modifica Padel Score Board né abilita controlli volume nella release.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: NativeVolumeProbeScreen(),
  ));
}

class NativeVolumeProbeScreen extends StatefulWidget {
  const NativeVolumeProbeScreen({super.key});

  @override
  State<NativeVolumeProbeScreen> createState() => _NativeVolumeProbeScreenState();
}

class _NativeVolumeProbeScreenState extends State<NativeVolumeProbeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<double>? _stream;
  Timer? _poll;
  double? _read;
  double? _streamValue;
  double? _beforeWrite;
  VolumeProbeResult? _lastWrite;
  int _events = 0;
  bool _busy = false;
  String? _error;
  final List<String> _logs = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // L'HUD di sistema rimane visibile: non nascondiamo i controlli nativi.
    PerfectVolumeControl.hideUI = false;
    _stream = PerfectVolumeControl.stream.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _streamValue = value;
          _events++;
        });
        _log('STREAM ${value.toStringAsFixed(3)}');
      },
      onError: (Object error) => _log('ERRORE STREAM: $error'),
    );
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_readNow()),
    );
    unawaited(_readNow());
  }

  void _log(String value) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, value);
      if (_logs.length > 35) _logs.removeLast();
    });
    debugPrint('[NativeVolumeProbe] $value');
  }

  Future<void> _readNow() async {
    try {
      final value = await PadelVolumeDiagnostic.read();
      if (!mounted) return;
      setState(() => _read = value);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _write(double target) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _lastWrite = null;
    });
    try {
      _beforeWrite = await PadelVolumeDiagnostic.read();
      final result = await PadelVolumeDiagnostic.write(target);
      if (!mounted) return;
      setState(() => _lastWrite = result);
      _log('WRITE ${result.before.toStringAsFixed(3)} -> '
          '${result.requested.toStringAsFixed(3)}; '
          'letto=${result.observed.toStringAsFixed(3)}; '
          'confermato=${result.confirmed}; '
          'slider=${result.sliderValue.toStringAsFixed(3)}');
      await _readNow();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _log('ERRORE WRITE: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('LIFECYCLE ${state.name}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    unawaited(_stream?.cancel() ?? Future<void>.value());
    unawaited(PadelVolumeDiagnostic.release().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _lastWrite;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostica volume iOS')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Sonda nativa separata dal tabellone. '
                  'Premi + / - per controllare STREAM; '
                  'usa i pulsanti per verificare la scrittura.'),
              const SizedBox(height: 12),
              Text('Volume reale letto: ${_read?.toStringAsFixed(3) ?? "---"}'),
              Text('Ultimo STREAM: ${_streamValue?.toStringAsFixed(3) ?? "---"}'),
              Text('Eventi STREAM: $_events'),
              if (result != null)
                Text('Ultima scrittura confermata: ${result.confirmed ? "SÌ" : "NO"}'),
              if (_error != null)
                Text('Errore: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: <Widget>[
                FilledButton(
                  onPressed: _busy ? null : () => _write(0.5),
                  child: const Text('Imposta 50%'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _write(0.8),
                  child: const Text('Imposta 80%'),
                ),
                OutlinedButton(
                  onPressed: _busy || _beforeWrite == null
                      ? null
                      : () => _write(_beforeWrite!),
                  child: const Text('Ripristina precedente'),
                ),
              ]),
              const Divider(),
              const Text('Eventi e risultati'),
              Expanded(
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText(_logs[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
