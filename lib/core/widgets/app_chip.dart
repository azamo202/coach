import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// شريحة اختيار قابلة للضغط — فلتر أو خيار من مجموعة.
///
/// تعلن حالتها (محدّد / غير محدّد) للقارئ الصوتي، ولا تعتمد على اللون وحده:
/// المحدّد يتغيّر لونه **و** سُمك حدّه **و** وزن نصّه.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// لون التحديد. اتركه فارغاً ليأخذ لون العلامة.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.mint;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(Radii.pill),
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: Touch.min),
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: selected ? accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: IconSizes.sm,
                      color: selected ? accent : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                Text(
                  label,
                  style: AppType.label.copyWith(
                    color: selected ? accent : AppColors.textSecondary,
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

/// شارة ثابتة لا تُضغط: مستوى، هدف، حالة، وحدة قياس.
///
/// الفرق عن [AppChip] مقصود — ما لا يُضغط لا يجوز أن يبدو قابلاً للضغط.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.subtle = false,
  });

  final String label;
  final IconData? icon;

  /// لون دلالي. اتركه فارغاً للشارة المحايدة.
  final Color? color;

  /// نسخة أهدأ بلا حدّ — للشارات التي تتكرّر كثيراً في قائمة.
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color == null
            ? AppColors.surfaceElevated
            : accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: subtle
            ? null
            : Border.all(
                color: color == null
                    ? AppColors.border
                    : accent.withValues(alpha: 0.30),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            ExcludeSemantics(
              child: Icon(icon, size: IconSizes.sm - 2, color: accent),
            ),
            const SizedBox(width: Space.xs + 2),
          ],
          Text(
            label,
            style: AppType.caption.copyWith(
              // النصّ الصغير يحتاج درجة أفتح قليلاً من درجة الأيقونة.
              color: color == null
                  ? AppColors.textSecondary
                  : AppColors.asText(accent),
              fontWeight: AppType.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

/// قيمة مع وحدتها في صندوق مدمج — «٣ مجموعات»، «٦٠ث راحة».
///
/// الرقم بخط لاتيني جدولي حتى لا يقفز الصفّ حين تتغيّر القيمة.
class AppMetricPill extends StatelessWidget {
  const AppMetricPill({super.key, required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: AppType.number(size: 13)),
          const SizedBox(width: Space.xs + 2),
          Text(unit, style: AppType.caption),
        ],
      ),
    );
  }
}
