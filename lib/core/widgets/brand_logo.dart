import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// علامة CoachMint — علامة صح بتدرّج النعناع، وورقة مرجانية أعلاها.
///
/// الإحداثيات مستخرجة حرفياً من ملف الشعار الأصلي (`coachmint-glyph.pdf`)
/// ومُطبَّعة على مربع 0→1، فالشكل مطابق للأصل عند أي مقاس.
///
/// قواعد الهوية المطبَّقة هنا:
/// - تدرّج النعناع ثابت الاتجاه (فاتح عند طرف العلامة، غامق عند أسفلها)
/// - بلا ظلال ولا تأثيرات ثلاثية الأبعاد
/// - الورقة المرجانية جزء أصيل من العلامة ولا تُحذف
class CoachMintMark extends StatelessWidget {
  const CoachMintMark({super.key, this.size = 48, this.showLeaf = true});

  final double size;

  /// تُخفى الورقة فقط في المقاسات الصغيرة جداً التي تختفي فيها أصلاً.
  final bool showLeaf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CoachMintMarkPainter(showLeaf: showLeaf),
        isComplex: false,
      ),
    );
  }
}

class _CoachMintMarkPainter extends CustomPainter {
  const _CoachMintMarkPainter({required this.showLeaf});

  final bool showLeaf;

  // --- إحداثيات مطبَّعة (0→1) مأخوذة من ملف الشعار الأصلي ---------------

  /// طرف الذراع القصير (أسفل يسار).
  static const Offset _tailStart = Offset(0.30177, 0.58105);

  /// رأس الزاوية.
  static const Offset _vertex = Offset(0.40918, 0.67870);

  /// طرف الذراع الطويل (أعلى يمين، تحت الورقة).
  static const Offset _tipEnd = Offset(0.60450, 0.40527);

  static const double _strokeRatio = 0.06836;

  /// مركز الورقة المرجانية.
  static const Offset _leafCenter = Offset(0.66113, 0.34863);
  static const double _leafSemiMajor = 0.08301;
  static const double _leafSemiMinor = 0.04395;

  /// ميل الورقة بالراديان (‎-38°‎).
  static const double _leafRotation = -0.66323;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    Offset at(Offset n) => Offset(n.dx * side, n.dy * side);

    final path = Path()
      ..moveTo(at(_tailStart).dx, at(_tailStart).dy)
      ..lineTo(at(_vertex).dx, at(_vertex).dy)
      ..lineTo(at(_tipEnd).dx, at(_tipEnd).dy);

    // تدرّج النعناع الرسمي — فاتح عند الطرف العلوي، غامق عند الأسفل.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeRatio * side
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: AppColors.mintGradient,
      ).createShader(Rect.fromLTWH(0, 0, side, side));

    canvas.drawPath(path, stroke);

    if (!showLeaf) return;

    canvas
      ..save()
      ..translate(at(_leafCenter).dx, at(_leafCenter).dy)
      ..rotate(_leafRotation)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: _leafSemiMajor * 2 * side,
          height: _leafSemiMinor * 2 * side,
        ),
        Paint()
          ..color = AppColors.coral
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_CoachMintMarkPainter oldDelegate) =>
      oldDelegate.showLeaf != showLeaf;
}

/// الشعار الكامل: العلامة + الاسم «CoachMint».
///
/// «Coach» بلون النص الأساسي و«Mint» بلون النعناع — كما في دليل الهوية،
/// وبنمط العلامة المعتمد من `AppType.brand`.
class CoachMintLogo extends StatelessWidget {
  const CoachMintLogo({
    super.key,
    this.markSize = 44,
    this.fontSize = 30,
    this.coachColor,
    this.showMark = true,
  });

  final double markSize;
  final double fontSize;
  final Color? coachColor;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final wordStyle = AppType.brand(size: fontSize);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showMark) ...<Widget>[
          CoachMintMark(size: markSize),
          SizedBox(width: markSize * 0.16),
        ],
        // الاسم لاتيني دائماً، فنثبّت اتجاهه حتى داخل واجهة عربية.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: 'Coach',
                  style: wordStyle.copyWith(
                    color: coachColor ?? AppColors.offWhite,
                  ),
                ),
                TextSpan(
                  text: 'Mint',
                  style: wordStyle.copyWith(color: AppColors.mint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// أيقونة العلامة داخل مربع بخلفية Spruce — تُستخدم كأفاتار أو شارة.
class CoachMintBadge extends StatelessWidget {
  const CoachMintBadge({super.key, this.size = 56, this.background});

  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.spruce,
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(child: CoachMintMark(size: size * 0.72)),
    );
  }
}
