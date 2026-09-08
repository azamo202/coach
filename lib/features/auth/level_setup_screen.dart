import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/ar_plural.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/fitness_level.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../shell/main_shell.dart';

/// تحديد المستوى والهدف — آخر خطوة قبل دخول التطبيق، وصفحة التعديل لاحقاً.
///
/// هذه الشاشة هي التي يقرأ منها المدرّب الذكي حِمل التدريب وعدد الجلسات ونوع
/// التمارين، فهي أهم نموذج في التطبيق. لذلك تلتزم بنفس لغة بقية الشاشات:
/// سطح واحد من [AppCard]، عمق من الطبقة والحدّ لا من الضباب، ومقاسات من
/// [Space] و[AppType] وحدهما.
///
/// ثلاثة قرارات تحكم ترتيبها:
/// 1. **سؤال واحد في أعلى الشاشة.** كان العنوان الرئيسي يسأل «وش مستواك
///    الرياضي؟» ثم يعيد السؤال نفسه ترويسةً للقسم الأول تحته مباشرة.
/// 2. **الاختياري يأتي أخيراً وموسوماً.** القياسات البدنية تحسّن الدقة ولا
///    تمنع المتابعة، فلا تقف بين المستخدم وبين الزرّ.
/// 3. **الزرّ مثبّت أسفل الشاشة** لأن القائمة أطول من شاشة واحدة، والإجراء
///    الوحيد لا يجوز أن يُبحث عنه بالتمرير.
class LevelSetupScreen extends StatefulWidget {
  const LevelSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<LevelSetupScreen> createState() => _LevelSetupScreenState();
}

