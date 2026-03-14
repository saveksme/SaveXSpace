import 'dart:math';
import 'package:flutter/material.dart';

class SuccessOverlay {
  static void show(BuildContext context, {String? message}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => _SuccessOverlayWidget(
          message: message,
          onDone: () {
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }
}

class _SuccessOverlayWidget extends StatefulWidget {
  final String? message;
  final VoidCallback onDone;

  const _SuccessOverlayWidget({this.message, required this.onDone});

  @override
  State<_SuccessOverlayWidget> createState() => _SuccessOverlayWidgetState();
}

class _SuccessOverlayWidgetState extends State<_SuccessOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _checkController;
  late AnimationController _ringController;
  late AnimationController _particleController;
  late AnimationController _exitController;

  late Animation<double> _bgFade;
  late Animation<double> _checkScale;
  late Animation<double> _checkDraw;
  late Animation<double> _ringScale;
  late Animation<double> _ringFade;
  late Animation<double> _particleProgress;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _exitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _bgFade = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutCubic),
    );
    _ringScale = Tween<double>(begin: 0.5, end: 1.8).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );
    _ringFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
    _particleProgress = CurvedAnimation(parent: _particleController, curve: Curves.easeOut);
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _checkController.forward();
    _ringController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _particleController.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _exitController.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _checkController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: Listenable.merge([_bgFade, _exitFade, _checkScale, _checkDraw, _ringScale, _ringFade, _particleProgress]),
      builder: (context, _) {
        return IgnorePointer(
          child: Opacity(
            opacity: _bgFade.value * _exitFade.value,
            child: Material(
              color: Colors.black.withValues(alpha: 0.88),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: _SuccessPainter(
                          checkScale: _checkScale.value,
                          checkDraw: _checkDraw.value,
                          ringScale: _ringScale.value,
                          ringFade: _ringFade.value,
                          particleProgress: _particleProgress.value,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: _checkDraw.value.clamp(0.0, 1.0),
                        child: Text(
                          widget.message!,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuccessPainter extends CustomPainter {
  final double checkScale;
  final double checkDraw;
  final double ringScale;
  final double ringFade;
  final double particleProgress;
  final Color color;

  _SuccessPainter({
    required this.checkScale,
    required this.checkDraw,
    required this.ringScale,
    required this.ringFade,
    required this.particleProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;

    // Expanding ring
    if (ringFade > 0) {
      final ringPaint = Paint()
        ..color = color.withValues(alpha: ringFade * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius * ringScale, ringPaint);
    }

    // Circle background
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.15 * checkScale)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * checkScale, circlePaint);

    // Circle border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * checkScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * checkScale, borderPaint);

    // Checkmark
    if (checkDraw > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final start = Offset(center.dx - radius * 0.3, center.dy + radius * 0.05);
      final mid = Offset(center.dx - radius * 0.05, center.dy + radius * 0.3);
      final end = Offset(center.dx + radius * 0.35, center.dy - radius * 0.25);

      if (checkDraw <= 0.5) {
        final t = checkDraw / 0.5;
        path.moveTo(start.dx, start.dy);
        path.lineTo(
          start.dx + (mid.dx - start.dx) * t,
          start.dy + (mid.dy - start.dy) * t,
        );
      } else {
        final t = (checkDraw - 0.5) / 0.5;
        path.moveTo(start.dx, start.dy);
        path.lineTo(mid.dx, mid.dy);
        path.lineTo(
          mid.dx + (end.dx - mid.dx) * t,
          mid.dy + (end.dy - mid.dy) * t,
        );
      }
      canvas.drawPath(path, checkPaint);
    }

    // Particles
    if (particleProgress > 0) {
      final particlePaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 12; i++) {
        final angle = (i * 30.0 + 42) * pi / 180;
        final dist = radius * 1.2 + radius * 1.5 * particleProgress;
        final x = center.dx + cos(angle) * dist;
        final y = center.dy + sin(angle) * dist;
        final opacity = (1.0 - particleProgress).clamp(0.0, 1.0);
        final pSize = 3.0 * (1.0 - particleProgress * 0.5);
        particlePaint.color = color.withValues(alpha: opacity * 0.8);
        canvas.drawCircle(Offset(x, y), pSize, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) => true;
}
