library;

import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:flutter/material.dart';

class RuleItem extends StatelessWidget {
  final bool isSelected;
  final bool isEditing;
  final Rule rule;
  final void Function() onSelected;
  final void Function(Rule rule) onEdit;

  const RuleItem({
    super.key,
    required this.isSelected,
    required this.rule,
    required this.onSelected,
    required this.onEdit,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return CommonSelectedListItem(
      isSelected: isSelected,
      onSelected: () {
        onSelected();
      },
      title: Text(
        rule.value,
        style: context.textTheme.bodyMedium?.toJetBrainsMono,
      ),
      onPressed: () {
        onEdit(rule);
      },
    );
  }
}

class RuleStatusItem extends StatelessWidget {
  final bool status;
  final Rule rule;
  final void Function(bool) onChange;

  const RuleStatusItem({
    super.key,
    required this.status,
    required this.rule,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: CommonCard(
          padding: EdgeInsets.zero,
          radius: 18,
          type: CommonCardType.filled,
          onPressed: () {
            onChange(!status);
          },
          child: ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            trailing: Switch(value: status, onChanged: onChange),
            title: Text(rule.value),
          ),
        ),
      ),
    );
  }
}

// Intuitive Russian descriptions for rule actions
String _ruleActionLabel(RuleAction action) {
  return switch (action) {
    RuleAction.DOMAIN => 'Домен (точный)',
    RuleAction.DOMAIN_SUFFIX => 'Домен (суффикс)',
    RuleAction.DOMAIN_KEYWORD => 'Домен (ключевое слово)',
    RuleAction.DOMAIN_REGEX => 'Домен (regex)',
    RuleAction.GEOSITE => 'Геосайт',
    RuleAction.IP_CIDR => 'IP-адрес (CIDR)',
    RuleAction.IP_CIDR6 => 'IPv6-адрес (CIDR)',
    RuleAction.IP_SUFFIX => 'IP-суффикс',
    RuleAction.IP_ASN => 'IP по ASN',
    RuleAction.GEOIP => 'GeoIP (страна)',
    RuleAction.SRC_GEOIP => 'Исходный GeoIP',
    RuleAction.SRC_IP_ASN => 'Исходный IP (ASN)',
    RuleAction.SRC_IP_CIDR => 'Исходный IP (CIDR)',
    RuleAction.SRC_IP_SUFFIX => 'Исходный IP-суффикс',
    RuleAction.DST_PORT => 'Порт назначения',
    RuleAction.SRC_PORT => 'Исходный порт',
    RuleAction.IN_PORT => 'Входящий порт',
    RuleAction.IN_TYPE => 'Тип подключения',
    RuleAction.IN_USER => 'Пользователь',
    RuleAction.IN_NAME => 'Имя подключения',
    RuleAction.PROCESS_NAME => 'Приложение (имя)',
    RuleAction.PROCESS_NAME_REGEX => 'Приложение (regex)',
    RuleAction.PROCESS_PATH => 'Приложение (путь)',
    RuleAction.PROCESS_PATH_REGEX => 'Приложение (путь regex)',
    RuleAction.UID => 'UID процесса',
    RuleAction.NETWORK => 'Сеть (TCP/UDP)',
    RuleAction.DSCP => 'DSCP',
    RuleAction.AND => 'И (логическое)',
    RuleAction.OR => 'ИЛИ (логическое)',
    RuleAction.NOT => 'НЕ (логическое)',
    _ => action.value,
  };
}

String _ruleTargetLabel(String target) {
  return switch (target) {
    'DIRECT' => 'Напрямую',
    'REJECT' => 'Заблокировать',
    'MATCH' => 'По умолчанию',
    _ => target,
  };
}

