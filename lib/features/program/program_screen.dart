import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/program_progress.dart';
import '../../routing/app_router.dart';
import '../../state/library_controller.dart';
import '../sports/new_program_screen.dart';
import 'widgets/week_card.dart';

/// تفاصيل برنامج واحد: أين وصلت، وما الأسبوع التالي.
class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key, required this.programId});

  final String programId;

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  int? _expandedWeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<LibraryController>();
      library.markOpened(widget.programId);
      final entry = library.byId(widget.programId);
      if (entry != null && mounted) {
        // نفتح الأسبوع الذي يقف عنده المستخدم، لا الأول دائماً.
        setState(
          () => _expandedWeek = entry.progress.currentWeekIndex(entry.program),
        );
      }
    });
  }

  Future<void> _confirmReset(SavedProgram entry) async {
    final library = context.read<LibraryController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'تصفير التقدّم',
      message: 'تُمسح كل الجلسات المكتملة في "${entry.program.sport}". '
          'البرنامج نفسه يبقى كما هو.',
      confirmLabel: 'تصفير',
      isDestructive: true,
    );
    if (!ok) return;
    await library.resetProgress(entry.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم تصفير التقدّم')));
  }

  Future<void> _confirmDelete(SavedProgram entry) async {
    final library = context.read<LibraryController>();
    final navigator = Navigator.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'حذف ${entry.program.sport}؟',
      message: 'يُحذف البرنامج وكل جلساتك المسجّلة فيه. لا يمكن التراجع.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok) return;
    await library.delete(entry.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final entry = library.byId(widget.programId);

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'البرنامج غير موجود',
          message: 'الغالب أنه حُذف. ارجع واختر برنامجاً آخر.',
          actionLabel: 'رجوع',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final program = entry.program;
    final colors = AccentPalette.byIndex(program.accentIndex);
    final currentWeek = entry.progress.currentWeekIndex(program);

    return Scaffold(
      body: BrandBackdrop(
        colors: colors,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.x4),
            children: <Widget>[
              ScreenHeader(
                title: program.sport,
                subtitle: '${program.level.label} · ${program.goal.label}',
                showBack: true,
                leading: SportMark(
                  sport: program.sport,
                  colors: colors,
                  size: SportMark.md,
                ),
                trailing: _ProgramMenu(
                  onRegenerate: () => context.pushPage(
                    NewProgramScreen(presetSport: program.sport),
                  ),
                  onReset: () => _confirmReset(entry),
                  onDelete: () => _confirmDelete(entry),
                ),
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  Space.sm,
                  Space.screenInset,
                  Space.xl,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.screenInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (program.summary.isNotEmpty) ...<Widget>[
                      Text(
                        program.summary,
                        style: AppType.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                    ],
                    _ProgressPanel(entry: entry, colors: colors),
                    const SizedBox(height: Space.md),
                    StatRow(
                      tiles: <StatTile>[
                        StatTile(
                          value: '${program.totalWeeks}',
                          label: 'أسابيع',
                          icon: Icons.calendar_month_rounded,
                        ),
                        StatTile(
                          value: '${program.totalSessions}',
                          label: 'جلسة',
                          icon: Icons.event_available_rounded,
                        ),
                        StatTile(
                          value: '${program.totalExercises}',
                          label: 'تمرين',
                          icon: Icons.fitness_center_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x3),
                    const SectionHeader(
                      title: 'خطة الأسابيع',
                      subtitle: 'كل أسبوع أصعب من الذي قبله',
                    ),
                    for (var i = 0; i < program.weeks.length; i++)
                      WeekRung(
                        entry: entry,
                        weekIndex: i,
                        colors: colors,
                        isCurrent: i == currentWeek,
                        isLast: i == program.weeks.length - 1,
                        expanded: _expandedWeek == i,
                        onToggleExpand: () => setState(
                          () => _expandedWeek = _expandedWeek == i ? null : i,
                        ),
                        onToggleSession: (dayIndex) {
                          HapticFeedback.mediumImpact();
                          context
                              .read<LibraryController>()
                              .toggleSession(entry.id, i, dayIndex);
                        },
                      ),
                    const SizedBox(height: Space.x3),
                    _Footer(entry: entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إجراءات البرنامج. ثلاثة إجراءات نادرة لا تستحق ثلاثة أزرار في الرأس.
class _ProgramMenu extends StatelessWidget {
  const _ProgramMenu({
    required this.onRegenerate,
    required this.onReset,
    required this.onDelete,
  });

  final VoidCallback onRegenerate;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded),
      tooltip: 'خيارات البرنامج',
      onSelected: (value) => switch (value) {
        'regenerate' => onRegenerate(),
        'reset' => onReset(),
        _ => onDelete(),
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        _item('regenerate', Icons.auto_awesome_rounded, 'ولّد برنامجاً جديداً'),
        _item('reset', Icons.restart_alt_rounded, 'تصفير التقدّم'),
        const PopupMenuDivider(),
        // الإجراء المتلف مفصول بصرياً عمّا فوقه حتى لا يُضغط بالخطأ.
        _item(
          'delete',
          Icons.delete_outline_rounded,
          'حذف البرنامج',
          color: AppColors.danger,
        ),
      ],
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: IconSizes.md, color: color),
          const SizedBox(width: Space.md),
          Text(label, style: AppType.body.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.entry, required this.colors});

  final SavedProgram entry;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final done = entry.progress.completedCount;
    final total = entry.program.totalSessions;
    final streak = entry.progress.streakDays;

    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(done.toString(), style: AppType.number(size: 30)),
              const SizedBox(width: Space.xs),
              Text('/ $total جلسة', style: AppType.bodySm),
              const Spacer(),
              if (streak > 0) ...<Widget>[
                AppTag(
                  label: '$streak يوم متتالٍ',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.coral,
                ),
                const SizedBox(width: Space.sm),
              ],
              AppTag(label: '${entry.percent}٪', color: colors.first),
            ],
          ),
          const SizedBox(height: Space.lg),
          ProgressBar(
            value: entry.ratio,
            colors: colors,
            semanticLabel: 'تقدّم البرنامج',
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.entry});

  final SavedProgram entry;

  @override
  Widget build(BuildContext context) {
    final program = entry.program;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (program.equipmentNeeded.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'الأدوات المطلوبة'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: program.equipmentNeeded
                .map((item) => AppTag(label: item))
                .toList(),
          ),
          const SizedBox(height: Space.x3),
        ],
        if (program.tips.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'نصائح المدرّب'),
          for (final tip in program.tips) ...<Widget>[
            _Tip(text: tip),
            const SizedBox(height: Space.sm),
          ],
          const SizedBox(height: Space.xl),
        ],
        if (program.safetyNotes.isNotEmpty) ...<Widget>[
          AppNotice(
            title: 'قبل أن تبدأ',
            message: program.safetyNotes,
            tone: NoticeTone.warning,
            icon: Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: Space.xl),
        ],
        Text(
          'هذا البرنامج توليد آلي لأغراض التدريب العام. إذا كانت لديك إصابة '
          'أو حالة صحية، راجع مختصاً قبل البدء.',
          textAlign: TextAlign.center,
          style: AppType.caption,
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: Space.xs),
          child: Icon(
            Icons.lightbulb_outline_rounded,
            size: IconSizes.sm,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            text,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