class _LevelSetupScreenState extends State<LevelSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  FitnessLevel _level = FitnessLevel.beginner;
  TrainingGoal _goal = TrainingGoal.general;
  String? _gender;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    if (user != null) {
      _level = user.level;
      _goal = user.goal;
      _gender = user.gender;
      if (user.age != null) _ageController.text = '${user.age}';
      if (user.weightKg != null) {
        _weightController.text = user.weightKg!.toStringAsFixed(0);
      }
      if (user.heightCm != null) {
        _heightController.text = user.heightCm!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.lightImpact();
      return;
    }

    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await auth.completeProfileSetup(
      level: _level,
      goal: _goal,
      age: int.tryParse(_ageController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      heightCm: double.tryParse(_heightController.text.trim()),
      gender: _gender,
    );
    if (!mounted) return;

    if (!ok) {
      showAppSnack(context, auth.error ?? 'تعذّر الحفظ', isError: true);
      return;
    }

    if (widget.isEditing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم تحديث مستواك')));
      navigator.pop();
    } else {
      await navigator.pushAndRemoveUntil(
        fadeThroughRoute<void>(const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final accent = _level.color;

    return Scaffold(
      body: BrandBackdrop(
        colors: AppColors.accentGradient(accent),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: Space.formWidth),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: Space.xxl),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: <Widget>[
                          // الشارة فوق العنوان لا تحته: هي تمهيد للسؤال،
                          // ومكانها بعده يجعلها تعليقاً على إجابة لم تُطلب بعد.
                          if (!widget.isEditing)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(
                                Space.screenInset,
                                Space.md,
                                Space.screenInset,
                                Space.md,
                              ),
                              child: _StepBadge(),
                            ),
                          ScreenHeader(
                            title: widget.isEditing
                                ? 'مستواي وهدفي'
                                : 'وش مستواك الرياضي؟',
                            subtitle: widget.isEditing
                                ? 'تحديث بياناتك يضبط صعوبة خططك القادمة.'
                                : 'عليها يبني المدرّب شدّة تمارينك وتكراراتها '
                                    'وفترات راحتها.',
                            showBack: widget.isEditing,
                            padding: EdgeInsets.fromLTRB(
                              widget.isEditing
                                  ? Space.sm
                                  : Space.screenInset,
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
                                for (final level in FitnessLevel.values)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Space.md,
                                    ),
                                    child: _LevelCard(
                                      level: level,
                                      selected: _level == level,
                                      onTap: () =>
                                          setState(() => _level = level),
                                    ),
                                  ),
                                const SizedBox(height: Space.xxl),
                                const SectionHeader(
                                  title: 'هدفك الأساسي',
                                  subtitle:
                                      'يوجّه المدرّب لنوع التمارين وتوزيع '
                                      'الأحمال',
                                ),
                                _GoalGrid(
                                  selected: _goal,
                                  onSelect: (goal) =>
                                      setState(() => _goal = goal),
                                ),
                                const SizedBox(height: Space.x3),
                                const SectionHeader(
                                  title: 'بيانات إضافية · اختيارية',
                                  subtitle:
                                      'تزيد دقّة استهداف السعرات والحمل. '
                                      'تقدر تتخطّاها الآن وتضيفها لاحقاً.',
                                ),
                                _GenderChoice(
                                  selected: _gender,
                                  onChanged: (value) =>
                                      setState(() => _gender = value),
                                ),
                                const SizedBox(height: Space.xl),
                                _MeasurementFields(
                                  age: _ageController,
                                  weight: _weightController,
                                  height: _heightController,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _SubmitBar(
                  isEditing: widget.isEditing,
                  accent: accent,
                  isLoading: auth.isBusy,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// موضع المستخدم من التسجيل — سطر واحد يقول إن هذه آخر خطوة.
class _StepBadge extends StatelessWidget {
  const _StepBadge();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppTag(
        label: 'الخطوة الأخيرة',
        icon: Icons.auto_awesome_rounded,
        color: AppColors.mint,
      ),
    );
  }
}

/// خيار مستوى واحد.
///
/// يعلن حالته للقارئ الصوتي، ولا يعتمد على اللون وحده: المحدَّد يتغيّر لونه
/// **و** سُمك حدّه **و** علامة الاختيار في طرفه.
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final FitnessLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = level.color;

    return Semantics(
      button: true,
      selected: selected,
      label: '${level.label}. ${level.description}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          color: selected
              ? accent.withValues(alpha: 0.10)
              : AppColors.spruceDeep,
          borderColor: selected ? accent : AppColors.border,
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: <Widget>[
              Container(
                width: IconSizes.tile,
                height: IconSizes.tile,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(level.icon, size: IconSizes.md, color: accent),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      level.label,
                      style: AppType.h4.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      level.description,
                      style: AppType.caption,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      '${Ar.session(level.defaultSessionsPerWeek)} أسبوعياً '
                      '· ${Ar.week(level.defaultWeeks)}',
                      style: AppType.caption.copyWith(
                        color: AppColors.asText(accent),
                        fontWeight: AppType.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              _SelectDot(selected: selected, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// علامة الاختيار في طرف الخيار — دائرة فارغة أو صحّ ممتلئ.
class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Curves.easeOut,
      width: IconSizes.lg,
      height: IconSizes.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: IconSizes.sm,
              color: AppColors.onPrimary,
            )
          : null,
    );
  }
}

/// أهداف التدريب في عمودين — عمود واحد على الشاشات الضيقة جداً.
class _GoalGrid extends StatelessWidget {
  const _GoalGrid({required this.selected, required this.onSelect});

  final TrainingGoal selected;
  final ValueChanged<TrainingGoal> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // عمودان ما دام العمود يتّسع لأطول اسم هدف («مهارات الرياضة»).
        final columns = constraints.maxWidth >= 320 ? 2 : 1;
        final width =
            (constraints.maxWidth - Space.sm * (columns - 1)) / columns;

        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            for (final goal in TrainingGoal.values)
              SizedBox(
                width: width,
                child: _GoalTile(
                  goal: goal,
                  selected: goal == selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(goal);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final TrainingGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.mint;

    return Semantics(
      button: true,
      selected: selected,
      label: goal.label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: Touch.min),
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: selected ? accent : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    goal.icon,
                    size: IconSizes.md,
                    color: selected ? accent : AppColors.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      goal.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_rounded,
                      size: IconSizes.sm,
                      color: accent,
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

/// الجنس — شريحتان تُلغى إحداهما بالضغط عليها ثانيةً.
class _GenderChoice extends StatelessWidget {
  const _GenderChoice({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const List<(String, IconData)> _options = <(String, IconData)>[
    ('ذكر', Icons.male_rounded),
    ('أنثى', Icons.female_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'الجنس',
          style: AppType.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: <Widget>[
            for (final (label, icon) in _options) ...<Widget>[
              if (label != _options.first.$1) const SizedBox(width: Space.sm),
              AppChip(
                label: label,
                icon: icon,
                selected: selected == label,
                onTap: () => onChanged(selected == label ? null : label),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// العمر والوزن والطول.
///
/// ثلاثة حقول في صفّ واحد على الشاشة العريضة، وواحد تحت الآخر على الضيقة:
/// حقل عرضه ثلث 375 بكسل لا يتّسع لرسالة خطأ، وكانت الرسائل مخفيّة تماماً
/// فيرفض النموذج الحفظ بلا سبب ظاهر.
class _MeasurementFields extends StatelessWidget {
  const _MeasurementFields({
    required this.age,
    required this.weight,
    required this.height,
  });

  final TextEditingController age;
  final TextEditingController weight;
  final TextEditingController height;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      AppTextField(
        controller: age,
        label: 'العمر',
        hint: '25',
        helper: 'بالسنوات',
        icon: Icons.cake_rounded,
        keyboardType: TextInputType.number,
        validator: (v) =>
            Validators.optionalNumber(v, min: 10, max: 90, label: 'العمر'),
      ),
      AppTextField(
        controller: weight,
        label: 'الوزن',
        hint: '75',
        helper: 'بالكيلوغرام',
        icon: Icons.scale_rounded,
        keyboardType: TextInputType.number,
        validator: (v) =>
            Validators.optionalNumber(v, min: 30, max: 250, label: 'الوزن'),
      ),
      AppTextField(
        controller: height,
        label: 'الطول',
        hint: '175',
        helper: 'بالسنتيمتر',
        icon: Icons.height_rounded,
        keyboardType: TextInputType.number,
        validator: (v) =>
            Validators.optionalNumber(v, min: 100, max: 230, label: 'الطول'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final field in fields) ...<Widget>[
                if (field != fields.first) const SizedBox(height: Space.lg),
                field,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final field in fields) ...<Widget>[
              if (field != fields.first) const SizedBox(width: Space.md),
              Expanded(child: field),
            ],
          ],
        );
      },
    );
  }
}

/// الإجراء الوحيد في الشاشة، مثبّت أسفلها.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.isEditing,
    required this.accent,
    required this.isLoading,
    required this.onSubmit,
  });

  final bool isEditing;
  final Color accent;
  final bool isLoading;
  final VoidCallback onSubmit;

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
            constraints: const BoxConstraints(maxWidth: Space.formWidth),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppButton.primary(
                    label: isEditing ? 'حفظ التعديلات' : 'يلا نبدأ',
                    isLoading: isLoading,
                    gradient: AppColors.accentGradient(accent),
                    onPressed: isLoading ? null : onSubmit,
                  ),
                  if (!isEditing) ...<Widget>[
                    const SizedBox(height: Space.sm),
                    Text(
                      'تقدر تغيّر مستواك في أي وقت من «حسابي».',
                      textAlign: TextAlign.center,
                      style: AppType.caption,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
