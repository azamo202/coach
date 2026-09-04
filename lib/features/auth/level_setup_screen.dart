import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/fitness_level.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../shell/main_shell.dart';

/// تحديد المستوى والهدف — يحدّد صعوبة كل برنامج يولّده الذكاء الاصطناعي.
///
/// تظهر بعد إنشاء الحساب، ويُعاد إليها من الملف الشخصي.
class LevelSetupScreen extends StatefulWidget {
  const LevelSetupScreen({super.key, this.isEditing = false});

  /// عند التعديل من الملف الشخصي نعرض زرّ رجوع ونغيّر نص الزرّ.
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

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

    return Scaffold(
      body: BrandBackdrop(
        colors: <Color>[_level.color, _level.color],
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: Space.x3),
              children: <Widget>[
                ScreenHeader(
                  title: widget.isEditing ? 'مستواي وهدفي' : 'وش مستواك؟',
                  subtitle: widget.isEditing
                      ? 'يؤثّر على كل برنامج تولّده بعد الآن'
                      : 'أهم خطوة — عليها يبني المدرّب الذكي برامجك',
                  showBack: widget.isEditing,
                  padding: EdgeInsets.fromLTRB(
                    widget.isEditing ? Space.sm : Space.screenInset,
                    Space.sm,
                    Space.screenInset,
                    Space.xxl,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.screenInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final level in FitnessLevel.values) ...<Widget>[
                        _LevelCard(
                          level: level,
                          selected: _level == level,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _level = level);
                          },
                        ),
                        const SizedBox(height: Space.md),
                      ],
                      const SizedBox(height: Space.lg),
                      const SectionHeader(
                        title: 'هدفك الأساسي',
                        subtitle: 'يوجّه المدرّب لنوع التمارين المناسبة',
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
                              color: _level.color,
                              onTap: () => setState(() => _goal = goal),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.x3),
                      const SectionHeader(
                        title: 'بيانات إضافية',
                        subtitle: 'اختيارية — لكنها تجعل البرنامج أدقّ',
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: AppTextField(
                              controller: _ageController,
                              label: 'العمر',
                              hint: '٢٥',
                              keyboardType: TextInputType.number,
                              validator: (v) => Validators.optionalNumber(
                                v,
                                min: 10,
                                max: 90,
                                label: 'العمر',
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: AppTextField(
                              controller: _weightController,
                              label: 'الوزن (كجم)',
                              hint: '٧٥',
                              keyboardType: TextInputType.number,
                              validator: (v) => Validators.optionalNumber(
                                v,
                                min: 30,
                                max: 250,
                                label: 'الوزن',
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: AppTextField(
                              controller: _heightController,
                              label: 'الطول (سم)',
                              hint: '١٧٥',
                              keyboardType: TextInputType.number,
                              validator: (v) => Validators.optionalNumber(
                                v,
                                min: 100,
                                max: 230,
                                label: 'الطول',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xl),
                      Text('الجنس', style: AppType.label),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        children: <Widget>[
                          for (final value in const <String>['ذكر', 'أنثى'])
                            AppChip(
                              label: value,
                              selected: _gender == value,
                              color: _level.color,
                              onTap: () => setState(
                                () => _gender = _gender == value ? null : value,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.x3),
                      AppButton.primary(
                        label: widget.isEditing ? 'حفظ التعديلات' : 'يلا نبدأ',
                        isLoading: auth.isBusy,
                        gradient: AppColors.accentGradient(_level.color),
                        onPressed: auth.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: Space.lg),
                      Text(
                        'تقدر تغيّر مستواك في أي وقت من «حسابي»، وتعيد توليد '
                        'أي برنامج على المستوى الجديد.',
                        textAlign: TextAlign.center,
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة اختيار مستوى — بديلة عن زرّ اختيار عادي لأن لكل مستوى شرحاً وحجماً.
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
    return Semantics(
      selected: selected,
      button: true,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: Motion.fast,
          decoration: BoxDecoration(
            color: selected
                ? level.color.withValues(alpha: 0.10)
                : AppColors.spruceDeep,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? level.color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.lg),
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: Touch.min,
                      height: Touch.min,
                      decoration: BoxDecoration(
                        color: level.color
                            .withValues(alpha: selected ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Icon(
                        level.icon,
                        color: level.color,
                        size: IconSizes.lg,
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(level.label, style: AppType.h3),
                              const SizedBox(width: Space.sm),
                              AppTag(
                                label: '${level.defaultWeeks} أسابيع · '
                                    '${level.defaultSessionsPerWeek} جلسات',
                                color: level.color,
                                subtle: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.xs),
                          Text(level.description, style: AppType.bodySm),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    _SelectDot(selected: selected, color: level.color),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      width: IconSizes.lg,
      height: IconSizes.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: IconSizes.sm - 2,
              color: AppColors.spruce,
            )
          : null,
    );
  }
}
