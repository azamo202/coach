import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/subscription.dart';

/// بطاقة خطة واحدة في صفحة الاشتراك.
///
/// السعر أكبر عنصر في البطاقة لأنه العنصر الذي يُقارَن. وما يفتحه
/// الاشتراك مكتوب تحته بصيغة عدد صريح — «برنامج واحد»، «3 برامج» —
/// لا بصيغة تسويقية تترك المستخدم يخمّن ما اشتراه.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.price,
    required this.priceReady,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
    this.highlight = false,
  });

  final SubscriptionPlan plan;

  /// السعر كما يعرضه المتجر بعملة المستخدم.
  final String price;

  /// هل وصل السعر من StoreKit فعلاً؟ إن لا، نوضّح أنه تقريبي.
  final bool priceReady;

  final bool selected;
  final VoidCallback onTap;

  /// الخطة التي يشترك فيها المستخدم الآن.
  final bool isCurrent;

  /// خطة نبرزها كأفضل قيمة.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.mint : AppColors.border;

    return Semantics(
      button: true,
      selected: selected,
      label: '${plan.title}، $price ${plan.periodLabel}، ${plan.slotsLabel}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          borderColor: accent,
          color: selected ? AppColors.surfaceElevated : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _SelectionDot(selected: selected),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      plan.title,
                      style: AppType.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrent)
                    const Flexible(
                      child: AppTag(
                        label: 'خطتك',
                        color: AppColors.mint,
                        subtle: true,
                      ),
                    )
                  else if (highlight)
                    const Flexible(
                      child: AppTag(
                        label: 'أفضل قيمة',
                        color: AppColors.coral,
                        subtle: true,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              // Wrap لا Row: السعر بعملة طويلة مع تكبير الخط يتجاوز عرض
              // البطاقة على شاشة 320، والنزول سطراً أفضل من قصّ السعر.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.xs,
                runSpacing: Space.xxs,
                children: <Widget>[
                  Text(
                    price,
                    style: AppType.number(size: 26, weight: AppType.bold),
                  ),
                  Text(
                    plan.periodLabel,
                    style: AppType.bodySm.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (!priceReady) Text('(تقريبي)', style: AppType.caption),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(plan.tagline, style: AppType.caption),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: <Widget>[
                  AppTag(
                    label: plan.slotsLabel,
                    icon: Icons.fitness_center_rounded,
                    subtle: true,
                  ),
                  if (plan.coachAdvice)
                    const AppTag(
                      label: 'المدرّب الذكي',
                      icon: Icons.psychology_alt_rounded,
                      subtle: true,
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

/// دائرة الاختيار — تعتمد على الشكل لا على اللون وحده.
class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      width: IconSizes.md,
      height: IconSizes.md,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.mint : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.mint : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.onPrimary,
            )
          : null,
    );
  }
}
