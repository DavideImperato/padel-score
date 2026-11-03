import 'package:flutter/material.dart';
import 'padel_ball_loader.dart';

/// Il launch screen nativo iOS usa lo stesso sfondo e la stessa pallina statica.
/// Questa schermata appare al primo frame Flutter durante il caricamento reale.
class PadelStartupScreen extends StatelessWidget {
  const PadelStartupScreen({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101D3A),
      body: SafeArea(
        child: Center(
          child: error == null
              ? const PadelBallLoader(size: 64)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFCCFF00), size: 36),
                      const SizedBox(height: 16),
                      const Text(
                        'Impossibile completare l’avvio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFDCE5F3)),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(height: 18),
                        FilledButton(onPressed: onRetry, child: const Text('Riprova')),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
