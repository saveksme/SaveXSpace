import 'dart:math' as math;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'edit.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView>
    with SingleTickerProviderStateMixin {
  bool _isUpdating = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: '${appLocalizations.add}${appLocalizations.profile}',
        );
      },
    );
  }

  Future<void> _updateProfile(Profile profile) async {
    if (_isUpdating) return;
    _isUpdating = true;
    try {
      await appController.loadingRun(() async {
        await appController.updateProfile(profile, showLoading: true);
      }, tag: LoadingTag.profiles);
    } catch (_) {}
    _isUpdating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final profiles = ref.watch(profilesProvider);
        final currentProfileId = ref.watch(currentProfileIdProvider);
        final profile = profiles.isNotEmpty
            ? profiles.firstWhere(
                (p) => p.id == currentProfileId,
                orElse: () => profiles.first,
              )
            : null;

        return CommonScaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          actions: [],
          body: FadeTransition(
            opacity: _fadeAnim,
            child: profiles.isEmpty
                ? _EmptyState(onAdd: _handleShowAddExtendPage)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in profiles) ...[
                          _ActiveSubscriptionCard(
                            profile: p,
                            isSelected: p.id == currentProfileId,
                            onSelect: () {
                              ref.read(currentProfileIdProvider.notifier).value = p.id;
                            },
                            onUpdate: () => _updateProfile(p),
                            onEdit: () => _handleShowEditExtendPage(p),
                            onDelete: () => _handleDeleteProfile(p),
                            onOverride: () => _handleShowOverridePage(p),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _AddNewButton(onTap: _handleShowAddExtendPage),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _handleShowOverridePage(Profile profile) {
    BaseNavigator.push(context, OverwriteView(profileId: profile.id));
  }

  void _handleShowEditExtendPage(Profile profile) {
    showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: EditProfileView(profile: profile, context: context),
          title: '${appLocalizations.edit}${appLocalizations.profile}',
        );
      },
    );
  }

  Future<void> _handleDeleteProfile(Profile profile) async {
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) return;
    await appController.deleteProfile(profile.id);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.08),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Icon(Icons.add_link_rounded, size: 36, color: primaryColor.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          Text(
            appLocalizations.nullProfileDesc,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              appLocalizations.addProfile,
              style: const TextStyle(fontFamily: 'SpaceGrotesk'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSubscriptionCard extends StatefulWidget {
  final Profile profile;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOverride;

  const _ActiveSubscriptionCard({
    required this.profile,
    this.isSelected = true,
    required this.onSelect,
    required this.onUpdate,
    required this.onEdit,
    required this.onDelete,
    required this.onOverride,
  });

  @override
  State<_ActiveSubscriptionCard> createState() => _ActiveSubscriptionCardState();
}

class _ActiveSubscriptionCardState extends State<_ActiveSubscriptionCard>
    with TickerProviderStateMixin {
  late AnimationController _successController;
  late AnimationController _shimmerController;
  bool _wasUpdating = false;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _triggerSuccessAnimation() {
    _successController.forward(from: 0.0);
    _shimmerController.forward(from: 0.0);
  }

  Profile get profile => widget.profile;
  bool get isSelected => widget.isSelected;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final sub = profile.subscriptionInfo;
    final hasData = sub != null && sub.total > 0;
    final used = hasData ? sub.upload + sub.download : 0;
    final total = hasData ? sub.total : 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final borderColor = isSelected
        ? primaryColor.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.08);
    final bgAlpha = isSelected ? 0.12 : 0.03;

    return GestureDetector(
      onTap: isSelected ? null : widget.onSelect,
      child: AnimatedBuilder(
        animation: Listenable.merge([_successController, _shimmerController]),
        builder: (context, child) {
          final successGlow = Curves.easeOut.transform(
            _successController.value < 0.5
                ? _successController.value * 2
                : 2.0 - _successController.value * 2,
          );
          final shimmerPos = _shimmerController.value;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    primaryColor.withValues(alpha: bgAlpha),
                    primaryColor.withValues(alpha: 0.25),
                    successGlow,
                  )!,
                  const Color(0xFF0D0D0D),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  borderColor,
                  primaryColor.withValues(alpha: 0.6),
                  successGlow,
                )!,
              ),
              boxShadow: [
                if (successGlow > 0)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15 * successGlow),
                    blurRadius: 20 * successGlow,
                    spreadRadius: 2 * successGlow,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Content
                  child!,
                  // Shimmer sweep overlay
                  if (shimmerPos > 0 && shimmerPos < 1.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.0 + 3.0 * shimmerPos, 0.0),
                              end: Alignment(-0.7 + 3.0 * shimmerPos, 0.0),
                              colors: [
                                Colors.transparent,
                                primaryColor.withValues(alpha: 0.06),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withValues(alpha: 0.5)],
                    ),
                  ),
                  child: const Icon(Icons.shield_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.realLabel,
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isSaveXHost) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showSaveXDialog(context, primaryColor),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/savex_logo.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 11,
                          color: _statusColor(),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (_, ref, _) {
                    final isUpdating = ref.watch(
                      isUpdatingProvider(profile.updatingKey),
                    );
                    // Detect update completion
                    if (_wasUpdating && !isUpdating) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _triggerSuccessAnimation();
                      });
                    }
                    _wasUpdating = isUpdating;

                    return isUpdating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.refresh_rounded, color: primaryColor.withValues(alpha: 0.7)),
                            onPressed: widget.onUpdate,
                          );
                  },
                ),
              ],
            ),
          ),

          // Announce banner
          if (profile.announce != null && profile.announce!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, size: 16, color: primaryColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.announce!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Data usage
          if (hasData) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${used.traffic.show} / ${total.traffic.show}',
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _barColor(ratio, primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: const Color(0xFF1A1A1A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _barColor(ratio, primaryColor).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.arrow_upward_rounded,
                    label: sub.upload.traffic.show,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.arrow_downward_rounded,
                    label: sub.download.traffic.show,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ],

          // Expiry + last update row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(
              children: [
                // Last update (left)
                if (profile.lastUpdateDate != null) ...[
                  const Icon(Icons.update_rounded, size: 12, color: Colors.white24),
                  const SizedBox(width: 5),
                  Text(
                    _formatDate(profile.lastUpdateDate!),
                    style: const TextStyle(fontSize: 11, color: Colors.white24),
                  ),
                ],
                const Spacer(),
                // Expire badge (right)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _expireBadgeBg(sub, primaryColor),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _expireBadgeBorder(sub, primaryColor),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInfinite(sub) ? Icons.all_inclusive_rounded : Icons.timer_outlined,
                        size: 12,
                        color: _expireBadgeText(sub, primaryColor),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _expireDisplayText(sub),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _expireBadgeText(sub, primaryColor),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Provider info
          _buildRegularProviderRow(primaryColor),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Правила',
                  onTap: widget.onOverride,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: appLocalizations.edit,
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: appLocalizations.delete,
                  onTap: widget.onDelete,
                  isDanger: true,
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Color _barColor(double ratio, Color primary) {
    if (ratio > 0.9) return Colors.red;
    if (ratio > 0.7) return Colors.amber;
    return primary;
  }

  String _statusText() {
    final sub = profile.subscriptionInfo;
    if (sub == null || sub.total == 0) return 'Активна';
    if (sub.expire > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000);
      if (date.year >= 2099) return 'Активна';
      if (date.isBefore(DateTime.now())) return 'Истекла';
    }
    return 'Активна';
  }

  Color _statusColor() {
    final sub = profile.subscriptionInfo;
    if (sub == null || sub.total == 0) return const Color(0xFF4ADE80);
    if (sub.expire > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000);
      if (date.isBefore(DateTime.now())) return Colors.red;
      if (date.difference(DateTime.now()).inDays < 3) return Colors.amber;
    }
    return const Color(0xFF4ADE80);
  }

  String _formatExpiry(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    if (date.year >= 2099) return 'Бесконечная';
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'Истекла';
    if (diff.inDays > 30) return '${diff.inDays} дн';
    if (diff.inDays > 0) return '${diff.inDays} дн';
    if (diff.inHours > 0) return '${diff.inHours} ч';
    return '< 1ч';
  }

  Color _expiryColor(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    if (date.year >= 2099) return Colors.white38;
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.red;
    if (diff.inDays < 3) return Colors.amber;
    return Colors.white38;
  }

  bool _isInfinite(SubscriptionInfo? sub) {
    if (sub == null || sub.expire == 0) return true;
    return DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000).year >= 2099;
  }

  String _expireDisplayText(SubscriptionInfo? sub) {
    if (_isInfinite(sub)) return 'Бесконечная';
    return _formatExpiry(sub!.expire);
  }

  Color _expireBadgeBg(SubscriptionInfo? sub, Color primary) {
    if (_isInfinite(sub)) return Colors.white.withValues(alpha: 0.04);
    final date = DateTime.fromMillisecondsSinceEpoch(sub!.expire * 1000);
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.red.withValues(alpha: 0.1);
    if (diff.inDays < 3) return Colors.amber.withValues(alpha: 0.08);
    return primary.withValues(alpha: 0.06);
  }

  Color _expireBadgeBorder(SubscriptionInfo? sub, Color primary) {
    if (_isInfinite(sub)) return Colors.white.withValues(alpha: 0.08);
    final date = DateTime.fromMillisecondsSinceEpoch(sub!.expire * 1000);
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.red.withValues(alpha: 0.2);
    if (diff.inDays < 3) return Colors.amber.withValues(alpha: 0.15);
    return primary.withValues(alpha: 0.12);
  }

  Color _expireBadgeText(SubscriptionInfo? sub, Color primary) {
    if (_isInfinite(sub)) return Colors.white.withValues(alpha: 0.5);
    final date = DateTime.fromMillisecondsSinceEpoch(sub!.expire * 1000);
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.red.withValues(alpha: 0.9);
    if (diff.inDays < 3) return Colors.amber.withValues(alpha: 0.9);
    return primary.withValues(alpha: 0.8);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  bool get _isSaveXHost {
    if (profile.url.isEmpty) return false;
    final host = Uri.tryParse(profile.url)?.host ?? '';
    return host == 'sub.savex.space';
  }

  Widget _buildSaveXBadge(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: () => _showSaveXDialog(context, primaryColor),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                primaryColor.withValues(alpha: 0.10),
                primaryColor.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/savex_logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SaveX',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isSaveXDialogOpen = false;

  void _showSaveXDialog(BuildContext context, Color primaryColor) {
    if (_isSaveXDialogOpen) return;
    _isSaveXDialogOpen = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SaveX',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim, secondAnim) {
        return _SaveXParticleDialog(
          primaryColor: primaryColor,
          animation: anim,
        );
      },
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return child;
      },
    ).then((_) {
      _isSaveXDialogOpen = false;
    });
  }

  Widget _buildRegularProviderRow(Color primaryColor) {
    final host = profile.url.isNotEmpty
        ? Uri.tryParse(profile.url)?.host ?? profile.url
        : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Icon(
            profile.url.isNotEmpty ? Icons.cloud_outlined : Icons.folder_outlined,
            size: 12,
            color: Colors.white24,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              profile.url.isNotEmpty ? host : 'Локальный профиль',
              style: const TextStyle(fontSize: 11, color: Colors.white24),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red.withValues(alpha: 0.6) : Colors.white38;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _AddNewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Text(
              appLocalizations.addProfile,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep these for backwards compatibility with other parts of the codebase
class ReorderableProfilesSheet extends StatefulWidget {
  final List<Profile> profiles;
  final SheetType type;

  const ReorderableProfilesSheet({
    super.key,
    required this.profiles,
    required this.type,
  });

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index, [bool isDecorator = false]) {
    final isLast = index == profiles.length - 1;
    final isFirst = index == 0;
    final profile = profiles[index];
    return CommonInputListItem(
      key: Key(profile.id.toString()),
      trailing: ReorderableDelayedDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(profile.realLabel),
      isFirst: isFirst,
      isLast: isLast,
      isDecorator: isDecorator,
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    appController.reorder(profiles);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSheetScaffold(
      type: widget.type,
      actions: [
        if (widget.type == SheetType.bottomSheet)
          IconButton.filledTonal(
            onPressed: _handleSave,
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.comfortable,
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
            ),
            icon: const Icon(Icons.check),
          )
        else
          IconButton.filledTonal(
            icon: const Icon(Icons.check),
            onPressed: _handleSave,
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32, top: 12),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(
              _buildItem(index, true),
              index,
              animation,
            );
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final profile = profiles.removeAt(oldIndex);
              profiles.insert(newIndex, profile);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}

// ── Particle data ──
class _Particle {
  double x, y, vx, vy, size;
  double opacity;
  // For burst effect: origin angle & distance from center
  double angle, maxDist;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    this.opacity = 1.0,
    this.angle = 0,
    this.maxDist = 0,
  });
}

// ── SaveX Dialog with particle background ──
class _SaveXParticleDialog extends StatefulWidget {
  final Color primaryColor;
  final Animation<double> animation;

  const _SaveXParticleDialog({
    required this.primaryColor,
    required this.animation,
  });

  @override
  State<_SaveXParticleDialog> createState() => _SaveXParticleDialogState();
}

class _SaveXParticleDialogState extends State<_SaveXParticleDialog>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _entranceController;
  late List<_Particle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(45, (_) => _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      vx: (_rng.nextDouble() - 0.5) * 0.0004,
      vy: (_rng.nextDouble() - 0.5) * 0.0004,
      size: 1.5 + _rng.nextDouble() * 2.5,
      opacity: 0.3 + _rng.nextDouble() * 0.7,
    ));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(_drift);
    _particleController.repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  void _drift() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < 0) p.x += 1.0;
      if (p.x > 1) p.x -= 1.0;
      if (p.y < 0) p.y += 1.0;
      if (p.y > 1) p.y -= 1.0;
    }
    if (mounted) setState(() {});
  }

  void _close() {
    _entranceController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pc = widget.primaryColor;

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_entranceController.value);
        final dialogScale = 0.92 + 0.08 * t;
        final slideY = 10.0 * (1.0 - t);

        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Opacity(
              opacity: t,
              child: Stack(
                children: [
                  // Particle layer
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ParticleNetworkPainter(
                          particles: _particles,
                          color: pc,
                          progress: t,
                          connectionDistance: 0.15,
                        ),
                      ),
                    ),
                  ),
                  // Dialog
                  Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Transform.translate(
                        offset: Offset(0, slideY),
                        child: Transform.scale(
                          scale: dialogScale,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 360),
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF1A1A2E),
                                  Color(0xFF0D0D14),
                                ],
                              ),
                              border: Border.all(
                                color: pc.withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pc.withValues(alpha: 0.1),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Logo
                                    SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(22),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: pc.withValues(alpha: 0.3),
                                                    blurRadius: 28,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(22),
                                            child: Image.asset(
                                              'assets/images/savex_logo.png',
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'SaveX',
                                          style: TextStyle(
                                            fontFamily: 'SpaceGrotesk',
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            gradient: LinearGradient(
                                              colors: [pc, pc.withValues(alpha: 0.7)],
                                            ),
                                          ),
                                          child: const Text(
                                            'Premium',
                                            style: TextStyle(
                                              fontFamily: 'SpaceGrotesk',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Спасибо, что вы с нами!',
                                      style: TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Вы используете подписку SaveX Premium — это значит, что вы цените качество, скорость и стабильность. Мы рады, что вы выбрали нас.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.45),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: _close,
                                        style: TextButton.styleFrom(
                                          backgroundColor: pc.withValues(alpha: 0.12),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            side: BorderSide(
                                              color: pc.withValues(alpha: 0.2),
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Отлично!',
                                          style: TextStyle(
                                            fontFamily: 'SpaceGrotesk',
                                            fontWeight: FontWeight.w600,
                                            color: pc,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
}

// ── Particle network painter ──
class _ParticleNetworkPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double progress;
  final double connectionDistance;

  _ParticleNetworkPainter({
    required this.particles,
    required this.color,
    required this.progress,
    required this.connectionDistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw connections
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final a = particles[i];
        final b = particles[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < connectionDistance) {
          final lineAlpha =
              (1.0 - dist / connectionDistance) * 0.35 * progress;
          linePaint.color = color.withValues(alpha: lineAlpha);
          canvas.drawLine(
            Offset(a.x * size.width, a.y * size.height),
            Offset(b.x * size.width, b.y * size.height),
            linePaint,
          );
        }
      }
    }

    // Draw dots
    for (final p in particles) {
      dotPaint.color =
          color.withValues(alpha: p.opacity * 0.6 * progress);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * progress,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleNetworkPainter old) => true;
}
