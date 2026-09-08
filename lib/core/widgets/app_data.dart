import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/sport_visuals.dart';
import 'app_surface.dart';

/// علامة الرياضة: الحرف الأول من اسمها فوق تدرّج مخصّص لها.
///
/// اخترنا الحرف بدل الرمز التعبيري لسبب وظيفي لا جمالي: التطبيق يَعِد
/// المستخدم بأن يكتب **أي** رياضة، ولا توجد مجموعة رموز تغطي «أي رياضة».
/// الرمز التعبيري يتغيّر شكله بين أندرويد و iOS، ولا يقبل ألوان الهوية،
/// ويكبر بشكل رديء. الحرف يعمل مع أي اسم، ويرث خط التطبيق وتدرّجه.
class SportMark extends StatelessWidget {
  const SportMark({
    super.key,
    required this.sport,
    required this.colors,
    this.size = 48,
    this.showIcon = true,
  });

  /// مقاسات الشارة. أربعة مقاسات تغطّي كل مواضعها في التطبيق.
  static const double sm = 32;
  static const double md = 44;
  static const double lg = 52;
  static const double xl = 96;

  final String sport;
  final List<Color> colors;
  final double size;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(size * 0.30),
        ),
        child: Center(
          child: showIcon
              ? Icon(
                  SportVisuals.iconFor(sport),
                  size: size * 0.54,
                  color: AppColors.onPrimary,
                )
              : Text(
                  SportVisuals.initialFor(sport),
                  textAlign: TextAlign.center,
                  style: AppType.h1.copyWith(
                    fontSize: size * 0.42,
                    height: 1,
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// شارة أحرف عامة — تُستخدم لصورة المستخدم الرمزية.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.mintGradient,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Center(
          child: Text(
            initials,
            style: AppType.brand(
              size: size * 0.36,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط تقدّم أفقي.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.colors,
    this.height = 8,
    this.semanticLabel,
  });

  final double value;
  final List<Color>? colors;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gradient = colors ?? AppColors.mintGradient;
    final ratio = value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: '${(ratio * 100).round()}٪',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: <Widget>[
            Container(height: height, color: AppColors.surfaceHigh),
            LayoutBuilder(
              builder: (context, constraints) => AnimatedContainer(
                duration: Motion.progress,
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * ratio,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حلقة تقدّم مع النسبة في مركزها.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.caption,
    this.size = 88,
    this.color,
  });

  final double value;

  /// كلمة واحدة تشرح ماذا تقيس النسبة.
  final String caption;

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0);

    return Semantics(
      label: caption,
      value: '${(ratio * 100).round()}٪',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: ratio),
                  duration: Motion.progress,
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) => CircularProgressIndicator(
                    value: animated,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceHigh,
                    color: color ?? AppColors.mint,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(ratio * 100).round()}٪',
                    style: AppType.number(size: size * 0.24),
                  ),
                  Text(caption, style: AppType.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة إحصائية صغيرة: رقم كبير وتسمية تحته.
///
/// الرقم محايد اللون عمداً. لو لوّنّا كل إحصاءة بلون مختلف لصارت الصفحة
/// قوس قزح بلا معنى — اللون هنا يميّز الأيقونة فقط حين يحمل دلالة حقيقية.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.isNumeric = true,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// لون دلالي للأيقونة — للسلسلة اليومية مثلاً. لا يلوّن الرقم.
  final Color? accent;

  final bool isNumeric;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      child: ExcludeSemantics(
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.lg,
          ),
          color: AppColors.surfaceElevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: IconSizes.sm,
                  color: accent ?? AppColors.textTertiary,
                ),
                const SizedBox(height: Space.md),
              ],
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isNumeric
                    ? AppType.number(size: 22)
                    : AppType.h3.copyWith(height: 1.15),
              ),
              const SizedBox(height: Space.xxs),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفّ من ثلاث إحصاءات بعرض متساوٍ — التركيبة المتكرّرة في التطبيق.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: Space.md),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
