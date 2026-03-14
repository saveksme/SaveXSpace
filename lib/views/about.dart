import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final data = await appController.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
    );
    appController.checkUpdateResultHandle(data: data, isUser: true);
  }

  List<Widget> _buildMoreSection(BuildContext context) {
    return generateSection(
      separated: false,
      title: appLocalizations.more,
      items: [
        ListItem(
          title: Text(appLocalizations.checkUpdate),
          onTap: () {
            _checkUpdate(context);
          },
        ),
        ListItem(
          title: const Text('Telegram'),
          onTap: () {
            globalState.openUrl('https://t.me/SaveXSpace');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: Text(appLocalizations.core),
          onTap: () {
            globalState.openUrl(
              'https://github.com/chen08209/Clash.Meta/tree/FlClash',
            );
          },
          trailing: const Icon(Icons.launch),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = [
      const SizedBox(height: 32),
      // Centered logo
      Center(
        child: Consumer(
          builder: (_, ref, __) {
            return _DeveloperModeDetector(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/icon.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    globalState.packageInfo.version,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              onEnterDeveloperMode: () {
                ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(developerMode: true));
                context.showNotifier(
                  appLocalizations.developerModeEnableTip,
                );
              },
            );
          },
        ),
      ),
      const SizedBox(height: 24),
      // "Based on FlClash" attribution
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'На основе ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            GestureDetector(
              onTap: () {
                globalState.openUrl('https://github.com/chen08209/FlClash');
              },
              child: Text(
                'FlClash',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'SaveX Space — независимый проект.\nНе связан с FlClash и его разработчиками.',
              triggerMode: TooltipTriggerMode.tap,
              preferBelow: true,
              textStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildMoreSection(context),
    ];
    return BaseScaffold(
      title: appLocalizations.about,
      body: Padding(
        padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
        child: generateListView(items),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
