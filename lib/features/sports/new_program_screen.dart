import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/sport_visuals.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/fitness_level.dart';
import '../../data/services/prompt_builder.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/health_controller.dart';
import '../../state/library_controller.dart';
import '../paywall/subscription_gate.dart';
import 'generating_screen.dart';

/// اختيار الرياضة والمستوى والهدف قبل التوليد.
///
/// الشاشة تبني **طلباً**، فبُنيت حول هذا المعنى:
///
/// 1. **الطلب مرئي دائماً.** شريط سفلي ثابت يعرض ما سيُولَّد الآن — «كرة قدم ·
///    مبتدئ · لياقة عامة · ٤ أسابيع × ٣ جلسات» — ويحمل الزرّ. لم يعد الزرّ في
///    نهاية تمرير طويل: القرار متاح في أي لحظة، وما سيحدث عند الضغط مكتوب فوقه.
/// 2. **الاقتراحات تخدم الحقل ولا تنافسه.** ثماني رياضات فقط تظهر ابتداءً،
///    وتتحوّل إلى نتائج مطابقة أثناء الكتابة، والبقية خلف زرّ «+n». الجدار
///    الذي كان يضمّ ١٨ شريحة كان ينقض الرسالة نفسها: «اكتب أي رياضة».
/// 3. **المستوى يشرح نفسه.** وصف المستوى المحدَّد يظهر تحت الصفّ ويتبدّل معه،
///    فيتعلّم المستخدم الفرق بين الخيارات بدل أن يخمّنه.
/// 4. **الخيارات المتقدّمة تعلن قيمها وهي مطويّة**، فلا يفتحها أحد ليكتشف
///    أن الافتراضي يناسبه أصلاً.
class NewProgramScreen extends StatefulWidget {
  const NewProgramScreen({super.key, this.presetSport});

  final String? presetSport;

  @override
  State<NewProgramScreen> createState() => _NewProgramScreenState();
}

class _NewProgramScreenState extends State<NewProgramScreen> {
  /// عدد الاقتراحات الظاهرة قبل الضغط على «عرض الكل».
  static const int _visibleSuggestions = 8;

  final _formKey = GlobalKey<FormState>();
  final _sportController = TextEditingController();
  final _notesController = TextEditingController();
  final _equipmentController = TextEditingController();

  FitnessLevel _level = FitnessLevel.beginner;
  TrainingGoal _goal = TrainingGoal.general;
  int? _weeks;
  int? _sessions;
  bool _showAdvanced = false;
  bool _showAllSports = false;

  @override
  void initState() {
    super.initState();
    _sportController.text = widget.presetSport ?? '';
    // الاقتراحات تتبع ما يُكتب في الحقل، وحالة الشريحة المحدَّدة كذلك.
    _sportController.addListener(_onSportChanged);
    final user = context.read<AuthController>().user;
    if (user != null) {
      _level = user.level;
      _goal = user.goal;
    }
  }

  void _onSportChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sportController.removeListener(_onSportChanged);
    _sportController.dispose();
    _notesController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  String get _sport => _sportController.text.trim();

  int get _effectiveWeeks => _weeks ?? _level.defaultWeeks;

  int get _effectiveSessions => _sessions ?? _level.defaultSessionsPerWeek;

