import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// ظهور متدرّج للعناصر عند فتح الشاشة.
///
/// الفكرة أن الشاشة تُبنى أمام المستخدم بترتيب قراءتها — الشعار ثم العنوان ثم
/// النموذج — بدل أن تظهر دفعة واحدة. الحركة قصيرة ومنخفضة المسافة عمداً:
/// إحساس بالجودة لا عرض للحركة.
///
/// * [step] رقم العنصر في التسلسل — يضرب في [stagger] ليعطي تأخير البداية.
/// * الحركة تُلغى تلقائياً حين يطلب النظام تقليل الحركة
///   (`MediaQuery.disableAnimations`)، فيظهر المحتوى فوراً وكاملاً.
class RevealIn extends StatefulWidget {
  const RevealIn({
    super.key,
    required this.child,
    this.step = 0,
    this.stagger = const Duration(milliseconds: 70),
    this.duration = Motion.slow,
    this.offset = Space.lg,
  });

  final Widget child;

  /// ترتيب العنصر ضمن التسلسل، يبدأ من الصفر.
  final int step;

  /// الفارق الزمني بين كل عنصر والذي يليه.
  final Duration stagger;

  final Duration duration;

  /// المسافة الرأسية التي يقطعها العنصر صعوداً وهو يظهر.
  final double offset;

  @override
  State<RevealIn> createState() => _RevealInState();
}

class _RevealInState extends State<RevealIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  Timer? _delay;

  @override
  void initState() {
    super.initState();
    // الإنشاء في initState لا في تعريف الحقل: حقل كسول يُنشئ متحكّماً جديداً
    // داخل dispose لو تخلّصت الشجرة من العنصر قبل أن يُبنى.
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _delay = Timer(widget.stagger * widget.step, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
