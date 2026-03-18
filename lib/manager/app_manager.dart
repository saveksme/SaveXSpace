import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        appController.savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        appController.updateGroupsDebounce();
      }
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      if (next.a == true && next.b == true) {
        macOS?.updateDns(false);
      } else {
        macOS?.updateDns(true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appController.tryCheckIp();
        if (system.isAndroid) {
          appController.tryStartCore();
        }
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    appController.updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerStatefulWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  @override
  ConsumerState<AppSidebarContainer> createState() =>
      _AppSidebarContainerState();
}

class _AppSidebarContainerState extends ConsumerState<AppSidebarContainer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final currentIndex = navigationState.currentIndex;
    final primaryColor = context.colorScheme.primary;

    return Column(
      children: [
        Expanded(child: widget.child),
        _BottomNavBar(
          items: navigationItems,
          currentIndex: currentIndex,
          primaryColor: primaryColor,
          surfaceColor: context.colorScheme.onSurface,
          bgColor: context.colorScheme.surfaceContainer,
          onTap: (index) {
            HapticFeedback.selectionClick();
            appController.toPage(navigationItems[index].label);
          },
        ),
      ],
    );
  }
}

/// Bottom navigation bar with stretching pill animation.
class _BottomNavBar extends StatefulWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Color primaryColor;
  final Color surfaceColor;
  final Color bgColor;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.primaryColor,
    required this.surfaceColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _prevIndex;
  double _pillLeft = 0;
  double _pillRight = 0;
  double _targetLeft = 0;
  double _targetRight = 0;
  double _startLeft = 0;
  double _startRight = 0;

  static const _pillWidthFraction = 0.65; // pill = 65% of slot width

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(_updatePill);
    // Initialize pill position
    _setPillToIndex(widget.currentIndex);
  }

  void _setPillToIndex(int index) {
    final n = widget.items.length;
    if (n == 0) return;
    final center = (index + 0.5) / n;
    final half = (0.5 / n) * _pillWidthFraction;
    _pillLeft = center - half;
    _pillRight = center + half;
    _startLeft = _pillLeft;
    _startRight = _pillRight;
    _targetLeft = _pillLeft;
    _targetRight = _pillRight;
  }

  void _animatePill(int from, int to) {
    final n = widget.items.length;
    if (n == 0) return;
    final fromCenter = (from + 0.5) / n;
    final toCenter = (to + 0.5) / n;
    final half = (0.5 / n) * _pillWidthFraction;

    _startLeft = fromCenter - half;
    _startRight = fromCenter + half;
    _targetLeft = toCenter - half;
    _targetRight = toCenter + half;

    _controller.forward(from: 0.0);
  }

  void _updatePill() {
    final t = _controller.value;
    final movingRight = _targetLeft > _startLeft;

    // Leading edge: Interval(0.0, 0.75) — starts fast
    // Trailing edge: Interval(0.25, 1.0) — starts delayed → stretch effect
    final leadingT = Curves.easeOutCubic.transform(
      ((t) / 0.75).clamp(0.0, 1.0),
    );
    final trailingT = Curves.easeOutCubic.transform(
      ((t - 0.25) / 0.75).clamp(0.0, 1.0),
    );

    setState(() {
      if (movingRight) {
        _pillLeft = _startLeft + (_targetLeft - _startLeft) * trailingT;
        _pillRight = _startRight + (_targetRight - _startRight) * leadingT;
      } else {
        _pillLeft = _startLeft + (_targetLeft - _startLeft) * leadingT;
        _pillRight = _startRight + (_targetRight - _startRight) * trailingT;
      }
    });
  }

  @override
  void didUpdateWidget(_BottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _animatePill(_prevIndex, widget.currentIndex);
      _prevIndex = widget.currentIndex;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: widget.bgColor,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Stretching pill
            Positioned.fill(
              child: CustomPaint(
                painter: _PillPainter(
                  pillLeft: _pillLeft,
                  pillRight: _pillRight,
                  pillColor: widget.primaryColor.withValues(alpha: 0.12),
                  pillHeight: 40,
                  pillRadius: 20,
                  barHeight: 64,
                ),
              ),
            ),
            // Nav items
            Row(
              children: [
                for (int i = 0; i < widget.items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              color: i == widget.currentIndex
                                  ? widget.primaryColor
                                  : widget.surfaceColor.withValues(alpha: 0.45),
                              size: 22,
                            ),
                            child: widget.items[i].icon,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Intl.message(widget.items[i].label.name),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 10,
                              fontWeight: i == widget.currentIndex
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: i == widget.currentIndex
                                  ? widget.primaryColor
                                  : widget.surfaceColor.withValues(alpha: 0.45),
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
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

/// Paints the stretching pill behind nav items.
class _PillPainter extends CustomPainter {
  final double pillLeft;
  final double pillRight;
  final Color pillColor;
  final double pillHeight;
  final double pillRadius;
  final double barHeight;

  _PillPainter({
    required this.pillLeft,
    required this.pillRight,
    required this.pillColor,
    required this.pillHeight,
    required this.pillRadius,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = pillLeft * size.width;
    final right = pillRight * size.width;
    final top = (barHeight - pillHeight) / 2 - 2;
    final rect = RRect.fromLTRBR(
      left, top, right, top + pillHeight, Radius.circular(pillRadius),
    );
    canvas.drawRRect(rect, Paint()..color = pillColor);
  }

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.pillLeft != pillLeft ||
      old.pillRight != pillRight ||
      old.pillColor != pillColor;
}
