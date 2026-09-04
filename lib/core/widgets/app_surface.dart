import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// خلفية الشاشات: طبقة لون شفافة تنزل من الأعلى نحو Spruce.
///
/// ليست ظلاً ولا توهجاً — تعطي الشاشة رأساً بصرياً دون أن تضيف حدوداً أو
/// صناديق جديدة.
///
/// الارتفاع ثابت ولا يُمرَّر من الشاشات: كانت كل شاشة تختار ارتفاعها
/// (320 و380 و400 و420 و480)، فيتغيّر ثقل أعلى الشاشة عند كل انتقال.
/// اللون وحده هو ما يتغيّر.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  static const double _height = 360;

  @override
  Widget build(BuildContext context) {
    final accent = (colors ?? AppColors.mintGradient).first;
    return Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    accent.withValues(alpha: 0.11),
                    accent.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// السطح الأساسي: العمق من الطبقة والحدّ، بلا ظل.
///
/// البطاقة ليست الحلّ الافتراضي لكل شيء. استخدمها حين يكون المحتوى وحدة
/// قائمة بذاتها يمكن الضغط عليها أو فصلها عمّا حولها — لا لمجرد تأطير نص.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = Radii.lg,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.spruceDeep,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.border),
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap!();
            },
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// رأس الشاشة الموحّد.
///
/// كل شاشة في التطبيق تبدأ بهذا الرأس — نفس الموضع، نفس المقاس، نفس المسافة
/// تحته. هذا وحده يجعل التنقّل بين الشاشات يبدو كتنقّل داخل تطبيق واحد.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = false,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(
      Space.screenInset,
      Space.sm,
      Space.screenInset,
      Space.xxl,
    ),
  });

  final String title;
  final String? subtitle;

  /// إجراء واحد على الأكثر. أكثر من ذلك يذهب إلى قائمة إضافية.
  final Widget? trailing;

  /// زر الرجوع للشاشات المدفوعة فوق غيرها.
  final bool showBack;

  /// عنصر يسبق العنوان — شارة الرياضة مثلاً.
  final Widget? leading;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (showBack) ...<Widget>[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'رجوع',
              // الأيقونة تنعكس تلقائياً مع اتجاه الواجهة.
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: Space.xs),
          ],
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.h1,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Space.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySm,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Space.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// عنوان قسم داخل الشاشة، مع إجراء اختياري على يساره.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(header: true, child: Text(title, style: AppType.h3)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Space.xxs),
                  Text(subtitle!, style: AppType.bodySm),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
