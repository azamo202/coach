import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/ar_plural.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/program_progress.dart';
import '../../../data/models/training_program.dart';
import '../../../routing/app_router.dart';
import '../session_screen.dart';

/// درجة واحدة من سلّم البرنامج.
///
/// وعد التطبيق هو **التدرّج**: كل أسبوع أصعب من الذي قبله. كومة بطاقات
/// متطابقة لا تقول ذلك — السلّم يقوله. الخيط الرأسي يصل الأسابيع ببعضها،
/// والعُقدة تمتلئ حين يكتمل الأسبوع، فيرى المستخدم موضعه من الرحلة كلها
/// بنظرة واحدة، لا برقم مكتوب.
///
/// الترقيم هنا يحمل معلومة حقيقية (ترتيب زمني إجباري)، ولذلك بقي.
class WeekRung extends StatelessWidget {
  const WeekRung({
    super.key,
    required this.entry,
    required this.weekIndex,
    required this.colors,
    required this.expanded,
    required this.isCurrent,
    required this.isLast,
    required this.onToggleExpand,
    required this.onToggleSession,
  });

  final SavedProgram entry;
  final int weekIndex;
  final List<Color> colors;
  final bool expanded;

  /// الأسبوع الذي يقف عنده المستخدم الآن.
  final bool isCurrent;

  final bool isLast;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onToggleSession;

  @override
  Widget build(BuildContext context) {
    final week = entry.program.weeks[weekIndex];
    final doneCount = entry.progress.completedInWeek(weekIndex);
    final total = week.days.length;
    final complete = total > 0 && doneCount == total;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Rail(
            index: weekIndex,
            complete: complete,
            isCurrent: isCurrent,
            isLast: isLast,
            colors: colors,
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Space.md),
              child: _Body(
                entry: entry,
                weekIndex: weekIndex,
                week: week,
                colors: colors,
                expanded: expanded,
                complete: complete,
                isCurrent: isCurrent,
                doneCount: doneCount,
                total: total,
                onToggleExpand: onToggleExpand,
                onToggleSession: onToggleSession,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// الخيط والعُقدة — عمود السلّم.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.complete,
    required this.isCurrent,
    required this.isLast,
    required this.colors,
  });

  final int index;
  final bool complete;
  final bool isCurrent;
  final bool isLast;
  final List<Color> colors;

  static const double _node = 32;
  static const double _railWidth = 2;

