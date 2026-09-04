import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// درجة أهمية الزر.
///
/// في كل شاشة زر أساسي واحد فقط. ما عداه ثانوي أو صامت — وإلا لم يعد للأساسي
/// معنى.
enum AppButtonVariant {
  /// الإجراء الوحيد الذي نريد من المستخدم أن يفعله في هذه الشاشة.
  primary,

  /// إجراء بديل مقبول: رجوع، تخطٍّ، تراجع.
  secondary,

  /// إجراء موجود لكنه لا يستحق أن يجذب النظر.
  ghost,

  /// إجراء يتلف بيانات. لونه تحذير، لا زينة.
  danger,
}

/// الزر الموحّد للتطبيق.
///
/// يغطي كل حالاته: العادي، المضغوط، المشغول، والمعطّل. الحالة المشغولة تعطّل
/// الضغط تلقائياً حتى لا يُرسل الطلب مرتين.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.gradient,
    this.semanticLabel,
  });

  /// اختصار للزر الأساسي.
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.gradient,
    this.semanticLabel,
  }) : variant = AppButtonVariant.primary;

  /// اختصار للزر الثانوي.
  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  })  : variant = AppButtonVariant.secondary,
        gradient = null;

  /// اختصار للزر الصامت.
  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  })  : variant = AppButtonVariant.ghost,
        gradient = null;

  /// اختصار لزر الإجراء المتلف.
  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  })  : variant = AppButtonVariant.danger,
        gradient = null;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;

  /// يملأ العرض المتاح. أطفئه للأزرار التي تقف بجانب غيرها.
  final bool expand;

  /// تدرّج بديل للزر الأساسي — يستخدمه سياق الرياضة أو المستوى.
  final List<Color>? gradient;

  /// نص بديل للقارئ الصوتي حين لا يكفي [label] وحده.
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final child = _Content(
      label: label,
      icon: icon,
      isLoading: isLoading,
      foreground: _foreground,
    );

    final button = switch (variant) {
      AppButtonVariant.primary => _GradientButton(
          gradient: gradient ?? AppColors.mintGradient,
          enabled: _enabled,
          onPressed: _handlePress,
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: _enabled ? _handlePress : null,
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: _enabled ? _handlePress : null,
          child: child,
        ),
      AppButtonVariant.danger => OutlinedButton(
          onPressed: _enabled ? _handlePress : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
          ),
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: variant == AppButtonVariant.ghost ? null : Touch.button,
        child: button,
      ),
    );
  }

  Color get _foreground => switch (variant) {
        AppButtonVariant.primary => AppColors.onPrimary,
        AppButtonVariant.secondary => AppColors.textPrimary,
        AppButtonVariant.ghost => AppColors.mint,
        AppButtonVariant.danger => AppColors.danger,
      };

  void _handlePress() {
    HapticFeedback.mediumImpact();
    onPressed!();
  }
}

/// الزر الأساسي بتدرّج النعناع — العمق من اللون وحده، بلا ظل.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.gradient,
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  final List<Color> gradient;
  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.md);

    return Opacity(
      // 0.45 يقرأه المستخدم كـ«غير متاح الآن» لا كـ«مخفي».
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: radius,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.foreground,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: IconSizes.md,
        height: IconSizes.md,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          // الأيقونة تكرّر ما يقوله النص، فنخفيها عن القارئ الصوتي.
          ExcludeSemantics(
            child: Icon(icon, size: IconSizes.md, color: foreground),
          ),
          const SizedBox(width: Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.button.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

/// زر أيقونة بمساحة لمس كاملة، للاستخدام في الرؤوس والصفوف.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// اسم الإجراء — إلزامي: زر بأيقونة فقط بلا اسم لا يقرؤه أحد.
  final String tooltip;

  final Color? color;

  /// خلفية خفيفة تميّزه حين يقف وحده في رأس الشاشة.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: IconSizes.lg),
      style: IconButton.styleFrom(
        foregroundColor: color ?? AppColors.textSecondary,
        backgroundColor: filled ? AppColors.surfaceElevated : null,
      ),
    );
  }
}
