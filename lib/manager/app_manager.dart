import 'dart:async';
import 'dart:io';

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
import 'package:window_manager/window_manager.dart';

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

    // On Windows, the window with hidden title bar can extend behind the
    // taskbar when maximized. Use viewPadding to detect system insets.
    // If Flutter reports 0, check if the window bottom edge is near the
    // screen bottom and add safety padding.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Column(
      children: [
        Expanded(child: widget.child),
        _BottomNavBar(
          items: navigationItems,
          currentIndex: currentIndex,
          primaryColor: primaryColor,
          surfaceColor: context.colorScheme.onSurface,
          bgColor: const Color(0xFF050505),
          onTap: (index) {
            HapticFeedback.selectionClick();
            appController.toPage(navigationItems[index].label);
          },
        ),
        if (bottomInset > 0)
          SizedBox(height: bottomInset),
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

  static const _pillFixedWidth = 56.0; // fixed pill width in pixels

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
    // Store just the normalized center position
    final center = (index + 0.5) / n;
    _pillLeft = center;
    _pillRight = center;
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

    _startLeft = fromCenter;
    _startRight = fromCenter;
    _targetLeft = toCenter;
    _targetRight = toCenter;

    _controller.forward(from: 0.0);
  }

  void _updatePill() {
    final t = _controller.value;
    final movingRight = _targetLeft > _startLeft;

    // Leading edge moves first, trailing delays → pill stretches then snaps
    final leadingT = Curves.easeOutCubic.transform(
      (t / 0.75).clamp(0.0, 1.0),
    );
    final trailingT = Curves.easeOutCubic.transform(
      ((t - 0.25) / 0.75).clamp(0.0, 1.0),
    );

    // Animate the CENTER positions of leading and trailing edges
    final leadingCenter = movingRight
        ? _startLeft + (_targetLeft - _startLeft) * leadingT
        : _startLeft + (_targetLeft - _startLeft) * leadingT;
    final trailingCenter = movingRight
        ? _startRight + (_targetRight - _startRight) * trailingT
        : _startRight + (_targetRight - _startRight) * trailingT;

    setState(() {
      if (movingRight) {
        _pillLeft = trailingCenter;  // trailing (left) delays
        _pillRight = leadingCenter;  // leading (right) goes first
      } else {
        _pillLeft = leadingCenter;   // leading (left) goes first
        _pillRight = trailingCenter; // trailing (right) delays
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      color: const Color(0xFF050505),
      child: Stack(
          children: [
            // Stretching pill
            Positioned.fill(
              child: CustomPaint(
                painter: _PillPainter(
                  pillLeft: _pillLeft,
                  pillRight: _pillRight,
                  pillColor: widget.primaryColor.withValues(alpha: 0.15),
                  pillFixedWidth: _pillFixedWidth,
                  pillHeight: 32,
                  pillRadius: 16,
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
    );
  }
}

/// Paints the stretching pill behind nav items.
/// pillLeft/pillRight are normalized center positions (0.0-1.0).
/// During animation they diverge to create stretch effect.
class _PillPainter extends CustomPainter {
  final double pillLeft;
  final double pillRight;
  final Color pillColor;
  final double pillFixedWidth;
  final double pillHeight;
  final double pillRadius;
  final double barHeight;

  _PillPainter({
    required this.pillLeft,
    required this.pillRight,
    required this.pillColor,
    required this.pillFixedWidth,
    required this.pillHeight,
    required this.pillRadius,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = pillFixedWidth / 2;
    // Convert normalized centers to pixel positions
    final leftCenter = pillLeft * size.width;
    final rightCenter = pillRight * size.width;
    // Left edge = leftmost center - half, Right edge = rightmost center + half
    final left = leftCenter - halfW;
    final right = rightCenter + halfW;
    final top = (barHeight - pillHeight) / 2 - 8;
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
