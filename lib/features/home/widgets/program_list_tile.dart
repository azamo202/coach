import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/ar_plural.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/program_progress.dart';

/// صفّ رياضة محفوظة: الشارة، الاسم والمستوى، نسبة الإنجاز، ثم شريط التقدّم
/// وسطر البيانات.
///
/// الصفّ واحد في «الرئيسية» و«برامجي» وفي الشبكة على الشاشات العريضة. كانت
/// نسخة الشبكة تستبدل نسبة الإنجاز بزرّ الحذف، فتختفي أهم معلومة في البطاقة
/// كلما اتّسعت الشاشة. الآن النسبة ثابتة، وزرّ الحذف يقف بجانبها حين يُطلب.
class ProgramListTile extends StatelessWidget {
  const ProgramListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  final SavedProgram entry;
  final VoidCallback onTap;

  /// حذف البرنامج. موجود في «برامجي» وحدها — بديل ظاهر للسحب، لا يعتمد
  /// المستخدم معه على إيماءة وحدها.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final program = entry.program;
    final colors = AccentPalette.byIndex(program.accentIndex);
    final done = entry.progress.completedCount;
    final total = program.totalSessions;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      semanticLabel: '${program.sport}، ${Ar.outOf(done, total, Ar.session)}، '
          '${entry.percent} بالمئة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SportMark(
                sport: program.sport,
                colors: colors,
                size: SportMark.md,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      program.sport,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.h3,
                    ),
                    const SizedBox(height: Space.xxs),
                    AppTag(
                      label: program.level.label,
                      color: program.level.color,
                      subtle: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              CompletionBadge(
                percent: entry.percent,
                complete: entry.isComplete,
                accent: colors.first,
              ),
              if (onDelete != null)
                AppIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'حذف ${program.sport}',
                  color: AppColors.textTertiary,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          ProgressBar(value: entry.ratio, colors: colors, height: 6),
          const SizedBox(height: Space.sm),
          // النصّان مرنان لا ثابتان.
          //
          // «١٢ من ٤٠ جلسة» و«٨ أسابيع» يطولان بطول الأرقام وبمقياس الخطّ،
          // وعرض البطاقة يضيق إلى ٢٤٦ نقطة في نافذة iPad الجانبية وعلى
          // iPhone SE. بعرضهما الطبيعي داخل صفّ كانا يفيضان بلا حدّ.
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline_rounded,
                size: IconSizes.sm - 2,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  Ar.outOf(done, total, Ar.session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.schedule_rounded,
                size: IconSizes.sm - 2,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  Ar.week(program.totalWeeks),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