String _contentHint(RuleAction action) {
  return switch (action) {
    RuleAction.DOMAIN || RuleAction.DOMAIN_SUFFIX || RuleAction.DOMAIN_KEYWORD || RuleAction.DOMAIN_REGEX => 'Домен (напр. google.com)',
    RuleAction.IP_CIDR || RuleAction.IP_CIDR6 || RuleAction.SRC_IP_CIDR => 'IP-адрес (напр. 192.168.1.0/24)',
    RuleAction.DST_PORT || RuleAction.SRC_PORT || RuleAction.IN_PORT => 'Порт (напр. 443)',
    RuleAction.PROCESS_NAME || RuleAction.PROCESS_NAME_REGEX => 'Имя процесса (напр. chrome.exe)',
    RuleAction.PROCESS_PATH || RuleAction.PROCESS_PATH_REGEX => 'Путь к exe',
    RuleAction.GEOIP || RuleAction.SRC_GEOIP => 'Код страны (напр. RU)',
    RuleAction.GEOSITE => 'Геосайт (напр. google)',
    RuleAction.NETWORK => 'tcp или udp',
    _ => 'Значение',
  };
}

class AddOrEditRuleDialog extends StatefulWidget {
  final Rule? rule;

  const AddOrEditRuleDialog({super.key, this.rule});

  @override
  State<AddOrEditRuleDialog> createState() => _AddOrEditRuleDialogState();
}

