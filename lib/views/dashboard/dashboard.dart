import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    final isStart = ref.read(isStartProvider);
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
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
                    if (isStart) ...[
                      _SpeedCard(primaryColor: primaryColor),
                      const SizedBox(height: 12),
                      _TrafficCard(primaryColor: primaryColor),
                    ],
                    const SizedBox(height: 12),
                    _SubscriptionCard(primaryColor: primaryColor),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final Color primaryColor;

  const _ConnectButton({
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
    required this.pulseAnimation,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 140.0;
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: AnimatedBuilder(
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
                : const Color(0xFF1A1A1A),
            border: Border.all(
              color: isConnected
                  ? primaryColor.withValues(alpha: 0.6)
                  : const Color(0xFF2A2A2A),
              width: 3,
            ),
            boxShadow: isConnected
                ? [BoxShadow(color: primaryColor.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 5)]
                : [],
          ),
          child: Center(
            child: isConnecting
                ? SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor),
                  )
                : Icon(
                    Icons.power_settings_new,
                    size: 48,
                    color: isConnected ? primaryColor : Colors.white38,
                  ),
          ),
        ),
      ),
    );
  }
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

// Total traffic usage card (compact row)
class _TrafficCard extends ConsumerWidget {
  final Color primaryColor;
  const _TrafficCard({required this.primaryColor});

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
            '\u2191 ${totalTraffic.up.traffic.show}',
            style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Text(
            '\u2193 ${totalTraffic.down.traffic.show}',
            style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            appLocalizations.trafficUsage,
            style: const TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// Subscription info card (always visible)
class _SubscriptionCard extends ConsumerWidget {
  final Color primaryColor;
  const _SubscriptionCard({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    final sub = profile.subscriptionInfo;
    final label = profile.label.isNotEmpty ? profile.label : profile.url;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${((sub.upload + sub.download) as num).traffic.show} / ${(sub.total as num).traffic.show}',
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ),
                if (sub.expire > 0)
                  Text(
                    _formatExpiry(sub.expire),
                    style: TextStyle(fontSize: 11, color: _expiryColor(sub.expire)),
                  ),
              ],
            ),
          ],
          if (profile.lastUpdateDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Обновлено: ${_formatDate(profile.lastUpdateDate!)}',
              style: const TextStyle(fontSize: 10, color: Colors.white24),
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiry(int expireTimestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000);
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 30) return '${diff.inDays} d';
    if (diff.inDays > 0) return '${diff.inDays} d';
    if (diff.inHours > 0) return '${diff.inHours} h';
    return '< 1h';
  }

  Color _expiryColor(int expireTimestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000);
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
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: ratio,
          backgroundColor: const Color(0xFF1A1A1A),
          valueColor: AlwaysStoppedAnimation<Color>(barColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}
