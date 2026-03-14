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
                        _ActiveSubscriptionCard(
                          profile: profile!,
                          onUpdate: () => _updateProfile(profile),
                          onEdit: () => _handleShowEditExtendPage(profile),
                          onDelete: () => _handleDeleteProfile(profile),
                          onOverride: () => _handleShowOverridePage(profile),
                        ),
                        const SizedBox(height: 20),
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

class _ActiveSubscriptionCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOverride;

  const _ActiveSubscriptionCard({
    required this.profile,
    required this.onUpdate,
    required this.onEdit,
    required this.onDelete,
    required this.onOverride,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final sub = profile.subscriptionInfo;
    final hasData = sub != null && sub.total > 0;
    final used = hasData ? sub.upload + sub.download : 0;
    final total = hasData ? sub.total : 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.12),
            const Color(0xFF0D0D0D),
          ],
        ),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
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
                      Text(
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
                            onPressed: onUpdate,
                          );
                  },
                ),
              ],
            ),
          ),

          // Announce banner
          if (profile.announce != null && profile.announce!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                  const Spacer(),
                  if (sub.expire > 0)
                    _StatChip(
                      icon: Icons.schedule_rounded,
                      label: _formatExpiry(sub.expire),
                      color: _expiryColor(sub.expire),
                    ),
                ],
              ),
            ),
          ],

          // Last update
          if (profile.lastUpdateDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Обновлено: ${_formatDate(profile.lastUpdateDate!)}',
                style: const TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Правила',
                  onTap: onOverride,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: appLocalizations.edit,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: appLocalizations.delete,
                  onTap: onDelete,
                  isDanger: true,
                ),
              ],
            ),
          ),
        ],
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
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'Истекла';
    if (diff.inDays > 30) return '${diff.inDays} дн';
    if (diff.inDays > 0) return '${diff.inDays} дн';
    if (diff.inHours > 0) return '${diff.inHours} ч';
    return '< 1ч';
  }

  Color _expiryColor(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return Colors.red;
    if (diff.inDays < 3) return Colors.amber;
    return Colors.white38;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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
