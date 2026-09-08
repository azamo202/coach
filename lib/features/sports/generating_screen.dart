import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/services/prompt_builder.dart';
import '../../routing/app_router.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import '../program/program_screen.dart';

/// شاشة انتظار التوليد.
///
/// الانتظار هنا يطول (٢٠–٦٠ ثانية)، فدوّارة صامتة تجعل المستخدم يظنّ التطبيق
/// متوقّفاً. الخطوات المكتوبة تخبره بما يجري وكم بقي تقريباً.
class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({super.key, required this.request});

  final ProgramRequest request;

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> {
  Timer? _stepTimer;
  int _step = 0;
  String? _error;

  late final List<String> _steps = <String>[
    'نحلّل متطلبات ${widget.request.sport}',
    'نضبط الصعوبة على مستوى ${widget.request.level.label}',
    'نبني التدرّج عبر ${widget.request.resolvedWeeks} أسابيع',
    'نختار التمارين وطريقة أداء كل واحد',
    'نراجع البرنامج ونجهّزه لك',
  ];

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        if (_step < _steps.length - 1) _step++;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final entry = await library.generateProgram(widget.request);
    if (!mounted) return;

    if (entry == null) {
      setState(() => _error = library.error ?? 'تعذّر توليد البرنامج');
      // الفشل قد يكون سببه انتهاء الحصة على الخادم — نحدّث الصورة لتطابقه.
      unawaited(subscription.refresh());
      return;
    }

    // البرنامج الجديد شغل حصة: نحدّث الصلاحية حتى تعرض بقية الشاشات
    // العدد الصحيح فوراً.
    unawaited(subscription.refresh());
    await context.replaceWith(ProgramScreen(programId: entry.id));
  }

  void _retry() {
    setState(() {
      _error = null;
      _step = 0;
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AccentPalette.byName(widget.request.sport);

    return PopScope(
      // لا نسمح بالخروج أثناء التوليد حتى لا يضيع الطلب في منتصفه.
      canPop: _error != null,
      child: Scaffold(
        body: BrandBackdrop(
          colors: colors,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
              child: _error != null ? _buildError() : _buildLoading(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(List<Color> colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SportMark(
            sport: widget.request.sport, colors: colors, size: SportMark.xl,),
        const SizedBox(height: Space.x3),
        Text(
          'نجهّز برنامج ${widget.request.sport}',
          textAlign: TextAlign.center,
          style: AppType.h2,
        ),
        const SizedBox(height: Space.md),
        AppTag(
          label: 'مستوى ${widget.request.level.label}',
          icon: widget.request.level.icon,
          color: widget.request.level.color,
        ),
        const SizedBox(height: Space.x4),
        Semantics(
          liveRegion: true,
          label: _steps[_step],
          child: ExcludeSemantics(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < _steps.length; i++)
                  _Step(
                    label: _steps[i],
                    done: i < _step,
                    active: i == _step,
                    accent: colors.first,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ErrorStateView(
          title: 'ما قدرنا نجهّز البرنامج',
          message: _error ?? '',
          onRetry: _retry,
        ),
        AppButton.ghost(
          label: 'رجوع لتعديل الطلب',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool done;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: IconSizes.md,
            height: IconSizes.md,
            child: done
                ? Icon(Icons.check_circle_rounded,
                    size: IconSizes.md, color: accent,)
                : active
                    ? CircularProgressIndicator(strokeWidth: 2, color: accent)
                    : const Icon(
                        Icons.circle_outlined,
                        size: IconSizes.sm,
                        color: AppColors.textTertiary,
                      ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              label,
              style: active
                  ? AppType.body.copyWith(fontWeight: AppType.semiBold)
                  : AppType.body.copyWith(
                      color: done
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
