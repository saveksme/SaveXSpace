import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _kExcludeProxyTypes = {
  'Direct', 'Reject', 'Selector', 'URLTest', 'Fallback',
  'LoadBalance', 'Relay', 'Compatible',
};

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _connectingController;
  late AnimationController _rippleController;
  late AnimationController _meshController;
  late AnimationController _auroraController;
  late AnimationController _cardsController;
  final _pageScrollController = SmoothScrollController();
  double _lastAuroraTarget = -1;
  bool _wasStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _connectingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 0.0,
    );

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 0.0,
    );
    _cardsController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectingController.dispose();
    _rippleController.dispose();
    _meshController.dispose();
    _auroraController.dispose();
    _cardsController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    final isStart = ref.read(isStartProvider);
    // Trigger ripple animation on tap
    _rippleController.forward(from: 0.0);
    debouncer.call(FunctionTag.updateStatus, () {
      appController.updateStatus(!isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  @override
  Widget build(BuildContext context) {
    final isStart = ref.watch(isStartProvider);
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final runTime = ref.watch(runTimeProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Manage connecting animation
    if (coreStatus == CoreStatus.connecting) {
      _connectingController.repeat();
    } else {
      _connectingController.stop();
    }

    // Trigger blur animation for VPN cards (in on connect, out on disconnect)
    if (isStart && !_wasStarted) {
      _cardsController.forward(from: 0.0);
    } else if (!isStart && _wasStarted) {
      _cardsController.reverse();
    }
    _wasStarted = isStart;

    // Smooth aurora intensity transitions
    final auroraTarget = isStart ? 1.0 : (coreStatus == CoreStatus.connecting ? 0.55 : 0.0);
    if (_lastAuroraTarget != auroraTarget) {
      _lastAuroraTarget = auroraTarget;
      if (auroraTarget == 1.0) {
        _auroraController.animateTo(1.0, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
      } else if (auroraTarget > 0) {
        _auroraController.animateTo(0.55, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      } else {
        _auroraController.animateTo(0.0, duration: const Duration(milliseconds: 1200), curve: Curves.easeInCubic);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated aurora + data flow background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_meshController, _auroraController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _AuroraFlowPainter(
                      progress: _meshController.value,
                      color: primaryColor,
                      intensity: _auroraController.value,
                    ),
                  );
                },
              ),
            ),
            // Main content
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Text(
                        appLocalizations.dashboard,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      _CoreStatusDot(coreStatus: coreStatus),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _pageScrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (hasProfile) ...[
                      _ConnectButton(
                        isConnected: isStart,
                        isConnecting: coreStatus == CoreStatus.connecting,
                        onTap: _handleToggle,
                        pulseAnimation: _pulseAnimation,
                        connectingController: _connectingController,
                        rippleController: _rippleController,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isStart
                              ? utils.getTimeText(runTime)
                              : appLocalizations.disconnected,
                          key: ValueKey(isStart ? 'running' : 'stopped'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isStart
                                ? primaryColor.withValues(alpha: 0.8)
                                : Colors.white38,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: () => appController.toProfiles(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                            color: primaryColor.withValues(alpha: 0.05),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withValues(alpha: 0.1),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Icon(Icons.add_rounded, size: 32, color: primaryColor),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                appLocalizations.addProfile,
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Добавьте подписку для начала работы',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (hasProfile)
                      _ModeSelector(
                        currentMode: mode,
                        onModeChanged: (m) => appController.changeMode(m),
                        primaryColor: primaryColor,
                      ),
                    const SizedBox(height: 16),
                    // Subscription card under mode selector
                    _SubscriptionCard(primaryColor: primaryColor),
                    const SizedBox(height: 12),
                    // Region selector — always visible
                    if (hasProfile)
                      _ProxySelector(
                        primaryColor: primaryColor,
                        currentMode: mode,
                      ),
                    const SizedBox(height: 12),
                    if (isStart || _cardsController.value > 0) ...[
                      _BlurRevealCard(
                        animation: _cardsController,
                        delay: 0.0,
                        child: _SpeedCard(primaryColor: primaryColor),
                      ),
                      const SizedBox(height: 12),
                      _BlurRevealCard(
                        animation: _cardsController,
                        delay: 0.12,
                        child: _TotalTrafficCard(primaryColor: primaryColor),
                      ),
                      const SizedBox(height: 12),
                      _BlurRevealCard(
                        animation: _cardsController,
                        delay: 0.24,
                        child: _NetworkInfoRow(primaryColor: primaryColor),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _AnnounceBanner(primaryColor: primaryColor),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

class _BlurRevealCard extends StatelessWidget {
  final Animation<double> animation;
  final double delay;
  final Widget child;

  const _BlurRevealCard({
    required this.animation,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final end = (delay + 0.6).clamp(0.0, 1.0);
        final t = ((animation.value - delay) / (end - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(t);
        final opacity = curved;
        final blur = (1.0 - curved) * 12.0;
        final translateY = (1.0 - curved) * 24.0;

        if (opacity <= 0.0) {
          return const SizedBox.shrink();
        }

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: blur > 0.5
                ? ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blur,
                        sigmaY: blur,
                        tileMode: TileMode.decal,
                      ),
                      child: child,
                    ),
                  )
                : child,
          ),
        );
      },
    );
  }
}

class _AuroraFlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double intensity;

  static final List<_FlowParticle> _particles = _generateParticles(40);

  _AuroraFlowPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });

  static List<_FlowParticle> _generateParticles(int count) {
    final rng = math.Random(77);
    return List.generate(count, (_) => _FlowParticle(
      x: rng.nextDouble(),
      speed: 0.3 + rng.nextDouble() * 0.7,
      size: 0.8 + rng.nextDouble() * 1.5,
      waveIndex: rng.nextInt(5),
      phase: rng.nextDouble() * math.pi * 2,
      brightness: 0.4 + rng.nextDouble() * 0.6,
    ));
  }

  // Compute wave Y at normalized x position for a given wave layer.
  // All speed multipliers are integers so the wave loops seamlessly at t=0..1.
  double _waveY(double x, int layer, double t, double h, double w) {
    final baseY = 0.2 + layer * 0.15;
    final ampScale = w;
    final amp = 0.025 + layer * 0.006;
    final freq = 1.5 + layer * 0.4;
    // Integer speeds ensure sin/cos repeat exactly over t=0..1
    final speed = (1 + layer).toDouble();
    final wave = math.sin((x * freq + t * speed) * math.pi * 2) * amp
        + math.sin((x * freq * 1.7 + t * speed * 2.0 + layer) * math.pi * 2) * amp * 0.5
        + math.cos((x * freq * 0.5 + t * speed * 3.0) * math.pi * 2) * amp * 0.3;
    return baseY * h + wave * ampScale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = progress;

    // ─── 1. Aurora wave ribbons ───
    for (int layer = 0; layer < 5; layer++) {
      final path = Path();
      final steps = 80;

      // Build wave path
      for (int i = 0; i <= steps; i++) {
        final x = (i / steps) * w;
        final nx = i / steps;
        final y = _waveY(nx, layer, t, h, w);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Stroke the wave line
      final waveAlpha = (0.03 + layer * 0.012) * intensity;
      final wavePaint = Paint()
        ..color = color.withValues(alpha: waveAlpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + (layer * 0.3)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, wavePaint);

      // Soft glow ribbon beneath wave (filled area)
      if (intensity > 0.15) {
        final glowPath = Path();
        for (int i = 0; i <= steps; i++) {
          final x = (i / steps) * w;
          final nx = i / steps;
          final y = _waveY(nx, layer, t, h, w);
          if (i == 0) {
            glowPath.moveTo(x, y);
          } else {
            glowPath.lineTo(x, y);
          }
        }
        // Close downward to create a filled band
        final bandH = 25.0 + layer * 8.0;
        for (int i = steps; i >= 0; i--) {
          final x = (i / steps) * w;
          final nx = i / steps;
          final y = _waveY(nx, layer, t, h, w) + bandH;
          glowPath.lineTo(x, y);
        }
        glowPath.close();

        final glowAlpha = (0.008 + layer * 0.003) * intensity;
        final glowPaint = Paint()
          ..color = color.withValues(alpha: glowAlpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawPath(glowPath, glowPaint);
      }
    }

    // ─── 2. Floating data particles ───
    if (intensity > 0.15) {
      final dotPaint = Paint()..style = PaintingStyle.fill;
      final speed = 0.4 + 0.6 * intensity;

      for (final p in _particles) {
        // Particle drifts along its wave
        final px = ((p.x + t * p.speed * speed * 0.15 + p.phase) % 1.0);
        final py = _waveY(px, p.waveIndex, t, h, w);

        // Vertical bob
        final bob = math.sin(t * math.pi * 2 * 3 + p.phase) * 4;

        final alpha = (0.08 + p.brightness * 0.12) * intensity;
        dotPaint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawCircle(
          Offset(px * w, py + bob),
          p.size * (0.7 + 0.3 * intensity),
          dotPaint,
        );

        // Tiny trail behind particle
        if (intensity > 0.8) {
          for (int trail = 1; trail <= 3; trail++) {
            final tx = px - trail * 0.008 * p.speed;
            if (tx < 0) continue;
            final ty = _waveY(tx, p.waveIndex, t, h, w);
            final trailAlpha = alpha * (1.0 - trail * 0.3);
            dotPaint.color = color.withValues(alpha: trailAlpha.clamp(0.0, 1.0));
            canvas.drawCircle(
              Offset(tx * w, ty + bob * (1.0 - trail * 0.2)),
              p.size * 0.5,
              dotPaint,
            );
          }
        }
      }
    }

    // ─── 3. Center radial glow (subtle) ───
    if (intensity > 0.05) {
      final centerX = w * 0.5;
      final centerY = h * 0.28; // Near the connect button
      final glowRadius = w * (0.25 + 0.2 * intensity);
      final glowAlpha = 0.06 * intensity;
      // Pulsing
      final pulse = 1.0 + 0.15 * math.sin(t * math.pi * 2 * 4);

      final radialPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: glowAlpha * pulse),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: glowRadius,
        ));

      canvas.drawCircle(Offset(centerX, centerY), glowRadius, radialPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraFlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.intensity != intensity;
}

class _FlowParticle {
  final double x;
  final double speed;
  final double size;
  final int waveIndex;
  final double phase;
  final double brightness;

  const _FlowParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.waveIndex,
    required this.phase,
    required this.brightness,
  });
}

class _CoreStatusDot extends StatelessWidget {
  final CoreStatus coreStatus;
  const _CoreStatusDot({required this.coreStatus});

  @override
  Widget build(BuildContext context) {
    final color = switch (coreStatus) {
      CoreStatus.connected => const Color(0xFF4ADE80),
      CoreStatus.connecting => Colors.amber,
      CoreStatus.disconnected => Colors.red,
    };
    final label = switch (coreStatus) {
      CoreStatus.connected => appLocalizations.connected,
      CoreStatus.connecting => appLocalizations.connecting,
      CoreStatus.disconnected => appLocalizations.disconnected,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;
  final AnimationController connectingController;
  final AnimationController rippleController;
  final Color primaryColor;

  const _ConnectButton({
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
    required this.pulseAnimation,
    required this.connectingController,
    required this.rippleController,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 140.0;
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: SizedBox(
        width: size + 40,
        height: size + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple effect on tap
            AnimatedBuilder(
              animation: rippleController,
              builder: (context, _) {
                final progress = rippleController.value;
                if (progress == 0.0 || progress == 1.0) {
                  return const SizedBox.shrink();
                }
                return Container(
                  width: size + (60 * progress),
                  height: size + (60 * progress),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.4 * (1 - progress)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            // Orbiting dots during connecting state
            if (isConnecting)
              AnimatedBuilder(
                animation: connectingController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(size + 30, size + 30),
                    painter: _OrbitingDotsPainter(
                      progress: connectingController.value,
                      color: primaryColor,
                      dotCount: 3,
                    ),
                  );
                },
              ),
            // Outer glow ring during connecting
            if (isConnecting)
              AnimatedBuilder(
                animation: connectingController,
                builder: (context, _) {
                  final glowAlpha = 0.1 + 0.15 * math.sin(connectingController.value * math.pi * 2);
                  return Container(
                    width: size + 16,
                    height: size + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: glowAlpha),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            // Main button
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                final scale = isConnected ? pulseAnimation.value : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? primaryColor.withValues(alpha: 0.15)
                      : isConnecting
                          ? primaryColor.withValues(alpha: 0.08)
                          : const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: isConnected
                        ? primaryColor.withValues(alpha: 0.6)
                        : isConnecting
                            ? primaryColor.withValues(alpha: 0.35)
                            : const Color(0xFF2A2A2A),
                    width: 3,
                  ),
                  boxShadow: isConnected
                      ? [BoxShadow(color: primaryColor.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 5)]
                      : isConnecting
                          ? [BoxShadow(color: primaryColor.withValues(alpha: 0.12), blurRadius: 30, spreadRadius: 2)]
                          : [],
                ),
                child: Center(
                  child: isConnecting
                      ? _ConnectingIcon(
                          controller: connectingController,
                          primaryColor: primaryColor,
                        )
                      : Icon(
                          Icons.power_settings_new,
                          size: 48,
                          color: isConnected ? primaryColor : Colors.white38,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectingIcon extends StatelessWidget {
  final AnimationController controller;
  final Color primaryColor;

  const _ConnectingIcon({
    required this.controller,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing power icon
            Opacity(
              opacity: 0.3 + 0.4 * math.sin(controller.value * math.pi * 2).abs(),
              child: Icon(
                Icons.power_settings_new,
                size: 48,
                color: primaryColor,
              ),
            ),
            // Rotating arc
            SizedBox(
              width: 56,
              height: 56,
              child: Transform.rotate(
                angle: controller.value * math.pi * 2,
                child: CustomPaint(
                  painter: _ArcPainter(color: primaryColor),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi * 0.7, false, paint);
    canvas.drawArc(rect, math.pi, math.pi * 0.7, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int dotCount;

  _OrbitingDotsPainter({
    required this.progress,
    required this.color,
    this.dotCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < dotCount; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi * 2 / dotCount);
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);

      final dotAlpha = 0.3 + 0.7 * ((math.sin(progress * math.pi * 2 + i * 1.5) + 1) / 2);
      final dotSize = 3.0 + 2.0 * ((math.sin(progress * math.pi * 2 + i * 2.0) + 1) / 2);

      final paint = Paint()
        ..color = color.withValues(alpha: dotAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dotX, dotY), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitingDotsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ModeSelector extends StatelessWidget {
  final Mode currentMode;
  final ValueChanged<Mode> onModeChanged;
  final Color primaryColor;

  const _ModeSelector({
    required this.currentMode,
    required this.onModeChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: Mode.values.map((mode) {
          final isSelected = mode == currentMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: isSelected ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1) : null,
                ),
                child: Center(
                  child: Text(
                    Intl.message(mode.name),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? primaryColor : Colors.white38,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Real-time speed card with upload/download rates
class _SpeedCard extends ConsumerWidget {
  final Color primaryColor;
  const _SpeedCard({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffics = ref.watch(trafficsProvider);
    final trafficList = traffics.list;
    final lastTraffic = trafficList.isNotEmpty ? trafficList.last : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_upward_rounded, size: 18, color: primaryColor.withValues(alpha: 0.7)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastTraffic != null ? '${lastTraffic.up.traffic.show}/s' : '0 B/s',
                      style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const Text('Upload', style: TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFF1A1A1A)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lastTraffic != null ? '${lastTraffic.down.traffic.show}/s' : '0 B/s',
                      style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const Text('Download', style: TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_downward_rounded, size: 18, color: primaryColor.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Announcement banner from subscription provider
class _AnnounceBanner extends ConsumerWidget {
  final Color primaryColor;
  const _AnnounceBanner({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null || profile.announce == null || profile.announce!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.campaign_rounded, size: 16, color: primaryColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                profile.announce!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Subscription info card with animated border on refresh
class _SubscriptionCard extends ConsumerStatefulWidget {
  final Color primaryColor;
  const _SubscriptionCard({required this.primaryColor});

  @override
  ConsumerState<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends ConsumerState<_SubscriptionCard>
    with TickerProviderStateMixin {
  late AnimationController _borderController;
  late AnimationController _successController;
  bool _isRefreshing = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _successController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showSuccess = false);
        _successController.reset();
      }
    });
  }

  @override
  void dispose() {
    _borderController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _onRefreshStart() {
    setState(() {
      _isRefreshing = true;
      _showSuccess = false;
    });
    _borderController.repeat();
  }

  void _onRefreshEnd() {
    _borderController.stop();
    _borderController.animateTo(1.0, duration: const Duration(milliseconds: 300))
      .then((_) {
        if (mounted) {
          _borderController.reset();
          setState(() {
            _isRefreshing = false;
            _showSuccess = true;
          });
          _successController.forward(from: 0.0);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    final sub = profile.subscriptionInfo;
    final label = profile.label.isNotEmpty ? profile.label : profile.url;
    final primaryColor = widget.primaryColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_borderController, _successController]),
      builder: (context, child) {
        CustomPainter? painter;
        if (_isRefreshing) {
          painter = _RefreshBorderPainter(
            progress: _borderController.value,
            color: const Color(0xFFE879A8),
            borderRadius: 14,
          );
        } else if (_showSuccess) {
          painter = _SuccessBorderPainter(
            progress: _successController.value,
            color: const Color(0xFF34D399),
            borderRadius: 14,
          );
        }
        return CustomPaint(
          foregroundPainter: painter,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A1A1A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sim_card_outlined, size: 16, color: primaryColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (sub != null && sub.total > 0) ...[
                    const SizedBox(height: 12),
                    _DataUsageBar(
                      used: sub.upload + sub.download,
                      total: sub.total,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${((sub.upload + sub.download) as num).traffic.show} / ${(sub.total as num).traffic.show}',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _isInfinite(sub) ? Icons.all_inclusive_rounded : Icons.timer_outlined,
                        size: 11,
                        color: _isInfinite(sub)
                            ? Colors.white24
                            : _expiryColor(sub?.expire ?? 0),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInfinite(sub) ? 'Бесконечная' : _formatExpiry(sub!.expire),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _isInfinite(sub)
                              ? Colors.white24
                              : _expiryColor(sub?.expire ?? 0),
                        ),
                      ),
                      if (profile.lastUpdateDate != null) ...[
                        Text(
                          '  ·  ',
                          style: const TextStyle(fontSize: 10, color: Colors.white12),
                        ),
                        Text(
                          'Обновлено: ${_formatDate(profile.lastUpdateDate!)}',
                          style: const TextStyle(fontSize: 10, color: Colors.white24),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RefreshButton(
              primaryColor: primaryColor,
              profile: profile,
              onRefreshStart: _onRefreshStart,
              onRefreshEnd: _onRefreshEnd,
            ),
          ],
        ),
      ),
    );
  }

  bool _isInfinite(dynamic sub) {
    if (sub == null) return true;
    final expire = sub.expire ?? 0;
    if (expire == 0) return true;
    return DateTime.fromMillisecondsSinceEpoch(expire * 1000).year >= 2099;
  }

  String _formatExpiry(int expireTimestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000);
    if (date.year >= 2099) return 'Бесконечная';
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Истекла';
    if (diff.inDays > 30) return '${diff.inDays} дн';
    if (diff.inDays > 0) return '${diff.inDays} дн';
    if (diff.inHours > 0) return '${diff.inHours} ч';
    return '< 1ч';
  }

  Color _expiryColor(int expireTimestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000);
    if (date.year >= 2099) return Colors.white30;
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return Colors.red;
    if (diff.inDays < 3) return Colors.amber;
    return Colors.white30;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

/// Paints a thin animated gradient arc that sweeps around the card — Material You style
class _RefreshBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;

  _RefreshBorderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Flat, uniform-speed line tracing the border
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final totalLen = metric.length;

    // Line segment: 15% of perimeter, moves at constant speed
    final lineLen = totalLen * 0.15;
    final start = (progress * totalLen) % totalLen;
    final end = start + lineLen;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    if (end <= totalLen) {
      final segment = metric.extractPath(start, end);
      canvas.drawPath(segment, paint);
    } else {
      // Wraps around
      final seg1 = metric.extractPath(start, totalLen);
      final seg2 = metric.extractPath(0, end - totalLen);
      canvas.drawPath(seg1, paint);
      canvas.drawPath(seg2, paint);
    }
  }

  @override
  bool shouldRepaint(_RefreshBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Green border that draws fully around the card then fades out on success.
class _SuccessBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;

  _SuccessBorderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final totalLen = metric.length;

    // Phase 1 (0..0.5): draw the border progressively
    // Phase 2 (0.5..1.0): fade out the full border
    final drawT = (progress / 0.5).clamp(0.0, 1.0);
    final fadeT = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    final alpha = (1.0 - Curves.easeOut.transform(fadeT)) * 0.8;

    if (alpha <= 0.01) return;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    final len = Curves.easeOutCubic.transform(drawT) * totalLen;
    if (len > 0) {
      final segment = metric.extractPath(0, len);
      canvas.drawPath(segment, paint);
    }
  }

  @override
  bool shouldRepaint(_SuccessBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RefreshButton extends StatefulWidget {
  final Color primaryColor;
  final Profile profile;
  final VoidCallback? onRefreshStart;
  final VoidCallback? onRefreshEnd;
  const _RefreshButton({
    required this.primaryColor,
    required this.profile,
    this.onRefreshStart,
    this.onRefreshEnd,
  });

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinController.repeat();
    widget.onRefreshStart?.call();
    try {
      await appController.updateProfile(widget.profile);
    } catch (_) {}
    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() => _isRefreshing = false);
      widget.onRefreshEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _refresh,
      child: AnimatedBuilder(
        animation: _spinController,
        builder: (_, child) {
          return Transform.rotate(
            angle: _spinController.value * math.pi * 2,
            child: child,
          );
        },
        child: Icon(
          Icons.refresh_rounded,
          size: 18,
          color: widget.primaryColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// Total session traffic
class _TotalTrafficCard extends ConsumerWidget {
  final Color primaryColor;
  const _TotalTrafficCard({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalTraffic = ref.watch(totalTrafficProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        children: [
          Icon(Icons.data_usage_rounded, size: 16, color: primaryColor.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Text(
            'Всего',
            style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            '↑ ${totalTraffic.up.traffic.show}',
            style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Text(
            '↓ ${totalTraffic.down.traffic.show}',
            style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// Network info: connections count + local IP + TUN
class _NetworkInfoRow extends ConsumerWidget {
  final Color primaryColor;
  const _NetworkInfoRow({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);
    final localIp = ref.watch(localIpProvider);
    final tunEnabled = ref.watch(realTunEnableProvider);
    final connectionsCount = requests.list.length;

    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.device_hub_rounded,
            label: '$connectionsCount',
            subtitle: 'Соединения',
            primaryColor: primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoTile(
            icon: Icons.language_rounded,
            label: localIp ?? '—',
            subtitle: 'IP',
            primaryColor: primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoTile(
            icon: Icons.shield_outlined,
            label: tunEnabled ? 'TUN' : 'Proxy',
            subtitle: 'Режим',
            primaryColor: primaryColor,
            highlight: tunEnabled,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color primaryColor;
  final bool highlight;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.primaryColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? primaryColor.withValues(alpha: 0.2)
              : const Color(0xFF1A1A1A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: primaryColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? primaryColor.withValues(alpha: 0.9) : Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

/// Proxy selector — dropdown for Global mode, link to Routes for Rule/Auto mode
class _ProxySelector extends ConsumerStatefulWidget {
  final Color primaryColor;
  final Mode currentMode;
  const _ProxySelector({required this.primaryColor, required this.currentMode});

  @override
  ConsumerState<_ProxySelector> createState() => _ProxySelectorState();
}

class _ProxySelectorState extends ConsumerState<_ProxySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _expanded = false;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  Future<void> _pingAll(List<Proxy> proxies, String? testUrl) async {
    if (_isPinging) return;
    setState(() => _isPinging = true);
    // Import delay test from proxies common
    final proxyNames = proxies.map((p) => p.name).toSet().toList();
    final delayFutures = proxyNames.map<Future>((proxyName) async {
      final groups = appController.groups;
      final selectedMap = appController.currentProfile?.selectedMap ?? {};
      final state = computeRealSelectedProxyState(
        proxyName,
        groups: groups,
        selectedMap: selectedMap,
      );
      final url = state.testUrl.takeFirstValid([
        appController.getRealTestUrl(testUrl),
      ]);
      final name = state.proxyName;
      if (name.isEmpty) return;
      appController.setDelay(Delay(url: url, name: name, value: 0));
      appController.setDelay(await coreController.getDelay(url, name));
    }).toList();
    final batches = delayFutures.batch(100);
    for (final batch in batches) {
      await Future.wait(batch);
    }
    appController.addSortNum();
    if (mounted) setState(() => _isPinging = false);
  }

  @override
  Widget build(BuildContext context) {
    final isGlobal = widget.currentMode == Mode.global;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: isGlobal
          ? KeyedSubtree(
              key: const ValueKey('global_selector'),
              child: _buildGlobalSelector(),
            )
          : KeyedSubtree(
              key: const ValueKey('routes_link'),
              child: _buildRoutesLink(),
            ),
    );
  }

  Widget _buildRoutesLink() {
    return GestureDetector(
      onTap: () => appController.toPage(PageLabel.proxies),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1A1A1F)),
        ),
        child: Row(
          children: [
            Icon(Icons.route_rounded, size: 18,
                color: widget.primaryColor.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Маршруты',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Настроить маршруты',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSelector() {
    final groups = ref.watch(currentGroupsStateProvider).value;
    final globalGroup = groups.where(
        (g) => g.name == GroupName.GLOBAL.name).toList();
    if (globalGroup.isEmpty) return const SizedBox.shrink(key: ValueKey('empty'));

    final group = globalGroup.first;
    // Filter out DIRECT, REJECT, and group-type proxies (Selector, URLTest, Fallback, etc.)
    final proxies = group.all
        .where((p) => !_kExcludeProxyTypes.contains(p.type) &&
            p.name != 'DIRECT' && p.name != 'REJECT')
        .toList();
    final selectedProxy = ref.watch(
      getSelectedProxyNameProvider(GroupName.GLOBAL.name),
    ) ?? '';

    return AnimatedContainer(
      key: const ValueKey('global_selector'),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _expanded
            ? const Color(0xFF111116)
            : const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? widget.primaryColor.withValues(alpha: 0.12)
              : const Color(0xFF1A1A1F),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  // Active dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.primaryColor.withValues(
                          alpha: selectedProxy.isNotEmpty ? 1.0 : 0.3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Selected proxy name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Сервер',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.3),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        EmojiText(
                          selectedProxy.isNotEmpty
                              ? selectedProxy
                              : 'Не выбран',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selectedProxy.isNotEmpty
                                ? Colors.white.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Ping all button
                  GestureDetector(
                    onTap: () => _pingAll(proxies, group.testUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPinging)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: widget.primaryColor.withValues(alpha: 0.6),
                              ),
                            )
                          else
                            Icon(Icons.speed_rounded, size: 14,
                                color: widget.primaryColor.withValues(alpha: 0.6)),
                          const SizedBox(width: 5),
                          Text(
                            'Ping',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand arrow
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more_rounded,
                        size: 20, color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ],
              ),
            ),
          ),
          // Animated list with blur reveal
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, _) {
              final t = _expandAnimation.value;
              if (t <= 0.0) return const SizedBox.shrink();
              final blur = (1.0 - t) * 8.0;
              final maxH = 280.0;

              Widget content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  // Proxy list with scroll isolation
                  _IsolatedScrollList(
                    height: (proxies.length * 42.0).clamp(0.0, maxH - 1) * t,
                    itemCount: proxies.length,
                    itemBuilder: (_, index) {
                      final proxy = proxies[index];
                      final isActive = proxy.name == selectedProxy;
                      return _ProxyListItem(
                        proxy: proxy,
                        testUrl: group.testUrl,
                        isActive: isActive,
                        primaryColor: widget.primaryColor,
                        onTap: () {
                          appController.updateCurrentSelectedMap(
                              GroupName.GLOBAL.name, proxy.name);
                          appController.changeProxyDebounce(
                              GroupName.GLOBAL.name, proxy.name);
                          _toggle();
                        },
                      );
                    },
                  ),
                ],
              );

              if (blur > 0.5) {
                content = ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: content,
                  ),
                );
              }

              return Opacity(opacity: t, child: content);
            },
          ),
        ],
      ),
    );
  }
}

class _ProxyListItem extends StatelessWidget {
  final Proxy proxy;
  final String? testUrl;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _ProxyListItem({
    required this.proxy,
    required this.testUrl,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Active indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 4 : 0,
              height: 4,
              margin: EdgeInsets.only(right: isActive ? 10 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
            ),
            // Name
            Expanded(
              child: EmojiText(
                proxy.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Delay with blur reveal animation
            _AnimatedDelay(proxyName: proxy.name, testUrl: testUrl),
          ],
        ),
      ),
    );
  }
}

class _DataUsageBar extends StatelessWidget {
  final int used;
  final int total;
  final Color primaryColor;

  const _DataUsageBar({
    required this.used,
    required this.total,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio > 0.9 ? Colors.red : (ratio > 0.7 ? Colors.amber : primaryColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          value: ratio,
          backgroundColor: const Color(0xFF1A1A1A),
          valueColor: AlwaysStoppedAnimation<Color>(barColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

/// Animated delay indicator — blur reveals when ping result arrives.
class _AnimatedDelay extends ConsumerStatefulWidget {
  final String proxyName;
  final String? testUrl;

  const _AnimatedDelay({required this.proxyName, required this.testUrl});

  @override
  ConsumerState<_AnimatedDelay> createState() => _AnimatedDelayState();
}

class _AnimatedDelayState extends ConsumerState<_AnimatedDelay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int? _prevDelay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, // start fully revealed
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delay = ref.watch(
      getDelayProvider(proxyName: widget.proxyName, testUrl: widget.testUrl),
    );

    // Detect transition from loading (0) to result
    if (_prevDelay == 0 && delay != null && delay != 0) {
      _controller.forward(from: 0.0);
    }
    _prevDelay = delay;

    if (delay == null) {
      return Text(
        '\u2014',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      );
    }
    if (delay == 0) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      );
    }

    final color = delay > 0
        ? (delay < 300
            ? const Color(0xFF34D399)
            : delay < 600
                ? const Color(0xFFFBBF24)
                : const Color(0xFFF87171))
        : const Color(0xFFF87171);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final blur = (1.0 - t) * 5.0;
        Widget result = Opacity(
          opacity: t,
          child: child,
        );
        if (blur > 0.3) {
          result = ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal,
              ),
              child: result,
            ),
          );
        }
        return result;
      },
      child: Text(
        delay > 0 ? '${delay}ms' : '---',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A scroll list that captures mouse wheel events to prevent them
/// from bubbling to the parent scrollable (page scroll).
class _IsolatedScrollList extends StatefulWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _IsolatedScrollList({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_IsolatedScrollList> createState() => _IsolatedScrollListState();
}

class _IsolatedScrollListState extends State<_IsolatedScrollList> {
  final _controller = SmoothScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Always consume wheel events — prevent parent page from scrolling
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (event) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
          ),
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.symmetric(vertical: 4),
            physics: const BouncingScrollPhysics(),
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ),
    );
  }
}

