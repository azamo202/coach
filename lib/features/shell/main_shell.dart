import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../program/library_screen.dart';
import '../progress/progress_screen.dart';
import '../sports/new_program_screen.dart';

/// الهيكل الرئيسي: أربع وجهات وزر إنشاء برنامج.
///
/// الوجهات الأربع هي كل المستوى الأعلى في التطبيق — لا يُدفن شيء داخل قائمة
/// جانبية. وزرّ الإنشاء في المنتصف لأنه الإجراء الوحيد الذي يقود التطبيق كله.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    final user = context.read<AuthController>().user;
    if (user == null) return;
    await context.read<LibraryController>().loadFor(user.id);
    if (!mounted) return;
    if (user.healthSyncEnabled) {
      await context.read<HealthController>().bootstrap();
    }
  }

  /// ينتقل إلى وجهة من الوجهات الأربع. تستدعيه الشاشات الداخلية عبر
  /// [ShellNavigation] بدل أن تدفع نسخة ثانية من الشاشة فوق نفسها.
  void goTo(int index) => _select(index);

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return ShellNavigation(
      goTo: goTo,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const <Widget>[
          HomeScreen(),
          LibraryScreen(),
          ProgressScreen(),
          ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _NewProgramButton(
        onTap: () => context.pushPage(const NewProgramScreen()),
      ),
      bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
    );
  }
}

/// يتيح للشاشات داخل الهيكل أن تنقل المستخدم إلى وجهة أخرى من وجهاته.
///
/// بدونها تضطر الشاشة إلى دفع نسخة جديدة من «برامجي» فوق «الرئيسية»، فيصبح
/// زرّ الرجوع يعود إلى نفس المكان الذي يظنّه المستخدم الوجهة الحالية.
class ShellNavigation extends InheritedWidget {
  const ShellNavigation({
    super.key,
    required this.goTo,
    required super.child,
  });

  final void Function(int index) goTo;

  static ShellNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavigation>();

  @override
  bool updateShouldNotify(ShellNavigation oldWidget) => false;
}

class _NewProgramButton extends StatelessWidget {
  const _NewProgramButton({required this.onTap});

  final VoidCallback onTap;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'إنشاء برنامج جديد',
      child: Tooltip(
        message: 'برنامج جديد',
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.mintGradient,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap();
              },
              child: const Icon(
                Icons.add_rounded,
                size: IconSizes.lg + 4,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  /// كل وجهة لها اسم مكتوب إلى جانب أيقونتها — الأيقونة وحدها تخمين.
  static const List<_TabItem> _items = <_TabItem>[
    _TabItem(Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    _TabItem(
      Icons.fitness_center_outlined,
      Icons.fitness_center_rounded,
      'برامجي',
    ),
    _TabItem(Icons.insights_outlined, Icons.insights_rounded, 'تقدّمي'),
    _TabItem(Icons.person_outline_rounded, Icons.person_rounded, 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.spruceDeep,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Touch.min + Space.lg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _Tab(
                      item: _items[0],
                      selected: index == 0,
                      onTap: () => onSelect(0),
                    ),
                  ),
                  Expanded(
                    child: _Tab(
                      item: _items[1],
                      selected: index == 1,
                      onTap: () => onSelect(1),
                    ),
                  ),
                  // فراغ زرّ الإنشاء العائم.
                  const SizedBox(width: 72),
                  Expanded(
                    child: _Tab(
                      item: _items[2],
                      selected: index == 2,
                      onTap: () => onSelect(2),
                    ),
                  ),
                  Expanded(
                    child: _Tab(
                      item: _items[3],
                      selected: index == 3,
                      onTap: () => onSelect(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.mint : AppColors.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // الأيقونة الممتلئة تميّز الوجهة الحالية حتى لمن لا يميّز اللون.
              Icon(
                selected ? item.activeIcon : item.icon,
                size: IconSizes.md + 2,
                color: color,
              ),
              const SizedBox(height: Space.xs),
              Text(
                item.label,
                style: AppType.overline.copyWith(
                  color: color,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
