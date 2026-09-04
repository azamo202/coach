import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/sport_visuals.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/training_program.dart';

/// المرجع السريع لطريقة أداء التمرين.
Future<void> showExerciseDetail(
  BuildContext context, {
  required Exercise exercise,
  required String sport,
  required List<Color> colors,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ExerciseDetailSheet(
      exercise: exercise,
      sport: sport,
      colors: colors,
    ),
  );
}

/// ورقة تفاصيل التمرين.
///
/// ترتيبها يتبع ترتيب استخدامها أثناء التمرين: الأرقام أولاً (تحتاجها وأنت
/// واقف)، ثم طريقة الأداء، ثم المراجع الخارجية.
class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet({
    super.key,
    required this.exercise,
    required this.sport,
    required this.colors,
  });

  final Exercise exercise;
  final String sport;
  final List<Color> colors;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'ما قدرنا نفتح الرابط', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          Space.xxl,
          Space.sm,
          Space.xxl,
          Space.x3,
        ),
        children: <Widget>[
          Text(exercise.name, style: AppType.h1),
          if (exercise.targetMuscles.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.sm),
            Text(exercise.targetMuscles, style: AppType.bodySm),
          ],
          const SizedBox(height: Space.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBox(
                  value: '${exercise.sets}',
                  label: 'مجموعات',
                  icon: Icons.repeat_rounded,
                  accent: colors.first,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _MetricBox(
                  value: exercise.reps.isEmpty ? '—' : exercise.reps,
                  label: 'تكرار',
                  icon: Icons.numbers_rounded,
                  accent: colors.first,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _MetricBox(
                  value: exercise.restSeconds > 0
                      ? '${exercise.restSeconds}ث'
                      : '—',
                  label: 'راحة',
                  icon: Icons.pause_circle_outline_rounded,
                  accent: colors.first,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          if (exercise.howTo.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'طريقة الأداء'),
            Text(
              exercise.howTo,
              style: AppType.bodyLg.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Space.xxl),
          ],
          if (exercise.cue.isNotEmpty) ...<Widget>[
            AppNotice(
              message: exercise.cue,
              tone: NoticeTone.neutral,
              icon: Icons.tips_and_updates_rounded,
            ),
            const SizedBox(height: Space.xxl),
          ],
          if (exercise.equipment.isNotEmpty ||
              exercise.tempo.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'تفاصيل'),
            if (exercise.equipment.isNotEmpty)
              _DetailRow(label: 'الأدوات', value: exercise.equipment),
            if (exercise.tempo.isNotEmpty)
              _DetailRow(label: 'إيقاع الأداء', value: exercise.tempo),
            const SizedBox(height: Space.xxl),
          ],
          const SectionHeader(
            title: 'شوف الحركة',
            subtitle: 'يفتح بحثاً في متصفّحك يوضّح الأداء بالصورة والفيديو',
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(
                  label: 'فيديو',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _open(
                    context,
                    SportVisuals.howToVideoUrl(exercise.name, sport),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: AppButton.secondary(
                  label: 'صور',
                  icon: Icons.image_outlined,
                  onPressed: () => _open(
                    context,
                    SportVisuals.howToImagesUrl(exercise.name, sport),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      child: ExcludeSemantics(
        child: AppCard(
          color: AppColors.surfaceElevated,
          radius: Radii.md,
          padding: const EdgeInsets.symmetric(vertical: Space.lg),
          child: Column(
            children: <Widget>[
              Icon(icon, size: IconSizes.sm, color: accent),
              const SizedBox(height: Space.sm),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.number(size: 16),
              ),
              const SizedBox(height: Space.xxs),
              Text(label, style: AppType.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: AppType.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
