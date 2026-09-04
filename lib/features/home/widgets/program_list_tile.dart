import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/program_progress.dart';

/// صفّ يعرض رياضة محفوظة مع نسبة إنجازها.
///
/// نفس الصفّ يظهر في «الرئيسية» و«برامجي» — لا نسختين بمقاسين مختلفين.
class ProgramListTile extends StatelessWidget {
  const ProgramListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  final SavedProgram entry;
  final VoidCallback onTap;
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
      semanticLabel: '${program.sport}، $done من $total جلسة، '
          '${entry.percent} بالمئة',
      child: Row(
        children: <Widget>[
          SportMark(sport: program.sport, colors: colors, size: SportMark.md),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        program.sport,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.h4,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    AppTag(
                      label: program.level.label,
                      color: program.level.color,
                      subtle: true,
                    ),
                    if (entry.isComplete) ...<Widget>[
                      const SizedBox(width: Space.sm),
                      // الأيقونة مع النسبة ١٠٠٪ — العلامة لا تُنقل باللون وحده.
                      const Icon(
                        Icons.verified_rounded,
                        size: IconSizes.sm,
                        color: AppColors.mint,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.md),
                ProgressBar(value: entry.ratio, colors: colors, height: 6),
                const SizedBox(height: Space.sm),
                Text(
                  '$done من $total جلسة · ${program.totalWeeks} أسابيع',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          if (onDelete != null)
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'حذف ${program.sport}',
              color: AppColors.textTertiary,
              onPressed: onDelete,
            )
          else
            Text(
              '${entry.percent}٪',
              style: AppType.number(size: 15, color: colors.first),
            ),
        ],
      ),
    );
  }
}
