import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ar_plural.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/program_progress.dart';
import '../../routing/app_router.dart';
import '../../state/library_controller.dart';
import '../program/program_screen.dart';
import '../paywall/subscription_gate.dart';

/// نظرة شاملة على تقدّم المستخدم عبر كل رياضاته.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    if (library.isLoading && library.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(Space.screenInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Skeleton(height: 140, radius: Radii.lg),
                SizedBox(height: Space.xl),
                SkeletonList(count: 3),
              ],
            ),
          ),
        ),
      );
    }

    if (library.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.insights_rounded,
            title: 'ما فيه تقدّم بعد',
            message: 'أنشئ برنامجاً وابدأ بتسجيل جلساتك، وتظهر إحصاءاتك هنا.',
            actionLabel: 'أنشئ برنامجاً',
            onAction: () => openNewProgram(context),
          ),
        ),
      );
    }

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.contentWidth),
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.bottomBarClearance),
                children: <Widget>[
                  const ScreenHeader(
                    title: 'تقدّمي',
                    subtitle: 'كل رياضاتك في مكان واحد',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.screenInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _OverallCard(library: library),
                        const SizedBox(height: Space.md),
                        StatRow(
                          tiles: <StatTile>[
                            StatTile(
                              value: '${library.entries.length}',
                              label: Ar.sport.unit(library.entries.length),
                              icon: Icons.sports_score_rounded,
                            ),
                            StatTile(
                              value: '${library.totalCompletedSessions}',
                              label:
                                  Ar.session.unit(library.totalCompletedSessions),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            StatTile(
                              value: '${library.bestStreak}',
                              label: 'يوم متتالٍ',
                              icon: Icons.local_fire_department_rounded,
                              accent:
                                  library.bestStreak > 0 ? AppColors.coral : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                        const SectionHeader(
                          title: 'آخر 7 أيام',
                          subtitle: 'عدد الجلسات التي أنجزتها كل يوم',
                        ),
                        _WeeklyChart(library: library),
                        const SizedBox(height: Space.x3),
                        const SectionHeader(title: 'تفصيل كل رياضة'),
                        for (final entry in library.entries) ...<Widget>[
                          _SportProgressRow(
                            entry: entry,
                            onTap: () => context.pushPage(
                              ProgramScreen(programId: entry.id),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                        ],
                      ],
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

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        children: <Widget>[
          ProgressRing(
            value: library.overallRatio,
            caption: 'إنجاز',
            size: 88,
          ),
          const SizedBox(width: Space.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('إجمالي تقدّمك', style: AppType.h3),
                const SizedBox(height: Space.sm),
                Text(
                  '${Ar.outOf(library.totalCompletedSessions, library.totalSessions, Ar.session)}'
                  '، عبر ${Ar.sport(library.entries.length)}.',
                  style: AppType.bodySm,
                ),
                const SizedBox(height: Space.md),
                AppTag(
                  label: '${Ar.session(library.sessionsThisWeek)} هذا الأسبوع',
                  icon: Icons.calendar_today_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.library});

  final LibraryController library;

  static const List<String> _dayNames = <String>[
    'إثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
    'سبت',
    'أحد',
  ];

  /// عدد الجلسات المكتملة في كل يوم من آخر 7 أيام (الأقدم أولاً).
  List<int> _dailyCounts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(7, 0);

    for (final entry in library.entries) {
      for (final date in entry.progress.completed.values) {
        final day = DateTime(date.year, date.month, date.day);
        final diff = today.difference(day).inDays;
        if (diff >= 0 && diff < 7) counts[6 - diff]++;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _dailyCounts();
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount < 3 ? 3 : maxCount + 1).toDouble();
    final now = DateTime.now();

    // الرسم البياني وحده لا يصل للقارئ الصوتي، فنرفق ملخّصاً نصياً له.
    return Semantics(
      label: 'جلسات آخر سبعة أيام',
      value: total == 0
          ? 'ما فيه جلسات مسجّلة'
          : '${Ar.session(total)}، أعلى يوم ${Ar.session(maxCount)}',
      child: ExcludeSemantics(
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xl,
            Space.md,
            Space.md,
          ),
          child: total == 0
              ? const _ChartEmpty()
              : SizedBox(
                  height: 168,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      minY: 0,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.surfaceHigh,
                          getTooltipItem: (group, i, rod, rodIndex) =>
                              BarTooltipItem(
                            Ar.session(rod.toY.round()),
                            AppType.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: AppColors.borderSoft,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        // القيمة مكتوبة فوق عمودها مباشرة بدل محور جانبي:
                        // سبعة أعمدة بأعداد صغيرة لا تستحق محوراً كاملاً،
                        // وبدون رقم يبقى ارتفاع العمود شكلاً لا معلومة.
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index > 6) {
                                return const SizedBox.shrink();
                              }
                              final count = counts[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.xs,
                                ),
                                child: Text(
                                  '$count',
                                  style: AppType.number(
                                    size: 12,
                                    color: count == 0
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(),
                        leftTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index > 6) {
                                return const SizedBox.shrink();
                              }
                              final date =
                                  now.subtract(Duration(days: 6 - index));
                              final isToday = index == 6;
                              return Padding(
                                padding: const EdgeInsets.only(top: Space.sm),
                                child: Text(
                                  _dayNames[date.weekday - 1],
                                  style: AppType.overline.copyWith(
                                    letterSpacing: 0,
                                    color: isToday
                                        ? AppColors.mint
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (var i = 0; i < 7; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: counts[i].toDouble(),
                                width: 18,
                                borderRadius:
                                    BorderRadius.circular(Radii.xs * 0.75),
                                gradient: const LinearGradient(
                                  colors: AppColors.mintGradient,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: AppColors.surfaceElevated,
                                ),
                              ),
                            ],
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

/// حالة الرسم البياني حين لا توجد بيانات — نصّ يشرح، لا محاور فارغة.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.bar_chart_rounded,
                size: IconSizes.xl,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: Space.md),
              Text(
                'ما سجّلت جلسة هذا الأسبوع بعد. علّم أول جلسة ليبدأ الرسم.',
                textAlign: TextAlign.center,
                style: AppType.bodySm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportProgressRow extends StatelessWidget {
  const _SportProgressRow({required this.entry, required this.onTap});

  final SavedProgram entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AccentPalette.byIndex(entry.program.accentIndex);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      color: AppColors.surfaceElevated,
      semanticLabel: '${entry.program.sport}، ${entry.percent} بالمئة',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SportMark(
                sport: entry.program.sport,
                colors: colors,
                size: SportMark.sm,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  entry.program.sport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h4,
                ),
              ),
              Text(
                '${entry.progress.completedCount}/'
                '${entry.program.totalSessions}',
                style: AppType.number(
                  size: 13,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                '${entry.percent}٪',
                style: AppType.number(size: 15, color: colors.first),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          ProgressBar(value: entry.ratio, colors: colors, height: 6),
        ],
      ),
    );
  }
}