  /// الرياضات المطابقة لما كُتب. عند الحقل الفارغ: كل الاقتراحات.
  List<String> get _matches {
    if (_sport.isEmpty) return SportVisuals.suggestions;
    return SportVisuals.suggestions
        .where((s) => s.contains(_sport) || _sport.contains(s))
        .toList();
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final library = context.read<LibraryController>();
    final health = context.read<HealthController>();
    final user = context.read<AuthController>().user;
    final navigator = Navigator.of(context);
    final sport = _sport;

    // إعادة فحص عند الإرسال: قد ينتهي الاشتراك بين فتح الشاشة والضغط،
    // والانتظار دقيقة ثم تلقّي رفض تجربة سيئة.
    if (!await ensureProgramSlot(context)) return;
    if (!mounted) return;

    if (library.hasSport(sport)) {
      final proceed = await showConfirmDialog(
        context,
        title: 'عندك برنامج لـ"$sport"',
        message: 'البرنامج الجديد يُضاف بجانب القديم ولا يستبدله. تبي تكمل؟',
        confirmLabel: 'ولّد جديد',
      );
      if (!proceed) return;
    }

    final request = ProgramRequest(
      sport: sport,
      level: _level,
      goal: _goal,
      weeks: _weeks,
      sessionsPerWeek: _sessions,
      profileBrief: user?.profileBrief ?? '',
      healthBrief:
          user != null && user.healthSyncEnabled ? health.snapshot.aiBrief : '',
      notes: _notesController.text.trim(),
      equipmentAvailable: _equipmentController.text.trim(),
    );

    await navigator.pushReplacement(
      fadeThroughRoute<void>(GeneratingScreen(request: request)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final accent = _level.color;
    final matches = _matches;

    return Scaffold(
      body: BrandBackdrop(
        colors: AppColors.accentGradient(accent),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.contentWidth),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: Space.xxl),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: <Widget>[
                    const ScreenHeader(
                      title: 'برنامج جديد',
                      subtitle: 'أي رياضة تبي تتطوّر فيها؟',
                      showBack: true,
                      padding: EdgeInsets.fromLTRB(
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
                          AppTextField(
                            controller: _sportController,
                            label: 'الرياضة',
                            hint: 'كرة سلة، بادل، تسلّق صخور…',
                            icon: Icons.search_rounded,
                            textInputAction: TextInputAction.done,
                            isRequired: true,
                            helper: 'اكتب أي رياضة، حتى لو ما كانت في الاقتراحات.',
                            validator: Validators.sport,
                            suffix: _sport.isEmpty
                                ? null
                                : AppIconButton(
                                    icon: Icons.close_rounded,
                                    tooltip: 'مسح الرياضة',
                                    onPressed: _sportController.clear,
                                  ),
                          ),
                          const SizedBox(height: Space.lg),
                          _SuggestionList(
                            matches: matches,
                            query: _sport,
                            accent: accent,
                            expanded: _showAllSports,
                            visibleCount: _visibleSuggestions,
                            onPick: (sport) {
                              _sportController.text = sport;
                              FocusScope.of(context).unfocus();
                            },
                            onExpand: () => setState(() => _showAllSports = true),
                          ),
                          const SizedBox(height: Space.x3),
                          const SectionHeader(
                            title: 'المستوى',
                            subtitle: 'يحدّد صعوبة التمارين وحجم التدريب',
                          ),
                          Row(
                            children: <Widget>[
                              for (var i = 0;
                                  i < FitnessLevel.values.length;
                                  i++) ...<Widget>[
                                if (i > 0) const SizedBox(width: Space.sm),
                                Expanded(
                                  child: _LevelPill(
                                    level: FitnessLevel.values[i],
                                    selected: _level == FitnessLevel.values[i],
                                    onTap: () => setState(() {
                                      _level = FitnessLevel.values[i];
                                      // المدّة والجلسات تعود لافتراضي المستوى
                                      // الجديد ما لم يغيّرها المستخدم بنفسه.
                                      _weeks = null;
                                      _sessions = null;
                                    }),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: Space.md),
                          // وصف المستوى المحدَّد وحده — الفرق بين الخيارات يُقرأ
                          // عند الحاجة، لا كثلاث فقرات متجاورة.
                          _LevelDescription(level: _level),
                          const SizedBox(height: Space.xxl),
                          const SectionHeader(
                            title: 'الهدف',
                            subtitle: 'يوجّه اختيار التمارين وترتيب الأولويات',
                          ),
                          Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.sm,
                            children: <Widget>[
                              for (final goal in TrainingGoal.values)
                                AppChip(
                                  label: goal.label,
                                  icon: goal.icon,
                                  selected: _goal == goal,
                                  color: accent,
                                  onTap: () => setState(() => _goal = goal),
                                ),
                            ],
                          ),
                          const SizedBox(height: Space.xxl),
                          _AdvancedSection(
                            expanded: _showAdvanced,
                            onToggle: () =>
                                setState(() => _showAdvanced = !_showAdvanced),
                            level: _level,
                            weeks: _effectiveWeeks,
                            sessions: _effectiveSessions,
                            onWeeks: (v) => setState(() => _weeks = v),
                            onSessions: (v) => setState(() => _sessions = v),
                            equipmentController: _equipmentController,
                            notesController: _notesController,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // الشريط السفلي جزء من Scaffold حتى يرتفع فوق لوحة المفاتيح تلقائياً.
      bottomNavigationBar: _GenerateBar(
        sport: _sport,
        level: _level,
        goal: _goal,
        weeks: _effectiveWeeks,
        sessions: _effectiveSessions,
        isBusy: library.isGenerating,
        onGenerate: _generate,
      ),
    );
  }
}

/// اقتراحات الرياضات: ثمانية ابتداءً، ونتائج مطابقة أثناء الكتابة.
///
/// عرض الثمانية عشر كلها دفعة واحدة كان يبني جداراً أطول من كل ما تحته،
/// ويقول للمستخدم عكس ما يقوله النصّ المساعد: «اختر من القائمة».
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.matches,
    required this.query,
    required this.accent,
    required this.expanded,
    required this.visibleCount,
    required this.onPick,
    required this.onExpand,
  });

  final List<String> matches;
  final String query;
  final Color accent;
  final bool expanded;
  final int visibleCount;
  final ValueChanged<String> onPick;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    // لا شيء يطابق ما كُتب: الحقل يقبله على أي حال، فلا داعي لصفّ فارغ.
    if (matches.isEmpty) return const SizedBox.shrink();

    // ما كُتب هو الاقتراح الوحيد: الشريحة تكرّر الحقل حرفياً ولا تضيف خياراً.
    if (matches.length == 1 && matches.first == query) {
      return const SizedBox.shrink();
    }

    final showAll = expanded || matches.length <= visibleCount;
    final visible = showAll ? matches : matches.take(visibleCount).toList();
    final hidden = matches.length - visible.length;

    return AnimatedSize(
      duration: Motion.base,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            query.isEmpty ? 'أو اختر من الشائع' : 'اقتراحات مطابقة',
            style: AppType.overline,
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: <Widget>[
              for (final sport in visible)
                AppChip(
                  label: sport,
                  icon: SportVisuals.iconFor(sport),
                  selected: query == sport,
                  color: accent,
                  onTap: () => onPick(sport),
                ),
              if (hidden > 0)
                // الزرّ يفتح البقية ولا يخفيها — الاختصار للمساحة لا للمحتوى.
                // والصيغة تبدأ بكلمة عربية عمداً: «+10» يقلبها محرّك النصّ
                // فتُقرأ «10+».
                AppChip(
                  label: 'عرض $hidden أخرى',
                  icon: Icons.keyboard_arrow_down_rounded,
                  selected: false,
                  color: accent,
                  onTap: onExpand,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// وصف المستوى المحدَّد — يتبدّل بتلاشٍ متقاطع بدل أن يقفز.
class _LevelDescription extends StatelessWidget {
  const _LevelDescription({required this.level});

  final FitnessLevel level;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.base,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.base,
        child: Container(
          key: ValueKey<FitnessLevel>(level),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm + 2,
          ),
          decoration: BoxDecoration(
            color: level.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: level.color.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  Icons.info_outline_rounded,
                  size: IconSizes.sm,
                  color: level.color,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  level.description,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final FitnessLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${level.label}. ${level.description}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                vertical: Space.md,
                horizontal: Space.xs,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? level.color.withValues(alpha: 0.14)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: selected ? level.color : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: IconSizes.tile,
                    height: IconSizes.tile,
                    decoration: BoxDecoration(
                      color: (selected ? level.color : AppColors.textTertiary)
                          .withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        level.icon,
                        size: IconSizes.md - 2,
                        color: selected ? level.color : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    level.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(
                      color: selected ? level.color : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                  // الافتراضي مكتوب على الخيار نفسه: المستوى يغيّر حجم
                  // التدريب، فليُقرأ الفرق قبل الاختيار لا بعده.
                  Text(
                    '${level.defaultWeeks} أسابيع',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                      color: selected
                          ? AppColors.asText(level.color)
                          : AppColors.textTertiary,
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

/// الخيارات التي يحتاجها القليل — مطويّة حتى لا تثقل الشاشة على الأكثرية.
///
/// وهي تعلن قيمها الحالية وهي مطويّة، فمن يريد التأكّد فقط لا يحتاج فتحها.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.level,
    required this.weeks,
    required this.sessions,
    required this.onWeeks,
    required this.onSessions,
    required this.equipmentController,
    required this.notesController,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final FitnessLevel level;
  final int weeks;
  final int sessions;
  final ValueChanged<int?> onWeeks;
  final ValueChanged<int?> onSessions;
  final TextEditingController equipmentController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AnimatedSize(
        duration: Motion.base,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              button: true,
              expanded: expanded,
              label: 'خيارات متقدّمة. $weeks أسابيع، $sessions جلسات '
                  'في الأسبوع',
              child: ExcludeSemantics(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.tune_rounded,
                            size: IconSizes.md,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('خيارات متقدّمة', style: AppType.h4),
                                const SizedBox(height: Space.xxs),
                                Text(
                                  '$weeks أسابيع · $sessions جلسات '
                                  'في الأسبوع',
                                  style: AppType.caption,
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: Motion.base,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Divider(height: Space.xl),
                    Text('مدة البرنامج', style: AppType.label),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: <Widget>[
                        for (final w in const <int>[4, 6, 8, 12])
                          AppChip(
                            label: '$w أسابيع',
                            selected: weeks == w,
                            color: level.color,
                            onTap: () => onWeeks(w),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    Text('جلسات في الأسبوع', style: AppType.label),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: <Widget>[
                        for (final s in const <int>[2, 3, 4, 5, 6])
                          AppChip(
                            label: '$s',
                            selected: sessions == s,
                            color: level.color,
                            onTap: () => onSessions(s),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    AppTextField(
                      controller: equipmentController,
                      label: 'الأدوات المتاحة',
                      hint: 'دمبلز، حبل مقاومة، بدون أدوات…',
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: <Widget>[
                        for (final eq in const <String>[
                          'بدون أدوات',
                          'دمبلز',
                          'حبل مقاومة',
                          'نادي رياضي',
                        ])
                          AppChip(
                            label: eq,
                            selected: equipmentController.text.contains(eq),
                            color: level.color,
                            onTap: () {
                              final cur = equipmentController.text.trim();
                              if (cur.isEmpty) {
                                equipmentController.text = eq;
                              } else if (!cur.contains(eq)) {
                                equipmentController.text = '$cur، $eq';
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    AppTextField(
                      controller: notesController,
                      label: 'ملاحظات أو إصابات',
                      hint: 'عندي ألم في الركبة، تجنّب القفز',
                      maxLines: 3,
                      helper: 'يأخذها المدرّب بالحسبان عند اختيار التمارين.',
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: <Widget>[
                        for (final note in const <String>[
                          'تجنّب القفز',
                          'ألم بالركبة',
                          'ألم أسفل الظهر',
                          'تمرين منزلي',
                        ])
                          AppChip(
                            label: note,
                            selected: notesController.text.contains(note),
                            color: level.color,
                            onTap: () {
                              final cur = notesController.text.trim();
                              if (cur.isEmpty) {
                                notesController.text = note;
                              } else if (!cur.contains(note)) {
                                notesController.text = '$cur، $note';
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// شريط التوليد الثابت: ملخّص الطلب ثم الزرّ.
///
/// الملخّص ليس زينة — هو الجملة التي سيُبنى عليها البرنامج، مكتوبة فوق الزرّ
/// الذي ينفّذها. وبقاؤه ثابتاً يعني أن المستخدم لا يحتاج تمريراً طويلاً
/// ليقرّر، ولا يفاجئه ما لم يقرأه.
class _GenerateBar extends StatelessWidget {
  const _GenerateBar({
    required this.sport,
    required this.level,
    required this.goal,
    required this.weeks,
    required this.sessions,
    required this.isBusy,
    required this.onGenerate,
  });

  final String sport;
  final FitnessLevel level;
  final TrainingGoal goal;
  final int weeks;
  final int sessions;
  final bool isBusy;
  final VoidCallback onGenerate;

  String get _summary => sport.isEmpty
      ? 'اكتب الرياضة أولاً — الباقي جاهز'
      : '$sport · ${level.label} · ${goal.label} · $weeks أسابيع '
          '× $sessions جلسات';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.spruce,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.contentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.screenInset,
                Space.md,
                Space.screenInset,
                Space.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Icon(
                          sport.isEmpty
                              ? Icons.edit_outlined
                              : Icons.check_circle_outline_rounded,
                          size: IconSizes.sm,
                          color: sport.isEmpty
                              ? AppColors.textTertiary
                              : AppColors.asText(level.color),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          _summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(
                            color: sport.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  AppButton.primary(
                    label: 'ولّد برنامجي',
                    icon: Icons.auto_awesome_rounded,
                    isLoading: isBusy,
                    gradient: AppColors.accentGradient(level.color),
                    semanticLabel: 'ولّد برنامجي. $_summary',
                    onPressed: isBusy ? null : onGenerate,
                  ),
                  const SizedBox(height: Space.sm),
                  // النصّ ينزل سطراً ثانياً بدل أن يفيض.
                  //
                  // بعرضه الطبيعي إلى جانب الأيقونة كان يتجاوز عرض نافذة
                  // iPad الجانبية بمئة نقطة تقريباً. وهو نصّ توقُّع مهم
                  // قبل انتظار دقيقة، فلا يجوز قصّه بحذف حروفه.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.timer_outlined,
                        size: IconSizes.sm,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          'التوليد يستغرق 20 إلى 60 ثانية',
                          textAlign: TextAlign.center,
                          style: AppType.caption,
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
