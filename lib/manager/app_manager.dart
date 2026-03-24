import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/pages/home.dart' show pageScrollNotifier;
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
  double _pillLeft = 0;
  double _pillRight = 0;
  bool _isTapAnimating = false;
  int? _targetIndex; // stable target during tap animation (ignores intermediate page changes)

  // For tap stretch animation
  late AnimationController _tapController;
  double _startLeft = 0;
  double _startRight = 0;
  double _targetLeft = 0;
  double _targetRight = 0;

  static const _pillFixedWidth = 56.0;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(_updateTapPill)
     ..addStatusListener(_onTapAnimationStatus);
    _setPillSnap(widget.currentIndex);
    pageScrollNotifier.addListener(_onPageScroll);
  }

  void _setPillSnap(int index) {
    final n = widget.items.length;
    if (n == 0) return;
    final center = (index + 0.5) / n;
    _pillLeft = center;
    _pillRight = center;
  }

  void _animateTap(int from, int to) {
    final n = widget.items.length;
    if (n == 0) return;
    final fromCenter = (_pillLeft + _pillRight) / 2; // current visual center
    final toCenter = (to + 0.5) / n;

    _startLeft = fromCenter;
    _startRight = fromCenter;
    _targetLeft = toCenter;
    _targetRight = toCenter;
    _isTapAnimating = true;
    _tapController.forward(from: 0.0);
  }

  void _updateTapPill() {
    final t = _tapController.value;
    final movingRight = _targetLeft > _startLeft;

    final leadingT = Curves.easeOutCubic.transform((t / 0.75).clamp(0.0, 1.0));
    final trailingT = Curves.easeOutCubic.transform(((t - 0.25) / 0.75).clamp(0.0, 1.0));

    final leadingCenter = _startLeft + (_targetLeft - _startLeft) * leadingT;
    final trailingCenter = _startRight + (_targetRight - _startRight) * trailingT;

    setState(() {
      if (movingRight) {
        _pillLeft = trailingCenter;
        _pillRight = leadingCenter;
      } else {
        _pillLeft = leadingCenter;
        _pillRight = trailingCenter;
      }
    });
  }

  void _onTapAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Snap pill to exact target position
      _setPillSnap(_targetIndex ?? widget.currentIndex);
      _targetIndex = null;
      // Release scroll lock after a microtask so page animation can settle
      Future.microtask(() {
        if (mounted) setState(() => _isTapAnimating = false);
      });
    }
  }

  void _onPageScroll() {
    if (_isTapAnimating) return; // ignore scroll during tap animation

    final n = widget.items.length;
    if (n == 0) return;
    final page = pageScrollNotifier.value.clamp(0.0, (n - 1).toDouble());

    final currentIndex = page.floor();
    final nextIndex = (currentIndex + 1).clamp(0, n - 1);
    final fraction = page - currentIndex;

    final currentCenter = (currentIndex + 0.5) / n;
    final nextCenter = (nextIndex + 0.5) / n;
    final baseCenter = currentCenter + (nextCenter - currentCenter) * fraction;

    if (fraction < 0.01 || fraction > 0.99 || currentIndex == nextIndex) {
      setState(() {
        _pillLeft = baseCenter;
        _pillRight = baseCenter;
      });
    } else {
      final stretchAmount = 0.3 * (0.5 - (fraction - 0.5).abs()) * 2;
      final halfStretch = stretchAmount / n;
      setState(() {
        if (nextCenter > currentCenter) {
          _pillLeft = baseCenter - halfStretch * (1 - fraction);
          _pillRight = baseCenter + halfStretch * fraction;
        } else {
          _pillLeft = baseCenter - halfStretch * fraction;
          _pillRight = baseCenter + halfStretch * (1 - fraction);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_BottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      if (_isTapAnimating) {
        // If already animating AND the new index differs from current target,
        // retarget the animation (user tapped another item mid-animation)
        if (_targetIndex != null && _targetIndex != widget.currentIndex) {
          _targetIndex = widget.currentIndex;
          _retargetAnimation(widget.currentIndex);
        }
        // Otherwise ignore — intermediate page changes from PageView
      } else {
        _targetIndex = widget.currentIndex;
        _animateTap(old.currentIndex, widget.currentIndex);
      }
    }
    if (old.items.length != widget.items.length) {
      _setPillSnap(widget.currentIndex);
    }
  }

  void _retargetAnimation(int newTarget) {
    final n = widget.items.length;
    if (n == 0) return;
    // Capture current visual position as the new start
    _startLeft = _pillLeft;
    _startRight = _pillRight;
    final toCenter = (newTarget + 0.5) / n;
    _targetLeft = toCenter;
    _targetRight = toCenter;
    _tapController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _tapController.dispose();
    pageScrollNotifier.removeListener(_onPageScroll);
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
                  pillFixedWidth: _pillFixedWidth - 8,
                  pillHeight: 24,
                  pillRadius: 12,
                  barHeight: 64,
                ),
              ),
            ),
            // Nav items — use _targetIndex during tap animation to avoid
            // intermediate page changes flashing icons/text
            Builder(builder: (context) {
              final selectedIndex = _targetIndex ?? widget.currentIndex;
              return Row(
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
                                color: i == selectedIndex
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
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: i == selectedIndex
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
              );
            }),
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
