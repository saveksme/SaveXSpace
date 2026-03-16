import 'dart:ui';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Minimal palette ──
const _kCardBg = Color(0xFF0E0E11);
const _kCardBorder = Color(0xFF1A1A1F);
const _kSelectedBorder = Color(0xFF2A2A35);
const _kTextPrimary = Color(0xDEFFFFFF);
const _kTextMuted = Color(0x4DFFFFFF);
const _kGood = Color(0xFF34D399);
const _kMedium = Color(0xFFFBBF24);
const _kBad = Color(0xFFF87171);

class ProxyCard extends StatefulWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;
  final int index;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
    this.index = 0,
  });

  @override
  State<ProxyCard> createState() => _ProxyCardState();
}

class _ProxyCardState extends State<ProxyCard> {
  bool _pressed = false;

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay() {
    proxyDelayTest(widget.proxy, widget.testUrl);
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = widget.groupType.isComputedSelected;
    final isSelector = widget.groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName =
          ref.read(getProxyNameProvider(widget.groupName));
      final nextProxyName = switch (isComputedSelected) {
        true =>
          currentProxyName == widget.proxy.name ? '' : widget.proxy.name,
        false => widget.proxy.name,
      };
      appController.updateCurrentSelectedMap(
          widget.groupName, nextProxyName);
      appController.changeProxyDebounce(widget.groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(appLocalizations.notSelectedTip);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Consumer(
      builder: (context, ref, _) {
        final selectedProxyName = ref.watch(
          getSelectedProxyNameProvider(widget.groupName),
        );
        final isSelected = selectedProxyName == widget.proxy.name;

        return GestureDetector(
          onTap: () => _changeProxy(ref),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.06)
                    : _kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.35)
                      : _kCardBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: name + delay
                  Row(
                    children: [
                      // Active indicator
                      if (widget.groupType.isComputedSelected)
                        _ActiveIndicator(
                          groupName: widget.groupName,
                          proxy: widget.proxy,
                          primaryColor: primaryColor,
                        ),
                      // Name
                      Expanded(
                        child: _buildName(isSelected, primaryColor),
                      ),
                      const SizedBox(width: 8),
                      // Delay
                      _DelayText(
                        proxy: widget.proxy,
                        testUrl: widget.testUrl,
                        onTest: _handleTestCurrentDelay,
                      ),
                    ],
                  ),
                  if (widget.type == ProxyCardType.expand) ...[
                    const SizedBox(height: 2),
                    _ProxyDesc(proxy: widget.proxy),
                  ],
                  const Spacer(),
                  // Row 2: protocol type
                  Text(
                    widget.proxy.type,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _kTextMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildName(bool isSelected, Color primaryColor) {
    final maxLines = widget.type == ProxyCardType.min ? 1 : 2;
    return SizedBox(
      height: measure.bodyMediumHeight * maxLines,
      child: EmojiText(
        widget.proxy.name,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? Colors.white : _kTextPrimary,
        ),
      ),
    );
  }
}

/// Delay text with blur reveal animation when value appears
class _DelayText extends StatefulWidget {
  final Proxy proxy;
  final String? testUrl;
  final VoidCallback onTest;

  const _DelayText({
    required this.proxy,
    required this.testUrl,
    required this.onTest,
  });

  @override
  State<_DelayText> createState() => _DelayTextState();
}

class _DelayTextState extends State<_DelayText>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int? _lastDelay;

  static Color _color(int delay) {
    if (delay < 0) return _kBad;
    if (delay < 300) return _kGood;
    if (delay < 600) return _kMedium;
    return _kBad;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDelayChanged(int? delay) {
    // Animate when transitioning from testing (0) to a real value
    if (_lastDelay == 0 && delay != null && delay != 0) {
      _animController.forward(from: 0.0);
    }
    _lastDelay = delay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final delay = ref.watch(
          getDelayProvider(proxyName: widget.proxy.name, testUrl: widget.testUrl),
        );

        _onDelayChanged(delay);

        if (delay == null) {
          return GestureDetector(
            onTap: widget.onTest,
            child: const Text(
              '\u2014',
              style: TextStyle(fontSize: 11, color: _kTextMuted),
            ),
          );
        }

        if (delay == 0) {
          return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: _kTextMuted,
            ),
          );
        }

        final color = _color(delay);
        return AnimatedBuilder(
          animation: _animController,
          builder: (_, child) {
            final t = Curves.easeOutCubic.transform(_animController.value);
            final blur = (1.0 - t) * 6.0;
            Widget result = child!;
            if (blur > 0.3) {
              result = ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                  tileMode: TileMode.decal,
                ),
                child: result,
              );
            }
            return Opacity(opacity: t.clamp(0.0, 1.0), child: result);
          },
          child: GestureDetector(
            onTap: widget.onTest,
            child: Text(
              delay > 0 ? '${delay}ms' : '---',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small active dot inline before name
class _ActiveIndicator extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final Color primaryColor;

  const _ActiveIndicator({
    required this.groupName,
    required this.proxy,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(getProxyNameProvider(groupName));
    if (proxyName != proxy.name) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primaryColor,
        ),
      ),
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;

  const _ProxyDesc({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(getProxyDescProvider(proxy));
    return SizedBox(
      height: globalState.measure.bodySmallHeight,
      child: EmojiText(
        desc,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          color: _kTextMuted,
        ),
      ),
    );
  }
}
