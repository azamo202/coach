import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/app_user.dart';
import '../../data/models/program_progress.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../program/program_screen.dart';
import '../shell/main_shell.dart';
import '../sports/new_program_screen.dart';
import 'widgets/health_card.dart';
import 'widgets/program_list_tile.dart';

/// الشاشة الرئيسية.
///
/// تجيب عن سؤال واحد: **ما التمرين التالي؟** كل ما عداه — الإحصاءات، بيانات
/// الصحة، بقية الرياضات — يأتي بعده وبوزن بصري أقل.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// عدد الرياضات المعروضة هنا قبل الإحالة إلى «برامجي».
  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final library = context.watch<LibraryController>();
    final health = context.watch<HealthController>();
    final user = auth.user;

    final loading = library.isLoading && library.isEmpty;
    // لا برامج ولا تحميل: الشاشة كلها للخطوة الأولى، لا بطاقة صغيرة يعلوها
    // فراغ نصف شاشة.
    final firstRun = library.isEmpty && !loading && library.error == null;

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.mint,
            backgroundColor: AppColors.spruceDeep,
            onRefresh: () async {
              if (user == null) return;
              final library = context.read<LibraryController>();
              final health = context.read<HealthController>();
              await library.loadFor(user.id, force: true);
              if (user.healthSyncEnabled) await health.refresh();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: ScreenHeader(
                    title: user?.name ?? 'صديقي',
                    subtitle: _greeting,
                    trailing: user == null
                        ? null
                        : AppTag(
                            label: user.level.label,
                            icon: user.level.icon,
                            color: user.level.color,
                          ),
                  ),
                ),
                if (firstRun)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.screenInset,
                        0,
                        Space.screenInset,
                        Space.bottomBarClearance,
                      ),
                      child: _FirstRunView(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.screenInset,
                      0,
                      Space.screenInset,
                      Space.bottomBarClearance,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: loading
                          ? const _HomeSkeleton()
                          : _Content(
                              library: library,
                              health: health,
                              user: user,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.library,
    required this.health,
    required this.user,
  });

  final LibraryController library;
  final HealthController health;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final hidden = library.entries.length - HomeScreen._previewCount;
    final person = user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (library.error != null && library.isEmpty && person != null) ...[
          AppNotice(
            title: 'تعذّر تحميل برامجك',
            message: library.error!,
            onRetry: () => context
                .read<LibraryController>()
                .loadFor(person.id, force: true),
          ),
          const SizedBox(height: Space.xxl),
        ],
        if (library.activeProgram != null) ...<Widget>[
          _NextSessionCard(entry: library.activeProgram!),
          const SizedBox(height: Space.xxl),
        ],
        // الإحصاءات تظهر حين يكون لها ما تقيسه. صفٌّ من الأصفار لا يخبر
        // المستخدم بشيء، ويبدأ العلاقة بجملة «لم تفعل شيئاً».
        if (!library.isEmpty) _QuickStats(library: library),
        if (person != null && person.healthSyncEnabled) ...<Widget>[
          const SizedBox(height: Space.xxl),
          HealthCard(
            snapshot: health.snapshot,
            isBusy: health.isBusy,
            onRefresh: () => context.read<HealthController>().refresh(),
          ),
        ],
        if (library.entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.x3),
          SectionHeader(
            title: 'رياضاتك',
            subtitle: '${library.entries.length} برنامج محفوظ',
            actionLabel: hidden > 0 ? 'عرض الكل' : null,
            onAction: hidden > 0
                ? () => ShellNavigation.maybeOf(context)?.goTo(1)
                : null,
          ),
          for (final entry
              in library.entries.take(HomeScreen._previewCount)) ...<Widget>[
            ProgramListTile(
              entry: entry,
              onTap: () => context.pushPage(ProgramScreen(programId: entry.id)),
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ],
    );
  }
}

