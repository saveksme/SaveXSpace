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

// Design constants
const _kCardBg = Color(0xFF0D0D0D);
const _kCardBorder = Color(0xFF1A1A1A);
const _kGoodDelay = Color(0xFF4ADE80);
const _kMediumDelay = Color(0xFFC57F0A);
const _kBadDelay = Color(0xFFEF4444);

class ProxyCard extends StatelessWidget {
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

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay() {
    proxyDelayTest(proxy, testUrl);
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(getProxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? '' : proxy.name,
        false => proxy.name,
      };
      appController.updateCurrentSelectedMap(groupName, nextProxyName);
      appController.changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(appLocalizations.notSelectedTip);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return _StaggeredFadeSlide(
      index: index,
      child: Consumer(
        builder: (context, ref, _) {
          final selectedProxyName = ref.watch(
            getSelectedProxyNameProvider(groupName),
          );
          final isSelected = selectedProxyName == proxy.name;

          return GestureDetector(
            onTap: () => _changeProxy(ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.10)
                    : _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.35)
                      : _kCardBorder,
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Left accent bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: isSelected ? 3 : 0,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProxyName(context, isSelected, primaryColor),
                        const SizedBox(height: 6),
                        if (type == ProxyCardType.expand) ...[
                          _ProxyDesc(proxy: proxy),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                proxy.type,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 11,
                                  color: Colors.white24,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            _DelayChip(
                              proxy: proxy,
                              testUrl: testUrl,
                              onTest: _handleTestCurrentDelay,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (groupType.isComputedSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ActivePulseDot(
                        groupName: groupName,
                        proxy: proxy,
                      ),
                    ),
                ],
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
    final maxLines = type == ProxyCardType.min ? 1 : 2;
    return SizedBox(
      height: measure.bodyMediumHeight * maxLines,
      child: EmojiText(
        proxy.name,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isSelected ? primaryColor : Colors.white70,
        ),
      ),
    );
  }
}

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
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    final delay = Duration(milliseconds: (widget.index * 30).clamp(0, 300));
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
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _DelayChip extends StatelessWidget {
  final Proxy proxy;
  final String? testUrl;
  final VoidCallback onTest;

  const _DelayChip({
    required this.proxy,
    required this.testUrl,
    required this.onTest,
  });

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
          getDelayProvider(proxyName: proxy.name, testUrl: testUrl),
        );

        if (delay == null) {
          return GestureDetector(
            onTap: onTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.bolt, size: 14, color: Colors.white24),
            ),
          );
        }

        if (delay == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38),
            ),
          );
        }

        final color = _getDelayColor(delay);
        return GestureDetector(
          onTap: onTest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              delay > 0 ? '${delay}ms' : 'timeout',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivePulseDot extends ConsumerStatefulWidget {
  final String groupName;
  final Proxy proxy;

  const _ActivePulseDot({required this.groupName, required this.proxy});

  @override
  ConsumerState<_ActivePulseDot> createState() => _ActivePulseDotState();
}

class _ActivePulseDotState extends ConsumerState<_ActivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.4).animate(
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
    final proxyName = ref.watch(getProxyNameProvider(widget.groupName));
    if (proxyName != widget.proxy.name) return const SizedBox.shrink();
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _kGoodDelay,
          boxShadow: [
            BoxShadow(color: Color(0x404ADE80), blurRadius: 4, spreadRadius: 1),
          ],
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
          fontFamily: 'SpaceGrotesk',
          fontSize: 11,
          color: Colors.white24,
        ),
      ),
    );
  }
}
