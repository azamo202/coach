import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// الحالة الفارغة.
///
/// الشاشة الفارغة دعوة للتصرّف، لا اعتذار. لذلك لكل حالة فارغة هنا سبب
/// مكتوب وإجراء واحد واضح يخرج المستخدم منها.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: Touch.min + Space.xxl,
              height: Touch.min + Space.xxl,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                icon,
                size: IconSizes.xl,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: Space.xl),
            Text(title, textAlign: TextAlign.center, style: AppType.h2),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.textTertiary),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: Space.xxl),
              AppButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة الفشل على مستوى الشاشة.
///
/// الرسالة تقول ما الذي حدث، والزرّ يقول ما الذي يفعله المستخدم الآن.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'ما قدرنا نكمّل',
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: Touch.min + Space.xxl,
              height: Touch.min + Space.xxl,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.32),
                ),
              ),
              child: Icon(icon, size: IconSizes.xl, color: AppColors.danger),
            ),
            const SizedBox(height: Space.xl),
            Text(title, textAlign: TextAlign.center, style: AppType.h2),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.textTertiary),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: Space.xxl),
              AppButton.primary(
                label: 'حاول مرة ثانية',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// نبرة الملاحظة داخل الشاشة.
enum NoticeTone { neutral, warning, danger }

/// ملاحظة داخل سياق الصفحة — خطأ نموذج، تنبيه سلامة، معلومة مهمّة.
///
/// تحمل أيقونة إلى جانب لونها، فلا تعتمد على اللون وحده لنقل معناها.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.danger,
    this.icon,
    this.title,
    this.onRetry,
  });

  final String message;
  final NoticeTone tone;
  final IconData? icon;
  final String? title;
  final VoidCallback? onRetry;

  Color get _accent => switch (tone) {
        NoticeTone.neutral => AppColors.textTertiary,
        NoticeTone.warning => AppColors.warning,
        NoticeTone.danger => AppColors.danger,
      };

  IconData get _icon =>
      icon ??
      switch (tone) {
        NoticeTone.neutral => Icons.info_outline_rounded,
        NoticeTone.warning => Icons.warning_amber_rounded,
        NoticeTone.danger => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: tone == NoticeTone.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.md + 2),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: _accent.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_icon, color: _accent, size: IconSizes.md),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null) ...<Widget>[
                    Text(title!, style: AppType.h4.copyWith(color: _accent)),
                    const SizedBox(height: Space.xs),
                  ],
                  Text(
                    message,
                    style: AppType.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(width: Space.sm),
              TextButton(onPressed: onRetry, child: const Text('إعادة')),
            ],
          ],
        ),
      ),
    );
  }
}

/// مستطيل رمادي ينبض مكان محتوى لم يصل بعد.
///
/// أفضل من دوّارة في منتصف الشاشة: يحجز المساحة الصحيحة فلا يقفز التخطيط
/// عند وصول البيانات، ويُظهر شكل ما هو قادم.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = Radii.sm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // من يطلب تقليل الحركة يحصل على مستطيل ساكن بنفس المكان والمقاس.
    final animate = !MediaQuery.disableAnimationsOf(context);

    final box = Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (!animate) return box;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: box,
    );
  }
}

/// هيكل مؤقّت لصفوف قائمة البرامج.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.itemHeight = 96});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ExcludeSemantics(
        child: Column(
          children: <Widget>[
            for (var i = 0; i < count; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Space.md),
              Skeleton(height: itemHeight, radius: Radii.lg),
            ],
          ],
        ),
      ),
    );
  }
}

/// حوار تأكيد موحّد.
///
/// نستخدمه قبل كل إجراء لا يمكن التراجع عنه — ونصّه يقول بالضبط ما الذي
/// سيُفقد، لا «هل أنت متأكد؟» وحدها.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.lg,
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textTertiary,
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.danger : AppColors.mint,
            foregroundColor:
                isDestructive ? AppColors.offWhite : AppColors.onPrimary,
            elevation: 0,
            minimumSize: const Size(Touch.min * 2, Touch.min),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// رسالة سريعة أسفل الشاشة تؤكّد ما حدث للتوّ.
void showAppSnack(BuildContext context, String message,
    {bool isError = false,}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? AppColors.danger : AppColors.mint,
              size: IconSizes.md,
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
}