/// بطاقة «التالي» — أهم عنصر في التطبيق كله.
///
/// تعرض الجلسة القادمة مباشرة بدل أن تطلب من المستخدم أن يبحث عنها داخل
/// البرنامج ثم داخل الأسبوع.
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.entry});

  /// لا تُبنى البطاقة أصلاً بلا برنامج — الحالة الفارغة تأخذ الشاشة كلها
  /// في [_FirstRunView].
  final SavedProgram entry;

  @override
  Widget build(BuildContext context) {
    final item = entry;
    final program = item.program;
    final colors = AccentPalette.byIndex(program.accentIndex);
    final next = item.progress.nextSession(program);
    final finished = next == null;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.pushPage(ProgramScreen(programId: item.id)),
      semanticLabel: 'برنامج ${program.sport}، أنجزت ${item.percent} بالمئة',
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  colors.first.withValues(alpha: 0.16),
                  colors.last.withValues(alpha: 0.04),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.lg),
              ),
            ),
            child: Row(
              children: <Widget>[
                SportMark(
                  sport: program.sport,
                  colors: colors,
                  size: SportMark.lg,
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        finished ? 'اكتمل البرنامج' : 'استكمل تدريبك',
                        style: AppType.caption,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        program.sport,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.h2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  '${item.percent}٪',
                  style: AppType.number(size: 20, color: colors.first),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.xs,
              Space.xl,
              Space.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ProgressBar(
                  value: item.ratio,
                  colors: colors,
                  semanticLabel: 'تقدّم ${program.sport}',
                ),
                const SizedBox(height: Space.lg),
                if (next != null)
                  Row(
                    children: <Widget>[
                      AppTag(label: 'أسبوع ${next.weekIndex + 1}'),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          next.day.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.h4,
                        ),
                      ),
                      const Icon(
                        // يتبع اتجاه القراءة تلقائياً: يشير يساراً في
                        // الواجهة العربية ويميناً في الإنجليزية.
                        Icons.chevron_right_rounded,
                        size: IconSizes.md,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  )
                else
                  Text(
                    'أنهيت كل جلسات هذا البرنامج. ارفع مستواك أو ابدأ رياضة '
                    'جديدة لتكمل التدرّج.',
                    style: AppType.bodySm,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة أول تشغيل: لا برامج بعد.
///
/// الفراغ هنا كان أكبر عنصر في الشاشة — بطاقة صغيرة أعلاها، وثلاثة أصفار
/// تحتها، ثم نصف شاشة سوداء. الحالة الفارغة **دعوة لفعل**، فأخذت الشاشة
/// كاملة وبُنيت من ثلاث طبقات:
///
/// 1. **الطلب**: عنوان وشرح وزرّ واحد.
/// 2. **طريق مختصر**: أربع رياضات شائعة تدخل مباشرة إلى شاشة التوليد
///    وحقلها مملوء — نقرة واحدة بدل نقرة وكتابة.
/// 3. **كيف يعمل**: ثلاث خطوات مرقّمة تشرح ما سيحدث بعد الضغط. الترقيم هنا
///    ليس زينة: هذه الخطوات تسلسل حقيقي لا قائمة خيارات.
class _FirstRunView extends StatelessWidget {
  const _FirstRunView();

  /// أربع رياضات فقط — الاختصار طريق سريع لا قائمة.
  static const List<String> _quickSports = <String>[
    'كرة قدم',
    'جري',
    'سباحة',
    'رفع أثقال',
  ];

  static const List<String> _steps = <String>[
    'تكتب رياضتك ومستواك وهدفك',
    'يبني المدرّب الذكي برنامجاً بأسابيع وجلسات وتمارين مشروحة',
    'تعلّم كل جلسة تنهيها، فيتتبّع التطبيق تقدّمك أسبوعاً بأسبوع',
  ];

  void _create(BuildContext context, [String? sport]) {
    context.pushPage(NewProgramScreen(presetSport: sport));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.lg),
        const RevealIn(child: _FirstRunHeadline()),
        const SizedBox(height: Space.xl),
        RevealIn(
          step: 1,
          child: AppButton.primary(
            label: 'أنشئ برنامجي',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => _create(context),
          ),
        ),
        const SizedBox(height: Space.xl),
        RevealIn(
          step: 2,
          child: Column(
            children: <Widget>[
              Text('أو ابدأ من رياضة شائعة', style: AppType.overline),
              const SizedBox(height: Space.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: <Widget>[
                  for (final sport in _quickSports)
                    AppChip(
                      label: sport,
                      selected: false,
                      onTap: () => _create(context, sport),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x3),
        RevealIn(
          step: 3,
          child: AppCard(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('كيف يعمل', style: AppType.h4),
                const SizedBox(height: Space.lg),
                for (var i = 0; i < _steps.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Space.lg),
                  _Step(number: i + 1, text: _steps[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

/// عنوان الحالة الفارغة: هالة نعناعية ثم العنوان والشرح.
class _FirstRunHeadline extends StatelessWidget {
  const _FirstRunHeadline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IgnorePointer(
                child: SizedBox(
                  width: 176,
                  height: 96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: <Color>[
                          AppColors.mint.withValues(alpha: 0.18),
                          AppColors.mint.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(
                    color: AppColors.mint.withValues(alpha: 0.35),
                  ),
                ),
                child: const ExcludeSemantics(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.mint,
                    size: IconSizes.xl,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(
          'ابدأ أول برنامج لك',
          textAlign: TextAlign.center,
          style: AppType.h1,
        ),
        const SizedBox(height: Space.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'اختر أي رياضة تريد التطوّر فيها، ويبني لك المدرّب الذكي برنامجاً '
            'متدرّجاً على مستواك.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// خطوة مرقّمة في «كيف يعمل».
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: IconSizes.lg + Space.xs,
          height: IconSizes.lg + Space.xs,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppType.number(size: 13, color: AppColors.mint),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Text(
              text,
              style: AppType.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return StatRow(
      tiles: <StatTile>[
        StatTile(
          value: '${library.totalCompletedSessions}',
          label: 'جلسة مكتملة',
          icon: Icons.check_circle_outline_rounded,
        ),
        StatTile(
          value: '${library.sessionsThisWeek}',
          label: 'هذا الأسبوع',
          icon: Icons.calendar_today_rounded,
        ),
        StatTile(
          value: '${library.bestStreak}',
          label: 'يوم متتالٍ',
          icon: Icons.local_fire_department_rounded,
          // اللون الوحيد في الصفّ، لأنه المقياس الوحيد الذي يعني «استمرارية».
          accent: library.bestStreak > 0 ? AppColors.coral : null,
        ),
      ],
    );
  }
}

/// هيكل التحميل — يحجز شكل الشاشة النهائي بدل دوّارة في الفراغ.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Skeleton(height: 168, radius: Radii.lg),
        SizedBox(height: Space.xxl),
        Row(
          children: <Widget>[
            Expanded(child: Skeleton(height: 96, radius: Radii.lg)),
            SizedBox(width: Space.md),
            Expanded(child: Skeleton(height: 96, radius: Radii.lg)),
            SizedBox(width: Space.md),
            Expanded(child: Skeleton(height: 96, radius: Radii.lg)),
          ],
        ),
        SizedBox(height: Space.x3),
        SkeletonList(count: 2),
      ],
    );
  }
}
