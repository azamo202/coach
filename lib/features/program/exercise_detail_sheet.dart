import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/sport_visuals.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/coach_advice.dart';
import '../../data/models/training_program.dart';
import '../../data/services/ai_program_service.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/subscription_controller.dart';
import '../paywall/paywall_screen.dart';

/// المرجع السريع لطريقة أداء التمرين واستشارة المدرب الذكي.
Future<void> showExerciseDetail(
  BuildContext context, {
  required Exercise exercise,
  required String sport,
  required List<Color> colors,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.spruceDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    constraints: const BoxConstraints(maxWidth: Space.contentWidth),
    builder: (context) => ExerciseDetailSheet(
      exercise: exercise,
      sport: sport,
      colors: colors,
    ),
  );
}

/// ورقة تفاصيل التمرين مع استشارات المدرب الذكي الحية.
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

  static bool _isDurationReps(String reps) {
    final lower = reps.trim();
    return lower.contains('دقيق') ||
        lower.contains('ساع') ||
        lower.contains('ثاني') ||
        lower.contains('متر') ||
        lower.contains('كم');
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'ما قدرنا نفتح الرابط', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDuration = _isDurationReps(exercise.reps);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SportMark(
                sport: sport,
                colors: colors,
                size: SportMark.md,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(exercise.name, style: AppType.h1),
                    if (exercise.targetMuscles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Space.xxs),
                      Text(
                        exercise.targetMuscles,
                        style: AppType.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
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
                  label: isDuration ? 'المدة' : 'تكرار',
                  icon: isDuration
                      ? Icons.timer_outlined
                      : Icons.fitness_center_rounded,
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
            const SectionHeader(
              title: 'طريقة الأداء',
              subtitle: 'خطوات التنفيذ الصحيحة للحركة',
            ),
            AppCard(
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: IconSizes.tile,
                    height: IconSizes.tile,
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: IconSizes.sm,
                        color: colors.first,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      exercise.howTo,
                      style: AppType.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xxl),
          ],
          if (exercise.cue.isNotEmpty) ...<Widget>[
            AppNotice(
              message: exercise.cue,
              tone: NoticeTone.neutral,
              icon: Icons.lightbulb_rounded,
            ),
            const SizedBox(height: Space.xxl),
          ],
          if (exercise.equipment.isNotEmpty ||
              exercise.tempo.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'تفاصيل'),
            AppCard(
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                children: <Widget>[
                  if (exercise.equipment.isNotEmpty)
                    _DetailRow(
                      icon: Icons.fitness_center_outlined,
                      label: 'الأدوات',
                      value: exercise.equipment,
                    ),
                  if (exercise.equipment.isNotEmpty && exercise.tempo.isNotEmpty)
                    const Divider(height: Space.lg, color: AppColors.borderSoft),
                  if (exercise.tempo.isNotEmpty)
                    _DetailRow(
                      icon: Icons.speed_rounded,
                      label: 'إيقاع الأداء',
                      value: exercise.tempo,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.xxl),
          ],

          // قسم استشارة المدرب الذكي
          _AiCoachSection(
            exercise: exercise,
            sport: sport,
            accentColor: colors.first,
          ),
          const SizedBox(height: Space.xxl),

          const SectionHeader(
            title: 'شوف الحركة',
            subtitle: 'يفتح بحثاً في متصفّحك يوضّح الأداء بالصورة والفيديو',
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.secondary(
                  label: 'فيديو',
                  icon: Icons.play_circle_filled_rounded,
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
                  icon: Icons.photo_library_rounded,
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

class _PromptItem {
  const _PromptItem(this.prompt, this.icon);
  final String prompt;
  final IconData icon;
}

/// قسم تفاعلي للتواصل مع المدرب الذكي (OpenAI API).
class _AiCoachSection extends StatefulWidget {
  const _AiCoachSection({
    required this.exercise,
    required this.sport,
    required this.accentColor,
  });

  final Exercise exercise;
  final String sport;
  final Color accentColor;

  @override
  State<_AiCoachSection> createState() => _AiCoachSectionState();
}

class _AiCoachSectionState extends State<_AiCoachSection> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  CoachAdvice? _advice;

  static const List<_PromptItem> _quickPrompts = <_PromptItem>[
    _PromptItem('أشعر بألم أو انزعاج أثناء التمرين', Icons.healing_rounded),
    _PromptItem('تمرين بديل بدون أدوات', Icons.swap_horiz_rounded),
    _PromptItem('نصيحة لتكنيك التنفس', Icons.air_rounded),
    _PromptItem('تعديل لتسهيل الحركة', Icons.tune_rounded),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask([String? customPrompt]) async {
    final question = (customPrompt ?? _questionController.text).trim();
    if (question.isEmpty) return;

    FocusScope.of(context).unfocus();

    // المدرّب الذكي ميزة اشتراك. الخادم يرفضها بدونه، لكن عرض صفحة
    // الاشتراك أوضح للمستخدم من رسالة رفض داخل ورقة التمرين.
    final subscription = context.read<SubscriptionController>();
    if (!subscription.canAskCoach) {
      await context.pushPage<void>(
        const PaywallScreen(
          reason: 'استشارة المدرّب الذكي متاحة للمشتركين.',
        ),
      );
      if (!mounted) return;
      await subscription.refresh();
      if (!mounted || !subscription.canAskCoach) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ai = context.read<AiProgramService>();
      final auth = context.read<AuthController>();
      final user = auth.user;

      final advice = await ai.getCoachAdvice(
        question: question,
        exercise: widget.exercise,
        sport: widget.sport,
        level: user?.level.label,
        goal: user?.goal.label,
      );

      if (!mounted) return;
      setState(() {
        _advice = advice;
        _isLoading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذّر التواصل مع المدرب الذكي الآن. حاول بعد لحظات.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
          title: 'استشر المدرب الذكي',
          subtitle: 'نصائح تكنيك، بدائل، وتعديلات آمنة بإشراف الذكاء الاصطناعي',
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: _quickPrompts.map((item) {
            return AppChip(
              label: item.prompt,
              icon: item.icon,
              selected: false,
              color: widget.accentColor,
              onTap: () => _ask(item.prompt),
            );
          }).toList(),
        ),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _questionController,
                label: 'سؤالك للمدرب',
                hint: 'أو اكتب سؤالك للمدرب هنا…',
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
              ),
            ),
            const SizedBox(width: Space.sm),
            SizedBox(
              height: Touch.field,
              width: Touch.field,
              child: Material(
                color: widget.accentColor,
                borderRadius: BorderRadius.circular(Radii.md),
                child: InkWell(
                  onTap: _isLoading ? null : () => _ask(),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.spruceBlack,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            size: IconSizes.md,
                            color: AppColors.spruceBlack,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: Space.md),
          AppNotice(
            title: 'تنبيه',
            message: _errorMessage!,
            tone: NoticeTone.warning,
          ),
        ],
        if (_advice != null) ...<Widget>[
          const SizedBox(height: Space.lg),
          _AdviceCard(
            advice: _advice!,
            accentColor: widget.accentColor,
          ),
        ],
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.advice,
    required this.accentColor,
  });

  final CoachAdvice advice;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome_rounded, color: accentColor, size: 20),
              const SizedBox(width: Space.sm),
              Text(
                'رد المدرب الذكي',
                style: AppType.h4.copyWith(color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            advice.answer,
            style: AppType.body.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: AppColors.surfaceElevated,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'التوصية العملية:',
                  style: AppType.caption.copyWith(fontWeight: AppType.bold),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  advice.recommendation,
                  style: AppType.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (advice.alternativeExercise.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Space.md),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: Space.xs),
                      Text(
                        'تمرين بديل مقترح: ',
                        style: AppType.caption.copyWith(
                          fontWeight: AppType.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          advice.alternativeExercise,
                          style: AppType.caption.copyWith(
                            color: AppColors.mint,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (advice.warning != null && advice.warning!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.md),
            AppNotice(
              title: 'تنبيه وقائي للسلامة',
              message: advice.warning!,
              tone: NoticeTone.danger,
              icon: Icons.health_and_safety_rounded,
            ),
          ],

          // إخلاء مسؤولية دائم لا مشروط.
          //
          // `advice.warning` يأتي من الذكاء الاصطناعي، فقد يغيب. وأحد
          // الأسئلة الجاهزة فوق هو «أشعر بألم أو انزعاج أثناء التمرين» —
          // أي أن الرد قد يُقرأ كتشخيص. جواب صحي مولّد آلياً بلا إفصاح
          // ثابت عن كونه آلياً وغير طبي سببُ رفض في مراجعة App Store،
          // ولذلك يظهر هذا السطر تحت كل رد بلا استثناء.
          const SizedBox(height: Space.md),
          Text(
            'رد مولّد آلياً لأغراض التدريب العام — ليس تشخيصاً ولا نصيحة '
            'طبية. مع أي ألم مستمر أو حالة صحية، راجع مختصاً.',
            style: AppType.caption,
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
          padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
          child: Column(
            children: <Widget>[
              Container(
                width: IconSizes.tile,
                height: IconSizes.tile,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: IconSizes.sm + 2, color: accent),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.number(size: 15),
              ),
              const SizedBox(height: Space.xxs),
              Text(
                label,
                style: AppType.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: IconSizes.sm, color: AppColors.textTertiary),
          const SizedBox(width: Space.sm),
        ],
        Text(label, style: AppType.caption),
        const Spacer(),
        Text(
          value,
          style: AppType.bodySm.copyWith(
            color: AppColors.textPrimary,
            fontWeight: AppType.semiBold,
          ),
        ),
      ],
    );
  }
}
