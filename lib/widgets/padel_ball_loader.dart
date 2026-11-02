import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Indicatore di avvio: pallina vettoriale, senza immagini o plugin esterni.
/// Il movimento viene disattivato quando iOS richiede di ridurre le animazioni.
class PadelBallLoader extends StatefulWidget {
  const PadelBallLoader({
    super.key,
    this.size = 64,
    this.showLabel = true,
  });

  final double size;
  final bool showLabel;

  @override
  State<PadelBallLoader> createState() => _PadelBallLoaderState();
}

class _PadelBallLoaderState extends State<PadelBallLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'Caricamento in corso',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.size + 14,
            width: widget.size + 16,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final t = reduceMotion ? 0.0 : _animation.value;
                final bounce = (1 - math.cos(2 * math.pi * t)) / 2;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: widget.size * (0.38 + 0.1 * (1 - bounce)),
                        height: widget.size * 0.085,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.27 - bounce * 0.1),
                          borderRadius: BorderRadius.circular(widget.size),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, 3 - 11 * bounce),
                      child: Transform.rotate(
                        angle: t * 2 * math.pi,
                        child: CustomPaint(
                          size: Size.square(widget.size),
                          painter: const _PadelBallPainter(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 14),
            const Text(
              'Caricamento in corso...',
              style: TextStyle(
                color: Color(0xFFDCE5F3),
                fontFamily: 'Roboto',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PadelBallPainter extends CustomPainter {
  const _PadelBallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final rect = Rect.fromLTWH((size.width - d) / 2, (size.height - d) / 2, d, d);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.42, -0.50),
          radius: 0.95,
          colors: [
            Color(0xFFE9FF86),
            Color(0xFFCCFF00),
            Color(0xFFA7D900),
            Color(0xFF617F00),
          ],
          stops: [0.0, 0.43, 0.77, 1.0],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final left = Path()
      ..moveTo(rect.left + d * 0.18, rect.top + d * 0.04)
      ..cubicTo(rect.left + d * 0.47, rect.top + d * 0.28,
          rect.left + d * 0.47, rect.top + d * 0.72,
          rect.left + d * 0.18, rect.top + d * 0.96);
    final right = Path()
      ..moveTo(rect.left + d * 0.82, rect.top + d * 0.04)
      ..cubicTo(rect.left + d * 0.53, rect.top + d * 0.28,
          rect.left + d * 0.53, rect.top + d * 0.72,
          rect.left + d * 0.82, rect.top + d * 0.96);
    final seamShadow = Paint()
      ..color = const Color(0xFF668800).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.085
      ..strokeCap = StrokeCap.round;
    final seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.048
      ..strokeCap = StrokeCap.round;
    for (final path in [left, right]) {
      canvas.drawPath(path, seamShadow);
      canvas.drawPath(path, seam);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
