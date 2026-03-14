import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    appController.addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(String url) async {
    appController.addProfileFormURL(url);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      appController.addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    final url = await globalState.showCommonDialog<String>(
      child: const _AnimatedURLFormDialog(),
    );
    if (url != null) {
      _handleAddProfileFormURL(url);
    }
  }

  @override
  Widget build(context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        children: [
          _AnimatedAddOption(
            delay: 0,
            icon: Icons.link_rounded,
            iconColor: const Color(0xFFAB6BF0),
            title: appLocalizations.url,
            subtitle: appLocalizations.urlDesc,
            onTap: _toAdd,
          ),
          _AnimatedAddOption(
            delay: 80,
            icon: Icons.qr_code_rounded,
            iconColor: const Color(0xFF6BB8F0),
            title: appLocalizations.qrcode,
            subtitle: appLocalizations.qrcodeDesc,
            onTap: _toScan,
          ),
          _AnimatedAddOption(
            delay: 160,
            icon: Icons.folder_open_rounded,
            iconColor: const Color(0xFF6BF0A0),
            title: appLocalizations.file,
            subtitle: appLocalizations.fileDesc,
            onTap: _handleAddProfileFormFile,
          ),
        ],
      ),
    );
  }
}

class _AnimatedAddOption extends StatefulWidget {
  final int delay;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AnimatedAddOption({
    required this.delay,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_AnimatedAddOption> createState() => _AnimatedAddOptionState();
}

class _AnimatedAddOptionState extends State<_AnimatedAddOption>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
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
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedURLFormDialog extends StatefulWidget {
  const _AnimatedURLFormDialog();

  @override
  State<_AnimatedURLFormDialog> createState() => _AnimatedURLFormDialogState();
}

class _AnimatedURLFormDialogState extends State<_AnimatedURLFormDialog>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();
  }

  Future<void> _submit() async {
    final url = _urlController.value.text.trim();
    if (url.isEmpty) return;
    Navigator.of(context).pop<String>(url);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _scaleAnim,
        child: CommonDialog(
          title: appLocalizations.importFromURL,
          actions: [
            TextButton(
              onPressed: _submit,
              child: Text(appLocalizations.submit),
            ),
          ],
          child: SizedBox(
            width: 300,
            child: Wrap(
              runSpacing: 16,
              children: [
                TextField(
                  keyboardType: TextInputType.url,
                  minLines: 1,
                  maxLines: 5,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  onEditingComplete: _submit,
                  controller: _urlController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: appLocalizations.url,
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    hintText: 'https://...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
