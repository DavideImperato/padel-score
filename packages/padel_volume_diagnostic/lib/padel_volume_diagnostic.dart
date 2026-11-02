import 'package:flutter/services.dart';

/// Risultato restituito dalla lettura dell'uscita audio iOS.
class VolumeProbeResult {
  const VolumeProbeResult({
    required this.requested,
    required this.before,
    required this.observed,
    required this.confirmed,
    required this.sliderValue,
  });

  final double requested;
  final double before;
  final double observed;
  final bool confirmed;
  final double sliderValue;

  factory VolumeProbeResult.fromMap(Map<Object?, Object?> map) {
    double numeric(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      throw FormatException('Campo volume non valido: $key');
    }
    return VolumeProbeResult(
      requested: numeric('requested'),
      before: numeric('before'),
      observed: numeric('observed'),
      confirmed: map['confirmed'] == true,
      sliderValue: numeric('sliderValue'),
    );
  }
}

/// Sonda isolata per test su iPhone. NON da collegare alla release App Store.
/// Non intercetta i tasti volume prima di iOS e non nasconde l'HUD di sistema.
class PadelVolumeDiagnostic {
  static const MethodChannel _channel = MethodChannel('padel_volume_diagnostic');

  static Future<double> read() async {
    final value = await _channel.invokeMethod<num>('read');
    if (value == null) throw StateError('Lettura del volume non disponibile');
    return value.toDouble();
  }

  /// Esegue una sola richiesta e attende una conferma di lettura nativa.
  /// [confirmed] è falso quando iOS non ha applicato il livello richiesto.
  static Future<VolumeProbeResult> write(double value) async {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'value', 'Il volume deve essere tra 0 e 1');
    }
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'write',
      <String, double>{'volume': value},
    );
    if (response == null) throw StateError('Nessuna risposta dal plugin iOS');
    return VolumeProbeResult.fromMap(response);
  }

  static Future<void> release() async {
    await _channel.invokeMethod<void>('release');
  }
}