  @override
  Widget build(BuildContext context) {
    final accent = colors.first;

    return SizedBox(
      width: _node,
      child: Column(
        children: <Widget>[
          // الجزء العلوي من الخيط بمحاذاة منتصف العُقدة.
          const SizedBox(height: Space.lg),
          _NodeDot(
            index: index,
            complete: complete,
            isCurrent: isCurrent,
            colors: colors,
            size: _node,
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: _railWidth,
                margin: const EdgeInsets.symmetric(vertical: Space.xs),
                color: complete
                    ? accent.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
        ],
      ),
    );
  }
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({
    required this.index,
    required this.complete,
    required this.isCurrent,
    required this.colors,
    required this.size,
  });

  final int index;
  final bool complete;
  final bool isCurrent;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = colors.first;

    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: complete ? LinearGradient(colors: colors) : null,
          color: complete ? null : AppColors.spruceDeep,
          border: complete
              ? null
              : Border.all(
                  color: isCurrent ? accent : AppColors.border,
                  width: isCurrent ? 2 : 1,
                ),
        ),
        child: Center(
          child: complete
              ? const Icon(
                  Icons.check_rounded,
                  size: IconSizes.sm,
                  color: AppColors.onPrimary,
                )
              : Text(
                  '${index + 1}',
                  style: AppType.number(
                    size: 13,
                    color: isCurrent ? accent : AppColors.textTertiary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.entry,
    required this.weekIndex,
    required this.week,
    required this.colors,
    required this.expanded,
    required this.complete,
    required this.isCurrent,
    required this.doneCount,
    required this.total,
    required this.onToggleExpand,
    required this.onToggleSession,
  });

  final SavedProgram entry;
  final int weekIndex;
  final TrainingWeek week;
  final List<Color> colors;
  final bool expanded;
  final bool complete;
  final bool isCurrent;
  final int doneCount;
  final int total;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onToggleSession;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: isCurrent ? colors.first.withValues(alpha: 0.5) : null,
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            expanded: expanded,
            label: 'الأسبوع ${weekIndex + 1}، ${week.title}، '
                'أنجزت $doneCount من $total',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onToggleExpand,
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // العنوان مرن ووسم «الآن» يحتفظ بعرضه.
                            //
                            // العنوان مع الوسم يتجاوزان عرض البطاقة في
                            // نافذة iPad الجانبية وعلى iPhone SE. الوسم
                            // هو المعلومة التي لا تُقصّ — فالعنوان هو من
                            // يتقلّص، لأنه مكرَّر أصلاً في تسمية Semantics.
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    'الأسبوع ${weekIndex + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.h4,
                                  ),
                                ),
                                if (isCurrent) ...<Widget>[
                                  const SizedBox(width: Space.sm),
                                  AppTag(
                                    label: 'الآن',
                                    color: colors.first,
                                    subtle: true,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: Space.xxs),
                            Text(
                              week.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.bodySm,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Text(
                        '$doneCount/$total',
                        style: AppType.number(
                          size: 13,
                          color:
                              complete ? colors.first : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: Motion.base,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textTertiary,
                          size: IconSizes.lg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.lg,
              ),
              child: Column(
                children: <Widget>[
                  if (week.intensity.isNotEmpty) ...<Widget>[
                    _IntensityNote(text: week.intensity, colors: colors),
                    const SizedBox(height: Space.md),
                  ],
                  for (var i = 0; i < week.days.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: Space.sm),
                    _DayTile(
                      day: week.days[i],
                      done: entry.progress.isDone(weekIndex, i),
                      colors: colors,
                      onToggle: () => onToggleSession(i),
                      onOpen: () => context.pushPage(
                        SessionScreen(
                          programId: entry.id,
                          weekIndex: weekIndex,
                          dayIndex: i,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// وصف التدرّج في هذا الأسبوع — المعلومة التي تميّزه عمّا قبله.
class _IntensityNote extends StatelessWidget {
  const _IntensityNote({required this.text, required this.colors});

  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: colors.first.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.trending_up_rounded,
            size: IconSizes.sm,
            color: colors.first,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              text,
              style: AppType.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.done,
    required this.colors,
    required this.onToggle,
    required this.onOpen,
  });

  final TrainingDay day;
  final bool done;
  final List<Color> colors;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: done
          ? colors.first.withValues(alpha: 0.09)
          : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              _CheckButton(done: done, colors: colors, onTap: onToggle),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      day.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.h4.copyWith(
                        color: done
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      '${Ar.exercise(day.exercises.length)} · '
                      '${Ar.minute(day.durationMinutes)}'
                      '${day.focus.isEmpty ? '' : ' · ${day.focus}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: IconSizes.md,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مربع تعليم الجلسة — مساحة لمسه كاملة رغم صغر دائرته.
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.colors,
    required this.onTap,
  });

  final bool done;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      label: done ? 'إلغاء تعليم الجلسة كمكتملة' : 'علّم الجلسة كمكتملة',
      button: true,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: Touch.min / 2,
          containedInkWell: false,
          child: SizedBox(
            width: Touch.min,
            height: Touch.min,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.fast,
                width: IconSizes.lg + 4,
                height: IconSizes.lg + 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done ? LinearGradient(colors: colors) : null,
                  color: done ? null : AppColors.surfaceElevated,
                  border: done
                      ? null
                      : Border.all(
                          color: colors.first.withValues(alpha: 0.38),
                          width: 1.5,
                        ),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: IconSizes.sm,
                        color: AppColors.onPrimary,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
