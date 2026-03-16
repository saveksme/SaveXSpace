import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class BaseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    if (system.isDesktop) PointerDeviceKind.mouse,
    PointerDeviceKind.unknown,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    Widget result = child;

    // Wrap with smooth wheel scroll on desktop
    if (system.isDesktop && details.controller != null) {
      result = _SmoothWheelScroll(
        controller: details.controller!,
        child: result,
      );
    }

    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return result;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            assert(details.controller != null);
            return CommonScrollBar(
              controller: details.controller,
              child: result,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return result;
        }
    }
  }
}

/// Intercepts mouse wheel events and replaces the default instant jump
/// with smooth animated scroll by registering first with the resolver.
class _SmoothWheelScroll extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const _SmoothWheelScroll({
    required this.controller,
    required this.child,
  });

  @override
  State<_SmoothWheelScroll> createState() => _SmoothWheelScrollState();
}

class _SmoothWheelScrollState extends State<_SmoothWheelScroll> {
  double _targetOffset = 0;
  bool _isWheelScrolling = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleSmooth(PointerScrollEvent event) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final pos = controller.position;

    if (!_isWheelScrolling) {
      _targetOffset = pos.pixels;
      _isWheelScrolling = true;
    }

    _targetOffset = (_targetOffset + event.scrollDelta.dy)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);

    pos.animateTo(
      _targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 350), () {
      _isWheelScrolling = false;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final controller = widget.controller;
      if (!controller.hasClients) return;
      final pos = controller.position;
      if (pos.maxScrollExtent <= pos.minScrollExtent) return;

      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (PointerSignalEvent resolved) {
          if (resolved is PointerScrollEvent) {
            _handleSmooth(resolved);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

/// Replaces the Scrollable's default instant jump on mouse wheel
/// with a smooth animated scroll. Uses a custom ScrollPosition
/// that overrides pointerScroll to animate instead of jumping.
///
/// This approach is more reliable than pointerSignalResolver
/// because it works at the ScrollPosition level — no race conditions.
/// ScrollController that provides smooth mouse wheel scrolling.
/// Use as PrimaryScrollController or pass to any ScrollView.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  double _targetPixels = 0.0;
  bool _isSmoothScrolling = false;
  Timer? _resetTimer;

  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void pointerScroll(double delta) {
    // Replace the default jumpTo with animateTo for smooth wheel scroll
    if (delta == 0.0) return;

    if (!_isSmoothScrolling) {
      _targetPixels = pixels;
      _isSmoothScrolling = true;
    }

    _targetPixels = (_targetPixels + delta).clamp(
      minScrollExtent,
      maxScrollExtent,
    );

    animateTo(
      _targetPixels,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 350), () {
      _isSmoothScrolling = false;
    });
  }
}

class HiddenBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (system.isDesktop && details.controller != null) {
      return _SmoothWheelScroll(
        controller: details.controller!,
        child: child,
      );
    }
    return child;
  }
}

class ShowBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    Widget result = child;
    if (system.isDesktop && details.controller != null) {
      result = _SmoothWheelScroll(
        controller: details.controller!,
        child: result,
      );
    }
    return CommonScrollBar(controller: details.controller, child: result);
  }
}

class NextClampingScrollPhysics extends ClampingScrollPhysics {
  const NextClampingScrollPhysics({super.parent});

  @override
  NextClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NextClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        end!,
        end,
        min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}

class ReverseScrollController extends ScrollController {
  ReverseScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ReverseScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class ReverseScrollPosition extends ScrollPositionWithSingleContext {
  ReverseScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _isInit = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_isInit) {
      correctPixels(maxScrollExtent);
      _isInit = true;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
