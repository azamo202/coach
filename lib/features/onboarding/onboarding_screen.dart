import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_logo.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

/// الوعد الذي تعرضه الشريحة — كل واحد يُرسم كقطعة حقيقية من التطبيق.
enum _Proof { sportSearch, level, progression, tracking }

class _Slide {
  const _Slide({
    required this.proof,
    required this.title,
    required this.body,
    required this.proofLabel,
    required this.colors,
  });

  final _Proof proof;
  final String title;
  final String body;

  /// وصف الرسم للقارئ الصوتي — الرسم نفسه مستثنى من شجرة الوصول.
  final String proofLabel;

  final List<Color> colors;
}

/// شاشة تعريف تظهر مرة واحدة عند أول تشغيل.
///
/// المبدأ هنا: **الشريحة تُري الوعد ولا ترسم أيقونة عنه.** أيقونة داخل مربّع
/// ملوّن لا تقول شيئاً عن التطبيق — بينما حقل بحث يكتب اسم رياضة بنفسه،
/// وسلّم أسابيع يرتفع، وحلقة إنجاز تمتلئ، كلها تُري المستخدم الشاشة التي
/// سيستخدمها فعلاً. لذلك كل شريحة تعرض قطعة مبنيّة من مكوّنات التطبيق نفسها.
///
/// ثلاثة قرارات تخطيطية تحكم الشاشة:
/// 1. **العناوين لا تتحرّك بين الشريحتين.** المساحة موزّعة بنِسَب ثابتة
///    (رسم : نص)، فلا يقفز العنوان لأعلى أو لأسفل عند كل تمرير.
/// 2. **حركة الطبقات.** الرسم يتحرّك أبطأ من النصّ أثناء التمرير، فيُقرأ
///    عمقاً لا انزلاقاً مسطّحاً.
/// 3. **لون الخلفية والزرّ يتدرّج مع الإصبع** بدل أن يقفز عند تغيّر الصفحة.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      proof: _Proof.sportSearch,
      title: 'أي رياضة تبيها',
      body: 'اكتب اسم أي رياضة — كرة قدم، سباحة، بادل، تسلّق، أو غيرها. '
          'ما فيه قوائم محدودة.',
      proofLabel: 'حقل بحث يُكتب فيه اسم رياضة، وتحته أمثلة: بادل، سباحة، '
          'تسلّق.',
      colors: AppColors.mintGradient,
    ),
    _Slide(
      proof: _Proof.level,
      title: 'برنامج على مستواك أنت',
      body: 'حدّد مستواك: مبتدئ، متوسط، أو محترف. يبني المدرّب الذكي برنامجاً '
          'يناسب قدراتك — لا أسهل ولا أصعب مما تحتمل.',
      proofLabel: 'ثلاثة مستويات: مبتدئ، متوسط وهو المحدّد، ومحترف.',
      colors: AccentPalette.teal,
    ),
    _Slide(
      proof: _Proof.progression,
      title: 'تدرّج أسبوعي واضح',
      body: 'كل أسبوع أصعب من الذي قبله، مع عدد المجموعات والتكرارات وطريقة '
          'أداء كل تمرين خطوة بخطوة.',
      proofLabel: 'أربعة أسابيع يرتفع حِملها بالترتيب: 3×8 ثم 3×10 ثم 4×10 '
          'ثم 4×12.',
      colors: AccentPalette.spring,
    ),
    _Slide(
      proof: _Proof.tracking,
      title: 'تتبّع تلقائي لتقدّمك',
      body: 'علّم جلساتك المكتملة وشوف نسبة إنجازك تكبر. واربط التطبيق ببيانات '
          'صحتك ليأخذ نشاطك اليومي بالحسبان.',
      proofLabel: 'حلقة إنجاز عند 68٪، مع 12 جلسة مكتملة و5 أيام متتالية.',
      colors: AccentPalette.aqua,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool goToSignUp}) async {
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    await auth.markOnboardingSeen();
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(
        goToSignUp ? const SignUpScreen() : const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _goTo(_index + 1);
    } else {
      _finish(goToSignUp: true);
    }
  }

  void _goTo(int i) {
    _pageController.animateToPage(
      i,
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
    );
  }

  /// موضع التمرير الحالي بالكسور — مصدر كل الحركة في هذه الشاشة.
  double get _offset {
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions) {
      return _pageController.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  /// لون الشريحة عند موضع كسريّ بين شريحتين.
  List<Color> _colorsAt(double offset) {
    final lower = offset.floor().clamp(0, _slides.length - 1);
    final upper = offset.ceil().clamp(0, _slides.length - 1);
    final t = offset - lower;
    final from = _slides[lower].colors;
    final to = _slides[upper].colors;
    return <Color>[
      Color.lerp(from.first, to.first, t)!,
      Color.lerp(from.last, to.last, t)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _pageController,
        builder: (context, _) {
          final offset = _offset;
          final colors = _colorsAt(offset);

          return BrandBackdrop(
            colors: colors,
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  _TopBar(onSkip: () => _finish(goToSignUp: false)),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => _SlideView(
                        slide: _slides[i],
                        // المسافة عن مركز الشاشة: 0 في المنتصف، ±1 عند الجار.
                        delta: reduceMotion ? 0 : (i - offset),
                        active: _index == i,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xxl,
                      vertical: Space.xl,
                    ),
                    child: _StepBar(
                      count: _slides.length,
                      offset: offset,
                      index: _index,
                      color: colors.first,
                      onTap: _goTo,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xxl,
                      0,
                      Space.xxl,
                      Space.lg,
                    ),
                    child: Column(
                      children: <Widget>[
                        AppButton.primary(
                          label: isLast ? 'ابدأ الآن' : 'التالي',
                          gradient: colors,
                          onPressed: _next,
                        ),
                        const SizedBox(height: Space.xs),
                        AppButton.ghost(
                          label: 'عندي حساب — تسجيل الدخول',
                          onPressed: () => _finish(goToSignUp: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// رأس الشاشة: هوية على اليمين ومخرج على اليسار.
///
/// الشعار هنا ليس زينة — الشاشة الأولى في التطبيق هي الموضع الوحيد الذي
/// يتعرّف فيه المستخدم على العلامة قبل أن يقرّر البقاء.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.sm, 0),
      child: Row(
        children: <Widget>[
          const CoachMintLogo(markSize: 26, wordmarkSize: 17),
          const Spacer(),
          TextButton(onPressed: onSkip, child: const Text('تخطّي')),
        ],
      ),
    );
  }
}

/// شريحة واحدة: رسم الوعد ثم العنوان ثم الشرح.
///
/// النِّسب (رسم 6 : نص 5) ثابتة في كل الشرائح، فيبقى العنوان على نفس
/// الارتفاع مهما اختلف طول النصّ — وهذا وحده يلغي «القفز» بين الشرائح.
class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.delta,
    required this.active,
  });

  final _Slide slide;

  /// بُعد الشريحة عن المركز: صفر في المنتصف، ±1 عند الجار.
  final double delta;

  final bool active;

  @override
  Widget build(BuildContext context) {
    final distance = delta.abs().clamp(0.0, 1.0);
    final fade = (1 - distance * 1.4).clamp(0.0, 1.0);

    return Semantics(
      label: '${slide.title}. ${slide.body}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // مربّع الرسم وصندوق النصّ لهما ارتفاع محجوز ثابت في كل
              // الشرائح، والمجموعة كلها متمركزة. النتيجة: العنوان على نفس
              // الارتفاع دائماً، وبلا فجوة ميتة أسفل النصّ.
              final height = constraints.maxHeight;
              final proofBox = (height * 0.46).clamp(120.0, 248.0);
              final textBox = (height * 0.30).clamp(96.0, 176.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // الرسم يتحرّك أبطأ من النصّ — الفرق بين 40 و96 هو كل
                  // الإحساس بالعمق أثناء التمرير.
                  SizedBox(
                    height: proofBox,
                    // الرسم يجلس على قاع صندوقه لا في منتصفه: ارتفاع البطاقة
                    // يختلف بين الشرائح، والتمركز كان يحوّل الفرق إلى فجوة
                    // متغيّرة بين الرسم وعنوانه — أسوأ موضع ممكن للفراغ.
                    // الفرق الآن يقع فوق الرسم حيث يُقرأ متنفّساً تحت الشعار.
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: fade,
                        child: Transform.translate(
                          offset: Offset(delta * 40, 0),
                          child: Transform.scale(
                            scale: 1 - distance * 0.06,
                            child: RepaintBoundary(
                              child: _ProofPanel(slide: slide, active: active),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x4),
                  SizedBox(
                    height: textBox,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(delta * 96, 0),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            children: <Widget>[
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: AppType.display,
                              ),
                              const SizedBox(height: Space.md),
                              ConstrainedBox(
                                // سطر لا يتجاوز ما تقرؤه العين مرّة واحدة.
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: AppType.bodyLg.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// إطار الرسم: بطاقة واحدة بمقاس ثابت في كل الشرائح.
///
/// المقاس الثابت مقصود — لو تغيّر حجم البطاقة بين الشريحتين لبدا التمرير
/// كقفزة لا كانتقال.
class _ProofPanel extends StatelessWidget {
  const _ProofPanel({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = slide.colors.first;

    return Semantics(
      label: slide.proofLabel,
      child: ExcludeSemantics(
        // على الشاشات القصيرة تُصغَّر البطاقة بدل أن تفيض — الرسم يحتمل
        // التصغير، والنصّ تحته لا يحتمله.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 344,
            child: AppCard(
              radius: Radii.xl,
              borderColor: accent.withValues(alpha: 0.28),
              padding: const EdgeInsets.all(Space.xl),
              child: switch (slide.proof) {
                _Proof.sportSearch => _SportSearchProof(
                    accent: accent,
                    active: active,
                  ),
                _Proof.level => _LevelProof(accent: accent),
                _Proof.progression => _ProgressionProof(
                    colors: slide.colors,
                    active: active,
                  ),
                _Proof.tracking => _TrackingProof(
                    accent: accent,
                    active: active,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// الوعد الأول: حقل يكتب اسم رياضة بنفسه، ثم يمسحه ويكتب غيرها.
///
/// الكتابة هي الرسالة — «ما فيه قوائم محدودة» تُقرأ في ثانية حين ترى الحقل
/// يقبل رياضة بعد رياضة. مع تفعيل «تقليل الحركة» يظهر مثال واحد ثابت.
class _SportSearchProof extends StatefulWidget {
  const _SportSearchProof({required this.accent, required this.active});

  final Color accent;
  final bool active;

  @override
  State<_SportSearchProof> createState() => _SportSearchProofState();
}

class _SportSearchProofState extends State<_SportSearchProof> {
  static const List<String> _sports = <String>[
    'كرة قدم',
    'سباحة',
    'تسلّق صخور',
    'بادل',
  ];

  static const Duration _typeStep = Duration(milliseconds: 110);
  static const Duration _eraseStep = Duration(milliseconds: 55);
  static const Duration _holdFull = Duration(milliseconds: 1100);

  Timer? _timer;
  int _word = 0;
  int _chars = 0;
  bool _erasing = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule(_typeStep);
  }

  @override
  void didUpdateWidget(_SportSearchProof oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _schedule(_typeStep);
    } else if (!widget.active && oldWidget.active) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    final word = _sports[_word];

    if (!_erasing) {
      if (_chars < word.length) {
        setState(() => _chars++);
        _schedule(_chars == word.length ? _holdFull : _typeStep);
      } else {
        setState(() => _erasing = true);
        _schedule(_eraseStep);
      }
      return;
    }

    if (_chars > 0) {
      setState(() => _chars--);
      _schedule(_eraseStep);
    } else {
      setState(() {
        _erasing = false;
        _word = (_word + 1) % _sports.length;
      });
      _schedule(_typeStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final typed =
        reduceMotion ? _sports.first : _sports[_word].substring(0, _chars);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: Touch.field,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: widget.accent, width: 1.5),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.search_rounded,
                size: IconSizes.md,
                color: widget.accent,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  typed.isEmpty ? ' ' : typed,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppType.body,
                ),
              ),
              if (!reduceMotion) _Caret(color: widget.accent),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        const Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            AppTag(label: 'بادل', subtle: true),
            AppTag(label: 'يوغا', subtle: true),
            AppTag(label: 'رفع أثقال', subtle: true),
          ],
        ),
      ],
    );
  }
}

/// مؤشّر الكتابة — خطّ ثابت لا يومض.
///
/// الوميض الدائم حركة لا تحمل معنى وتبقى تعمل ما دامت الشاشة مفتوحة؛
/// الكتابة نفسها هي ما يجب أن تجذب النظر هنا.
class _Caret extends StatelessWidget {
  const _Caret({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: IconSizes.lg,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
    );
  }
}

/// الوعد الثاني: ثلاثة مستويات، الأوسط محدّد.
///
/// الاختيار لا يُقرأ من اللون وحده — المحدّد يتغيّر حدّه ووزن نصّه وتظهر
/// عليه علامة صح، تماماً كما في شاشة اختيار المستوى الحقيقية.
class _LevelProof extends StatelessWidget {
  const _LevelProof({required this.accent});

  final Color accent;

  static const List<({String label, int weight})> _levels =
      <({String label, int weight})>[
    (label: 'مبتدئ', weight: 1),
    (label: 'متوسط', weight: 2),
    (label: 'محترف', weight: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < _levels.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Space.sm),
          _LevelRow(
            label: _levels[i].label,
            weight: _levels[i].weight,
            selected: i == 1,
            accent: accent,
          ),
        ],
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.weight,
    required this.selected,
    required this.accent,
  });

  final String label;
  final int weight;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (selected)
            Icon(Icons.check_circle_rounded, size: IconSizes.md, color: accent)
          else
            const Icon(
              Icons.circle_outlined,
              size: IconSizes.md,
              color: AppColors.textTertiary,
            ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              label,
              style: selected
                  ? AppType.h4.copyWith(color: accent)
                  : AppType.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          // ثلاث شُرَط تصاعدية تُترجم «ثِقَل» المستوى بلا كلمات.
          for (var i = 1; i <= 3; i++) ...<Widget>[
            const SizedBox(width: Space.xxs),
            Container(
              width: 4,
              height: 6.0 + i * 4,
              decoration: BoxDecoration(
                color: i <= weight
                    ? (selected ? accent : AppColors.textTertiary)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// الوعد الثالث: أربعة أسابيع يرتفع حِملها.
///
/// الأعمدة ترتفع حين تصل الشريحة، بفارق زمني بينها — الارتفاع المتتابع هو
/// معنى «التدرّج» نفسه، لا زخرفة فوقه.
class _ProgressionProof extends StatelessWidget {
  const _ProgressionProof({required this.colors, required this.active});

  final List<Color> colors;
  final bool active;

  static const List<({String load, double ratio})> _weeks =
      <({String load, double ratio})>[
    (load: '3×8', ratio: 0.42),
    (load: '3×10', ratio: 0.62),
    (load: '4×10', ratio: 0.82),
    (load: '4×12', ratio: 1),
  ];

  static const double _maxBar = 120;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // بلا ارتفاع ثابت للصفّ: الأعمدة تقيس نفسها، فلا يفيض شيء حين يكبّر
    // المستخدم خطّ النظام.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var i = 0; i < _weeks.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // «3×8» صيغة لاتينية: بلا تثبيت الاتجاه تُقلب إلى «8×3».
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _weeks[i].load,
                      style: AppType.number(
                        size: 12,
                        weight: AppType.semiBold,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : Motion.progress + Motion.fast * i,
                    curve: Curves.easeOutCubic,
                    height: (active || reduceMotion)
                        ? _maxBar * _weeks[i].ratio
                        : Space.sm,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'أسبوع ${i + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// الوعد الرابع: حلقة الإنجاز مع رقمين يفسّرانها.
class _TrackingProof extends StatelessWidget {
  const _TrackingProof({required this.accent, required this.active});

  final Color accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ProgressRing(
          value: active ? 0.68 : 0,
          caption: 'إنجازك',
          size: 124,
          color: accent,
        ),
        const SizedBox(height: Space.lg),
        // Wrap لا Row: الوحدتان تنزلان سطرين على الشاشات الضيقة بدل أن
        // تفيضا خارج البطاقة.
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            AppMetricPill(value: '12', unit: 'جلسة'),
            AppMetricPill(value: '5', unit: 'أيام متتالية'),
          ],
        ),
      ],
    );
  }
}

/// مؤشّر التقدّم: أربع قطع تمتلئ مع التمرير، وعدّاد «2 / 4» بجانبها.
///
/// النقاط الدائرية تقول «أين أنا» فقط. القطع تقول «كم بقي» أيضاً، وهي
/// أهمّ سؤال في شاشة تعريف. وكل قطعة هدف لمس كامل الارتفاع للانتقال
/// المباشر — بما فيها الرجوع للخلف.
class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.count,
    required this.offset,
    required this.index,
    required this.color,
    required this.onTap,
  });

  final int count;
  final double offset;
  final int index;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الشريحة ${index + 1} من $count',
      child: Row(
        children: <Widget>[
          for (var i = 0; i < count; i++)
            Expanded(
              child: Semantics(
                button: true,
                label: 'الانتقال إلى الشريحة ${i + 1}',
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: SizedBox(
                    // ارتفاع اللمس 48 والخطّ 5 — الهدف أكبر من الرسم دائماً.
                    height: Touch.min,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xs,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            // القطعة تمتلئ مع الإصبع لا بعد وصوله.
                            value: (offset - i + 1).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppColors.surfaceHigh,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: Space.md),
          // العدّاد لاتيني: بلا تثبيت الاتجاه يقلبه محرّك النصّ العربي
          // فيُقرأ «4 / 1» بدل «1 / 4».
          ExcludeSemantics(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${index + 1} / $count',
                style: AppType.number(
                  size: 13,
                  weight: AppType.semiBold,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
