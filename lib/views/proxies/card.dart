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

const _kCardBg = Color(0xFF0A0A0A);
const _kCardBorder = Color(0xFF1A1A1A);
const _kTextPrimary = Color(0xDEFFFFFF);
const _kTextSecondary = Color(0x59FFFFFF);
const _kGoodDelay = Color(0xFF4ADE80);
const _kMediumDelay = Color(0xFFFBBF24);
const _kBadDelay = Color(0xFFEF4444);

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
  late final AnimationController _selectController;
  late final Animation<double> _selectBounce;
  bool _wasSelected = false;

  Measure get measure => globalState.measure;

  @override
  void initState() {
    super.initState();
    _selectController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _selectBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.03), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 40),
    ]).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _selectController.dispose();
    super.dispose();
  }

  void _handleTestCurrentDelay() {
    proxyDelayTest(widget.proxy, widget.testUrl);
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = widget.groupType.isComputedSelected;
    final isSelector = widget.groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(getProxyNameProvider(widget.groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == widget.proxy.name ? '' : widget.proxy.name,
        false => widget.proxy.name,
      };
      appController.updateCurrentSelectedMap(widget.groupName, nextProxyName);
      appController.changeProxyDebounce(widget.groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(appLocalizations.notSelectedTip);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return _StaggeredFadeSlide(
      index: widget.index,
      child: Consumer(
        builder: (context, ref, _) {
          final selectedProxyName = ref.watch(
            getSelectedProxyNameProvider(widget.groupName),
          );
          final isSelected = selectedProxyName == widget.proxy.name;

          // Trigger bounce animation when this card becomes selected
          if (isSelected && !_wasSelected) {
            _selectController.forward(from: 0.0);
          }
          _wasSelected = isSelected;

          return GestureDetector(
            onTap: () => _changeProxy(ref),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedBuilder(
              animation: _selectBounce,
              builder: (context, child) {
                final bounceScale = _selectController.isAnimating
                    ? _selectBounce.value
                    : 1.0;
                final pressScale = _pressed ? 0.96 : 1.0;
                return Transform.scale(
                  scale: bounceScale * pressScale,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.08)
                      : _kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.35)
                        : _kCardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: const [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + active dot
                    Row(
                      children: [
                        Expanded(
                          child: _buildProxyName(context, isSelected, primaryColor),
                        ),
                        if (widget.groupType.isComputedSelected)
                          _ActiveDot(
                            groupName: widget.groupName,
                            proxy: widget.proxy,
                          ),
                      ],
                    ),
                    if (widget.type == ProxyCardType.expand) ...[
                      const SizedBox(height: 3),
                      _ProxyDesc(proxy: widget.proxy),
                    ],
                    const Spacer(),
                    // Bottom: type + delay
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.proxy.type,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.5)
                                  : _kTextSecondary,
                            ),
                          ),
                        ),
                        _DelayText(
                          proxy: widget.proxy,
                          testUrl: widget.testUrl,
                          onTest: _handleTestCurrentDelay,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProxyName(
    BuildContext context,
    bool isSelected,
    Color primaryColor,
  ) {
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

/// Staggered entrance: fade + subtle slide up
class _StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredFadeSlide({required this.index, required this.child});

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    final delay = Duration(milliseconds: (widget.index * 25).clamp(0, 250));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

/// Delay chip with animated appearance
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
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  int? _previousDelay;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.value = 1.0;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerAnimation(int? delay) {
    if (_previousDelay == 0 && delay != null && delay != 0) {
      _animController.forward(from: 0.0);
    }
    _previousDelay = delay;
  }

  Color _getDelayColor(int delay) {
    if (delay < 0) return _kBadDelay;
    if (delay < 300) return _kGoodDelay;
    if (delay < 600) return _kMediumDelay;
    return _kBadDelay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final delay = ref.watch(
          getDelayProvider(proxyName: widget.proxy.name, testUrl: widget.testUrl),
        );

        _triggerAnimation(delay);

        if (delay == null) {
          return GestureDetector(
            onTap: widget.onTest,
            child: const Icon(
              Icons.speed_rounded,
              size: 14,
              color: _kTextSecondary,
            ),
          );
        }

        if (delay == 0) {
          return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: _kTextSecondary,
            ),
          );
        }

        final color = _getDelayColor(delay);
        return ScaleTransition(
          scale: _scaleAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onTap: widget.onTest,
              child: Text(
                delay > 0 ? '${delay}ms' : 'fail',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Active dot with gentle opacity pulse
class _ActiveDot extends ConsumerStatefulWidget {
  final String groupName;
  final Proxy proxy;

  const _ActiveDot({required this.groupName, required this.proxy});

  @override
  ConsumerState<_ActiveDot> createState() => _ActiveDotState();
}

class _ActiveDotState extends ConsumerState<_ActiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final proxyName = ref.watch(getProxyNameProvider(widget.groupName));
    if (proxyName != widget.proxy.name) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
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
          fontSize: 11,
          color: _kTextSecondary,
        ),
      ),
    );
  }
}
