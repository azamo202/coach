import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ar_plural.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/fitness_level.dart';
import '../../data/models/program_progress.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import '../home/widgets/program_list_tile.dart';
import '../paywall/subscription_gate.dart';
import 'program_screen.dart';

/// كل الرياضات المحفوظة.
///
/// الفلاتر مجموعتان مستقلّتان: **الحالة** و**المستوى**. كانتا مختلطتين في
/// شريط واحد فكان الضغط على شريحة يلغي أخرى بلا سبب مفهوم.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _Status {
  all('الكل'),
  active('قيد التنفيذ'),
  done('مكتملة');

  const _Status(this.label);

  final String label;
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Status _status = _Status.all;
  FitnessLevel? _level;

  List<SavedProgram> _apply(List<SavedProgram> entries) {
    return entries.where((entry) {
      final matchesStatus = switch (_status) {
        _Status.all => true,
        _Status.active => !entry.isComplete,
        _Status.done => entry.isComplete,
      };
      return matchesStatus && (_level == null || entry.program.level == _level);
    }).toList();
  }

  void _clearFilters() => setState(() {
        _status = _Status.all;
        _level = null;
      });

  Future<void> _confirmDelete(SavedProgram entry) async {
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final ok = await showConfirmDialog(
      context,
      title: 'حذف ${entry.program.sport}؟',
      message: 'يُحذف البرنامج وكل جلساتك المسجّلة فيه. لا يمكن التراجع.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!ok) return;
    await library.delete(entry.id);
    // الحذف حرّر حصة على الخادم؛ نحدّث الصلاحية ليظهر ذلك في الواجهة.
    await subscription.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final entries = _apply(library.entries);

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Space.gridWidth),
                  child: ScreenHeader(
                    title: 'برامجي',
                    subtitle: '${Ar.outOf(library.entries.length, AppConfig.maxSavedSports, Ar.sport)}'
                        ' محفوظة',
                    padding: const EdgeInsets.fromLTRB(
                      Space.screenInset,
                      Space.sm,
                      Space.screenInset,
                      Space.lg,
                    ),
                  ),
                ),
              ),
              if (library.entries.isNotEmpty)
                _FilterBar(
                  status: _status,
                  level: _level,
                  onStatus: (value) => setState(() => _status = value),
                  onLevel: (value) => setState(() => _level = value),
                ),
              Expanded(
                child: _body(context, library, entries),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LibraryController library,
    List<SavedProgram> entries,
  ) {
    if (library.isLoading && library.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.screenInset),
        child: SkeletonList(count: 4),
      );
    }

    if (library.error != null && library.isEmpty) {
      final user = context.read<AuthController>().user;
      return ErrorStateView(
        title: 'تعذّر تحميل برامجك',
        message: library.error!,
        onRetry: user == null
            ? null
            : () =>
                context.read<LibraryController>().loadFor(user.id, force: true),
      );
    }

    if (library.entries.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'ما عندك برامج بعد',
        message: 'اختر أي رياضة، وابنِ أول برنامج تدريبي متدرّج لك.',
        actionLabel: 'أنشئ برنامجاً',
        onAction: () => openNewProgram(context),
      );
    }

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'ما فيه برنامج بهذه الفلاتر',
        message: 'امسح الفلاتر لترى كل رياضاتك المحفوظة.',
        actionLabel: 'مسح الفلاتر',
        onAction: _clearFilters,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 650;
        final isExtraWide = width >= 1050;
        final crossAxisCount = isExtraWide ? 3 : (isWide ? 2 : 1);

        if (crossAxisCount > 1) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.gridWidth),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  Space.screenInset,
                  Space.sm,
                  Space.screenInset,
                  Space.bottomBarClearance,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: Space.md,
                  mainAxisSpacing: Space.md,
                  mainAxisExtent: 140,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ProgramListTile(
                    entry: entry,
                    onTap: () => context.pushPage(
                      ProgramScreen(programId: entry.id),
                    ),
                  );
                },
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            Space.screenInset,
            Space.sm,
            Space.screenInset,
            Space.bottomBarClearance,
          ),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: Space.md),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Dismissible(
              key: ValueKey<String>(entry.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await _confirmDelete(entry);
                return false;
              },
              background: Container(
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsetsDirectional.only(start: Space.xxl),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                      size: IconSizes.md,
                    ),
                    const SizedBox(width: Space.sm),
                    Text(
                      'حذف',
                      style: AppType.label.copyWith(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
              child: ProgramListTile(
                entry: entry,
                onTap: () => context.pushPage(
                  ProgramScreen(programId: entry.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// مجموعتا فلترة مستقلّتان، كل واحدة أحادية الاختيار.
///
/// الشرائح تلتفّ إلى سطر ثانٍ ولا تنزلق أفقياً. الشريط المنزلق كان يقصّ
/// «مبتدئ» عند حافة الشاشة ويخفي «متوسط» و«محترف» خلفها بلا أي إشارة إلى
/// وجودهما — فلتر لا يراه أحد ليس فلتراً.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.level,
    required this.onStatus,
    required this.onLevel,
  });

  final _Status status;
  final FitnessLevel? level;
  final ValueChanged<_Status> onStatus;
  final ValueChanged<FitnessLevel?> onLevel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screenInset,
        0,
        Space.screenInset,
        Space.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Space.gridWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _FilterGroup(
                label: 'الحالة',
                children: <Widget>[
                  for (final value in _Status.values)
                    AppChip(
                      label: value.label,
                      selected: status == value,
                      onTap: () => onStatus(value),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              _FilterGroup(
                label: 'المستوى',
                children: <Widget>[
                  for (final value in FitnessLevel.values)
                    AppChip(
                      label: value.label,
                      icon: value.icon,
                      color: value.color,
                      selected: level == value,
                      onTap: () => onLevel(level == value ? null : value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مجموعة شرائح تحت اسمها.
///
/// الاسم يقول ما الذي تفلتره المجموعة — بدونه تبدو الشرائح الستّ صفّاً
/// واحداً يلغي بعضه بعضاً.
class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // الاسم فوق الشرائح لا بجانبها: عمود الاسم كان يقتطع 60 بكسل من عرض
    // الصفّ، فتهبط شريحة «محترف» وحدها إلى سطر ثانٍ — والنتيجة أطول مما لو
    // أخذ الاسم سطره الخاصّ.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.overline),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: children,
        ),
      ],
    );
  }
}
