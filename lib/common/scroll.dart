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
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.normal,
    );
  }

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
/// with a smooth animated scroll. Works by scheduling a microtask
/// that undoes the default jump and animates to the target instead.
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

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final controller = widget.controller;
      if (!controller.hasClients) return;
      final pos = controller.position;
      if (pos.maxScrollExtent <= pos.minScrollExtent) return;

      // Capture position before the default handler jumps
      final beforeJump = pos.pixels;

      if (!_isWheelScrolling) {
        _targetOffset = beforeJump;
        _isWheelScrolling = true;
      }

      _targetOffset = (_targetOffset + event.scrollDelta.dy)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);

      final target = _targetOffset;

      // After the default handler's jumpTo, undo it and animate smoothly.
      // scheduleMicrotask runs after dispatchEvent completes but before
      // the next frame renders, so the user never sees the jump.
      scheduleMicrotask(() {
        if (!controller.hasClients) return;
        final pos = controller.position;
        // Undo the default jump
        pos.jumpTo(beforeJump);
        // Animate smoothly to accumulated target
        pos.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      });

      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 350), () {
        _isWheelScrolling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.child,
    );
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
