import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

/// Global notifier for page scroll fraction (0.0 to itemCount-1).
/// Used by _BottomNavBar to follow swipe position in real-time.
final pageScrollNotifier = ValueNotifier<double>(0.0);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeBackScopeContainer(
      child: AppSidebarContainer(
        child: Material(
          color: context.colorScheme.surface,
          child: Consumer(
            builder: (context, ref, child) {
              return child!;
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final view = KeepScope(
                      keep: navigationItem.keep,
                      child: isMobile
                          ? navigationView
                          : Navigator(
                              pages: [MaterialPage(child: navigationView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return view;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;
  bool _isProgrammaticNavigation = false;
  PageLabel? _navTarget;
  int _navEpoch = 0; // tracks navigation generation for reentrancy

  @override
  initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    _pageController.addListener(_onScroll);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        if (_isProgrammaticNavigation && _navTarget == next) return;
        _toPage(next);
      }
    });
  }

  void _onScroll() {
    if (_pageController.hasClients && _pageController.page != null) {
      pageScrollNotifier.value = _pageController.page!;
    }
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    _isProgrammaticNavigation = true;
    _navTarget = pageLabel;
    final epoch = ++_navEpoch;
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if ((isAnimateToPage || !isMobile) && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
    // Only clear flags if this is still the latest navigation
    // (a newer _toPage call may have started while we were awaiting)
    if (mounted && _navEpoch == epoch) {
      _isProgrammaticNavigation = false;
      _navTarget = null;

      // If user touch interrupted the animation, PageView may have
      // settled on a different page. Sync provider to reality.
      final actualPage = _pageController.page?.round() ?? index;
      if (actualPage != index &&
          actualPage >= 0 &&
          actualPage < widget.navigationItems.length) {
        ref.read(currentPageLabelProvider.notifier).value =
            widget.navigationItems[actualPage].label;
      }
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Skip intermediate page changes during programmatic navigation
    // (animateToPage fires this for every page it passes through)
    if (_isProgrammaticNavigation) return;
    if (index >= 0 && index < widget.navigationItems.length) {
      ref.read(currentPageLabelProvider.notifier).value =
          widget.navigationItems[index].label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    final isMobile = ref.watch(isMobileViewProvider);
    return PageView.builder(
      controller: _pageController,
      physics: isMobile
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}


class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await appController.handleBackOrExit();
        }
        return false;
      },
      child: child,
    );
  }
}