class _AddOrEditRuleDialogState extends State<AddOrEditRuleDialog> {
  late RuleAction _ruleAction;
  final _ruleTargetController = TextEditingController();
  final _contentController = TextEditingController();
  bool _noResolve = false;
  bool _src = false;
  List<DropdownMenuEntry> _targetItems = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    _initState();
    super.initState();
  }

  void _initState() {
    _targetItems = [
      ...RuleTarget.values.map(
        (item) => DropdownMenuEntry(value: item.name, label: '${_ruleTargetLabel(item.name)} (${item.name})'),
      ),
    ];
    if (widget.rule != null) {
      final parsedRule = ParsedRule.parseString(widget.rule!.value);
      _ruleAction = parsedRule.ruleAction;
      _contentController.text = parsedRule.content ?? '';
      _ruleTargetController.text = parsedRule.ruleTarget ?? '';
      _noResolve = parsedRule.noResolve;
      _src = parsedRule.src;
      return;
    }
    _ruleAction = RuleAction.addedRuleActions.first;
    if (_targetItems.isNotEmpty) {
      _ruleTargetController.text = _targetItems.first.value;
    }
  }

  @override
  void didUpdateWidget(AddOrEditRuleDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      _initState();
    }
  }

  bool _isProcessRule(RuleAction action) {
    return [
      RuleAction.PROCESS_NAME,
      RuleAction.PROCESS_NAME_REGEX,
      RuleAction.PROCESS_PATH,
      RuleAction.PROCESS_PATH_REGEX,
    ].contains(action);
  }

  Future<void> _showProcessPicker() async {
    final processes = await _getRunningProcesses();
    if (!mounted || processes.isEmpty) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _ProcessPickerDialog(
        processes: processes,
        isPathMode: _ruleAction == RuleAction.PROCESS_PATH || _ruleAction == RuleAction.PROCESS_PATH_REGEX,
      ),
    );
    if (selected != null) {
      _contentController.text = selected;
      setState(() {});
    }
  }

  Future<List<_ProcessInfo>> _getRunningProcesses() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-Process | Where-Object {\$_.MainWindowTitle -ne ""} | Select-Object ProcessName, Path -Unique | ConvertTo-Csv -NoTypeInformation'],
      );
      final lines = (result.stdout as String).split('\n').skip(1);
      final Map<String, _ProcessInfo> unique = {};
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        // Parse CSV: "name","path"
        final parts = trimmed.split('","');
        if (parts.isEmpty) continue;
        final name = parts[0].replaceAll('"', '').trim();
        final path = parts.length > 1 ? parts[1].replaceAll('"', '').trim() : '';
        if (name.isNotEmpty && !unique.containsKey(name.toLowerCase())) {
          unique[name.toLowerCase()] = _ProcessInfo(name: '$name.exe', path: path);
        }
      }
      final list = unique.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (_) {
      return [];
    }
  }

  void _handleSubmit() {
    final res = _formKey.currentState?.validate();
    if (res == false) {
      return;
    }
    final parsedRule = ParsedRule(
      ruleAction: _ruleAction,
      content: _contentController.text,
      ruleTarget: _ruleTargetController.text,
      noResolve: _noResolve,
      src: _src,
    );
    final rule = widget.rule != null
        ? widget.rule!.copyWith(value: parsedRule.value)
        : Rule.value(parsedRule.value);
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: widget.rule != null
          ? appLocalizations.editRule
          : appLocalizations.addRule,
      actions: [
        TextButton(
          onPressed: _handleSubmit,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: DropdownMenuTheme(
        data: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(),
            labelStyle: context.textTheme.bodyLarge?.copyWith(
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (_, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      _ruleAction =
                          await globalState.showCommonDialog<RuleAction>(
                            filter: false,
                            child: OptionsDialog<RuleAction>(
                              title: 'Тип правила',
                              options: RuleAction.addedRuleActions,
                              textBuilder: (item) => _ruleActionLabel(item),
                              value: _ruleAction,
                            ),
                          ) ??
                          _ruleAction;
                      setState(() {});
                    },
                    child: Text(_ruleActionLabel(_ruleAction)),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    keyboardType: TextInputType.text,
                    onFieldSubmitted: (_) {
                      _handleSubmit();
                    },
                    controller: _contentController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _contentHint(_ruleAction),
                      suffixIcon: _isProcessRule(_ruleAction)
                          ? IconButton(
                              icon: const Icon(Icons.apps_rounded, size: 20),
                              tooltip: 'Выбрать из запущенных',
                              onPressed: () => _showProcessPicker(),
                            )
                          : null,
                    ),
                    validator: (_) {
                      if (_contentController.text.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.content,
                        );
                      }
                      return null;
                    },
                  ),
                  if (_isProcessRule(_ruleAction))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showProcessPicker(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.list_alt_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Выбрать из запущенных приложений',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  FormField<String>(
                    validator: (_) {
                      if (_ruleTargetController.text.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.ruleTarget,
                        );
                      }
                      return null;
                    },
                    builder: (filed) {
                      return DropdownMenu(
                        controller: _ruleTargetController,
                        label: Text(appLocalizations.ruleTarget),
                        width: 200,
                        menuHeight: 250,
                        enableFilter: false,
                        enableSearch: false,
                        dropdownMenuEntries: _targetItems,
                        errorText: filed.errorText,
                      );
                    },
                  ),
                  if (_ruleAction.hasParams) ...[
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: [
                        CommonCard(
                          radius: 8,
                          isSelected: _src,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              appLocalizations.sourceIp,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _src = !_src;
                            });
                          },
                        ),
                        CommonCard(
                          radius: 8,
                          isSelected: _noResolve,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              appLocalizations.noResolve,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _noResolve = !_noResolve;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProcessInfo {
  final String name;
  final String path;
  const _ProcessInfo({required this.name, required this.path});
}

class _ProcessPickerDialog extends StatefulWidget {
  final List<_ProcessInfo> processes;
  final bool isPathMode;

  const _ProcessPickerDialog({
    required this.processes,
    this.isPathMode = false,
  });

  @override
  State<_ProcessPickerDialog> createState() => _ProcessPickerDialogState();
}

class _ProcessPickerDialogState extends State<_ProcessPickerDialog> {
  String _search = '';

  List<_ProcessInfo> get _filtered {
    if (_search.isEmpty) return widget.processes;
    final q = _search.toLowerCase();
    return widget.processes
        .where((p) => p.name.toLowerCase().contains(q) || p.path.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Запущенные приложения',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtered.isEmpty
                  ? const Center(child: Text('Ничего не найдено'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.memory_rounded, size: 18, color: primaryColor.withValues(alpha: 0.6)),
                          title: Text(p.name, style: const TextStyle(fontSize: 13)),
                          subtitle: p.path.isNotEmpty
                              ? Text(
                                  p.path,
                                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            Navigator.of(context).pop(
                              widget.isPathMode ? p.path : p.name,
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
