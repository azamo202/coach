import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ar_plural.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/training_program.dart';
import '../../state/library_controller.dart';
import 'exercise_detail_sheet.dart';

/// جلسة تدريبية واحدة: الإحماء، التمارين، التهدئة.
///
/// الإجراء الوحيد المهم — «أنهيت الجلسة» — مثبّت أسفل الشاشة، فلا يضطر
/// المستخدم للتمرير إلى آخر التمارين ليسجّل ما أنجزه.
class SessionScreen extends StatelessWidget {
  const SessionScreen({
    super.key,
    required this.programId,
    required this.weekIndex,
    required this.dayIndex,
  });

  final String programId;
  final int weekIndex;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final entry = library.byId(programId);
    final day = entry?.program.dayAt(weekIndex, dayIndex);

    if (entry == null || day == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'الجلسة غير موجودة',
          message: 'ارجع للبرنامج واختر جلسة أخرى.',
          actionLabel: 'رجوع',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final program = entry.program;
    final colors = AccentPalette.byIndex(program.accentIndex);
    final done = entry.progress.isDone(weekIndex, dayIndex);

    return Scaffold(
      body: BrandBackdrop(
        colors: colors,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Space.contentWidth),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: Space.xxl),
                      children: <Widget>[
                        ScreenHeader(
                          title: day.label,
                          subtitle: day.focus.isEmpty ? null : day.focus,
                          showBack: true,
                          trailing: AppTag(
                            label: 'أسبوع ${weekIndex + 1}',
                            color: colors.first,
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            Space.sm,
                            Space.sm,
                            Space.screenInset,
                            Space.lg,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.screenInset,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  AppTag(
                                    label: Ar.minute(day.durationMinutes),
                                    icon: Icons.schedule_rounded,
                                  ),
                                  const SizedBox(width: Space.sm),
                                  AppTag(
                                    label: Ar.exercise(day.exercises.length),
                                    icon: Icons.fitness_center_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.xl),
                              if (day.warmUp.isNotEmpty) ...<Widget>[
                                _PhaseCard(
                                  icon: Icons.whatshot_rounded,
                                  title: 'الإحماء',
                                  body: day.warmUp,
                                  accentColor: AppColors.coral,
                                ),
                                const SizedBox(height: Space.xl),
                              ],
                              const SectionHeader(
                                title: 'التمارين',
                                subtitle: 'اضغط أي تمرين لتعرف طريقة أدائه',
                              ),
                              for (var i = 0; i < day.exercises.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: Space.md),
                                  child: _ExerciseCard(
                                    index: i + 1,
                                    exercise: day.exercises[i],
                                    colors: colors,
                                    onTap: () => showExerciseDetail(
                                      context,
                                      exercise: day.exercises[i],
                                      sport: program.sport,
                                      colors: colors,
                                    ),
                                  ),
                                ),
                              if (day.coolDown.isNotEmpty) ...<Widget>[
                                const SizedBox(height: Space.sm),
                                _PhaseCard(
                                  icon: Icons.self_improvement_rounded,
                                  title: 'التهدئة',
                                  body: day.coolDown,
                                  accentColor: colors.first,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _CompleteBar(
                done: done,
                colors: colors,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context
                      .read<LibraryController>()
                      .toggleSession(programId, weekIndex, dayIndex);
                  if (!done) {
                    showAppSnack(context, 'سُجّلت الجلسة. أحسنت.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الإحماء والتهدئة — بطاقة مميزة بشارة لونية وأيقونة معبرة.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: IconSizes.tile,
            height: IconSizes.tile,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Center(
              child: Icon(
                icon,
                size: IconSizes.md,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.h4),
                const SizedBox(height: Space.xs),
                Text(
                  body,
                  style: AppType.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.colors,
    required this.onTap,
  });

  final int index;
  final Exercise exercise;
  final List<Color> colors;
  final VoidCallback onTap;

  static String _formatRepsUnit(String reps) {
    final lower = reps.trim();
    if (lower.contains('دقيق') ||
        lower.contains('ساع') ||
        lower.contains('ثاني') ||
        lower.contains('متر') ||
        lower.contains('كم')) {
      return '';
    }
    return 'تكرار';
  }

  @override
  Widget build(BuildContext context) {
    final repsUnit = _formatRepsUnit(exercise.reps);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      semanticLabel: 'التمرين $index: ${exercise.name}. اعرف طريقة الأداء',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // رقم التمرين
              Container(
                width: IconSizes.tile,
                height: IconSizes.tile,
                decoration: BoxDecoration(
                  color: colors.first.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: AppType.number(size: 14, color: colors.first),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(exercise.name, style: AppType.h4),
                    if (exercise.targetMuscles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Space.xxs),
                      Text(
                        exercise.targetMuscles,
                        style: AppType.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              const Icon(
                Icons.info_outline_rounded,
                size: IconSizes.md,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: <Widget>[
              AppMetricPill(
                value: '${exercise.sets}',
                unit: Ar.set.unit(exercise.sets),
              ),
              if (exercise.reps.isNotEmpty)
                AppMetricPill(value: exercise.reps, unit: repsUnit),
              if (exercise.restSeconds > 0)
                AppMetricPill(value: '${exercise.restSeconds}', unit: 'ث راحة'),
              if (exercise.tempo.isNotEmpty)
                AppMetricPill(value: exercise.tempo, unit: 'إيقاع'),
            ],
          ),
          if (exercise.cue.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              decoration: BoxDecoration(
                color: colors.first.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(
                  color: colors.first.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.lightbulb_rounded,
                    size: IconSizes.sm,
                    color: colors.first,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      exercise.cue,
                      style: AppType.bodySm.copyWith(
                        color: colors.first,
                        fontWeight: AppType.medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// شريط الإجراء المثبّت أسفل الجلسة — ممركز ومحدد العرض على الشاشات الكبيرة.
class _CompleteBar extends StatelessWidget {
  const _CompleteBar({
    required this.done,
    required this.colors,
    required this.onTap,
  });

  final bool done;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.spruceDeep,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.contentWidth),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: done
                  ? AppButton.secondary(
                      label: 'تراجع عن الإكمال',
                      icon: Icons.undo_rounded,
                      onPressed: onTap,
                    )
                  : AppButton.primary(
                      label: 'أنهيت الجلسة',
                      icon: Icons.check_rounded,
                      gradient: colors,
                      onPressed: onTap,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
