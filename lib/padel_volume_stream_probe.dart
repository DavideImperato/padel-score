import 'dart:async';
import 'package:flutter/material.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: VolumeProbe(),
  ));
}

class VolumeProbe extends StatefulWidget {
  const VolumeProbe({super.key});

  @override
  State<VolumeProbe> createState() => _VolumeProbeState();
}

class _VolumeProbeState extends State<VolumeProbe>
    with WidgetsBindingObserver {
  StreamSubscription<double>? subscription;
  Timer? timer;

  double? currentVolume;
  double? lastStreamVolume;

  int pollChanges = 0;
  int streamEvents = 0;

  bool reading = false;
  String lifecycle = 'resumed';

  final List<String> logs = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    PerfectVolumeControl.hideUI = false;

    subscription = PerfectVolumeControl.stream.listen(
      (value) {
        if (!mounted) return;

        setState(() {
          lastStreamVolume = value;
          streamEvents++;
        });

        addLog('STREAM: $value');
      },
      onError: (Object error) {
        addLog('ERRORE STREAM: $error');
      },
    );

    timer = Timer.periodic(
      const Duration(milliseconds: 750),
      (_) => readVolume(),
    );

    readVolume();
  }

  Future<void> readVolume() async {
    if (reading) return;
    reading = true;

    try {
      final value = await PerfectVolumeControl.getVolume();

      if (!mounted) return;

      final previous = currentVolume;
      final changed = previous == null ||
          (value - previous).abs() > 0.0005;

      setState(() {
        currentVolume = value;

        if (previous != null && changed) {
          pollChanges++;
        }
      });

      if (changed) {
        addLog('GET: $value');
      }
    } catch (error) {
      addLog('ERRORE GET: $error');
    } finally {
      reading = false;
    }
  }

  void addLog(String message) {
    debugPrint('[VolumeProbe] $message');

    if (!mounted) return;

    setState(() {
      logs.insert(0, message);

      if (logs.length > 40) {
        logs.removeLast();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycle = state.name;
    addLog('Lifecycle: ${state.name}');

    if (state == AppLifecycleState.resumed) {
      readVolume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test volume Flutter'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Diagnostica perfect_volume_control. '
                'Non modifica il volume e non assegna punti.',
              ),
              const SizedBox(height: 20),
              Text(
                'getVolume(): '
                '${currentVolume?.toStringAsFixed(3) ?? "---"}',
              ),
              Text(
                'Ultimo STREAM: '
                '${lastStreamVolume?.toStringAsFixed(3) ?? "---"}',
              ),
              Text('Variazioni GET: $pollChanges'),
              Text('Eventi STREAM: $streamEvents'),
              Text('Stato app: $lifecycle'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: readVolume,
                child: const Text('Leggi volume adesso'),
              ),
              const Divider(),
              const Text('REGISTRO EVENTI'),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SelectableText(logs[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
