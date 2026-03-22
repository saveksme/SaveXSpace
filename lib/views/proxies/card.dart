import 'dart:math' as math;
import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/services.dart';
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

// extractFlag is imported from package:fl_clash/common/proxy.dart via common.dart

/// Track which proxies have already animated in this session
final Set<String> _animatedProxies = {};

// ── Dashboard-matching palette (dark) ──
const _kCardBg = Color(0xFF0D0D0D);
const _kCardBorder = Color(0xFF1A1A1A);
const _kPillBg = Color(0xFF151515);
const _kOnSurface = Color(0xFFE6E1E5);
const _kOnSurfaceMuted = Color(0xFF666666);
const _kGood = Color(0xFF81D4A4);
const _kMedium = Color(0xFFF0C96D);
const _kBad = Color(0xFFF2918A);

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

class _ProxyCardState extends State<ProxyCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _enterController;

  Measure get measure => globalState.measure;

  @override
  void initState() {
    super.initState();
    final proxyKey = '${widget.groupName}/${widget.proxy.name}';
    final alreadySeen = _animatedProxies.contains(proxyKey);
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: alreadySeen ? 1.0 : 0.0,
    );
    if (!alreadySeen) {
      _animatedProxies.add(proxyKey);
      final stagger = math.min(widget.index * 25, 250);
      Future.delayed(Duration(milliseconds: stagger), () {
        if (mounted) _enterController.forward();
      });
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

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

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _enterController,
        curve: Curves.easeOut,
      ),
      child: _buildCard(primaryColor),
    );
  }

  Widget _buildCard(Color primaryColor) {
    final extracted = extractFlag(widget.proxy.name);
    final countryCode = extracted.countryCode;
    final displayName = extracted.name;

    return Consumer(
      builder: (context, ref, _) {
        final selectedProxyName = ref.watch(
          getSelectedProxyNameProvider(widget.groupName),
        );
        final isSelected = selectedProxyName == widget.proxy.name;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _changeProxy(ref);
          },
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.08)
                    : _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.3)
                      : _kCardBorder,
                ),
              ),
              child: Row(
                children: [
                  // Leading: circle flag or active indicator
                  _LeadingIndicator(
                    groupName: widget.groupName,
                    groupType: widget.groupType,
                    proxy: widget.proxy,
                    primaryColor: primaryColor,
                    isSelected: isSelected,
                    countryCode: countryCode,
                  ),
                  const SizedBox(width: 12),
                  // Name + protocol
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EmojiText(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : _kOnSurface,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.proxy.type,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kOnSurfaceMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delay pill
                  _DelayPill(
                    proxy: widget.proxy,
                    testUrl: widget.testUrl,
                    onTest: _handleTestCurrentDelay,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Leading circle indicator — shows drawn flag, active check, or globe
class _LeadingIndicator extends ConsumerWidget {
  final String groupName;
  final GroupType groupType;
  final Proxy proxy;
  final Color primaryColor;
  final bool isSelected;
  final String? countryCode;

  const _LeadingIndicator({
    required this.groupName,
    required this.groupType,
    required this.proxy,
    required this.primaryColor,
    required this.isSelected,
    this.countryCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isActive;
    if (groupType.isComputedSelected) {
      final proxyName = ref.watch(getProxyNameProvider(groupName));
      isActive = proxyName == proxy.name;
    } else {
      isActive = false;
    }

    // If we have a country code, show a drawn circular flag filling the circle
    if (countryCode != null) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            ClipOval(
              child: CircleFlag(countryCode!, size: 28),
            ),
            if (isActive)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // No flag — show check or globe in a circle
    Widget inner;
    if (isActive) {
      inner = Icon(
        Icons.check_rounded,
        key: const ValueKey('check'),
        size: 16,
        color: primaryColor,
      );
    } else {
      inner = Icon(
        Icons.public_rounded,
        key: const ValueKey('globe'),
        size: 14,
        color: _kOnSurfaceMuted.withValues(alpha: 0.5),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? primaryColor.withValues(alpha: 0.15)
            : isSelected
                ? primaryColor.withValues(alpha: 0.06)
                : _kPillBg,
        border: Border.all(
          color: isActive
              ? primaryColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: inner,
        ),
      ),
    );
  }
}

/// Delay shown as a styled pill/chip
class _DelayPill extends StatefulWidget {
  final Proxy proxy;
  final String? testUrl;
  final VoidCallback onTest;
  final Color primaryColor;

  const _DelayPill({
    required this.proxy,
    required this.testUrl,
    required this.onTest,
    required this.primaryColor,
  });

  @override
  State<_DelayPill> createState() => _DelayPillState();
}

class _DelayPillState extends State<_DelayPill>
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
      duration: const Duration(milliseconds: 450),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDelayChanged(int? delay) {
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
          getDelayProvider(
              proxyName: widget.proxy.name, testUrl: widget.testUrl),
        );

        _onDelayChanged(delay);

        // No data — tap to test
        if (delay == null) {
          return GestureDetector(
            onTap: widget.onTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kPillBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '— ms',
                style: TextStyle(
                  fontSize: 11,
                  color: _kOnSurfaceMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        // Testing in progress
        if (delay == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kPillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.primaryColor.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        // Result
        final color = _color(delay);
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOut,
          ),
          child: GestureDetector(
            onTap: widget.onTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Text(
                delay > 0 ? '${delay}ms' : '--',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        );
      },
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
          color: _kOnSurfaceMuted,
        ),
      ),
    );
  }
}
