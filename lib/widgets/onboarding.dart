import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingKey = 'savex_onboarding_done';

class OnboardingGuide {
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kOnboardingKey) ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }

  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => const _OnboardingOverlay(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

class _OnboardingOverlay extends StatefulWidget {
  const _OnboardingOverlay();

  @override
  State<_OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<_OnboardingOverlay>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _currentPage = 0;

  final _steps = const [
    _OnboardingStep(
      icon: Icons.add_link_rounded,
      iconColor: Color(0xFFAB6BF0),
      title: 'Добавьте подписку',
      description: 'Перейдите в «Подписки» и добавьте ссылку от вашего VPN-провайдера',
      hint: 'Формат: xspace://install-config?url=...',
    ),
    _OnboardingStep(
      icon: Icons.route_rounded,
      iconColor: Color(0xFF6BB8F0),
      title: 'Настройте маршруты',
      description: 'Во вкладке «Маршруты» выберите сервер и режим работы. Режим Авто автоматически направляет трафик по правилам',
      hint: 'Авто — для большинства пользователей',
    ),
    _OnboardingStep(
      icon: Icons.power_settings_new_rounded,
      iconColor: Color(0xFF4ADE80),
      title: 'Подключайтесь!',
      description: 'Нажмите большую кнопку на главном экране — и вы защищены',
      hint: 'TUN и системный прокси включены автоматически',
    ),
  ];

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    OnboardingGuide.markDone();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Пропустить',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _OnboardingPage(
                    step: _steps[index],
                    stepIndex: index,
                    totalSteps: _steps.length,
                    primaryColor: primaryColor,
                  );
                },
              ),
            ),

            // Dots + Next
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Row(
                children: [
                  // Dots
                  Row(
                    children: List.generate(_steps.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isActive
                              ? primaryColor
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Next button
                  GestureDetector(
                    onTap: _next,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: _currentPage == _steps.length - 1 ? 28 : 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentPage == _steps.length - 1 ? 'Начать' : 'Далее',
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String hint;

  const _OnboardingStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.hint,
  });
}

class _OnboardingPage extends StatefulWidget {
  final _OnboardingStep step;
  final int stepIndex;
  final int totalSteps;
  final Color primaryColor;

  const _OnboardingPage({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.primaryColor,
  });

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step number
              Text(
                '${widget.stepIndex + 1}/${widget.totalSteps}',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 32),

              // Icon
              Transform.scale(
                scale: _iconScale.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.step.iconColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: widget.step.iconColor.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.step.iconColor.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.step.icon,
                    size: 40,
                    color: widget.step.iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Text(
                    widget.step.title,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Text(
                    widget.step.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Hint chip
              FadeTransition(
                opacity: _textFade,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: widget.primaryColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.step.hint,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            color: widget.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
