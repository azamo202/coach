import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import 'level_setup_screen.dart';
import 'login_screen.dart';
import 'widgets/auth_title.dart';

/// إنشاء حساب جديد.
///
/// نفس بنية شاشة الدخول بالضبط — عنوان، ثم لوحة واحدة تضمّ النموذج، ثم
/// تذييل المسار الآخر — لأن الشاشتين خطوتان في مسار واحد، والاختلاف بينهما
/// يجب أن يكون في المحتوى لا في الشكل.
///
/// ما يخصّ هذه الشاشة وحدها:
/// - **مؤشّر قوة كلمة المرور** يظهر بتمدّد قصير عند أول حرف، ولا يعتمد على
///   اللون وحده: معه تسمية نصّية دائماً.
/// - **الموافقة على الشروط** قبل الزرّ مباشرة، لأنها شرط الضغط عليه.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onSecretChanged);
    _confirmController.addListener(_onSecretChanged);
  }

  void _onSecretChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onSecretChanged);
    _confirmController.removeListener(_onSecretChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;

    if (!_acceptedTerms) {
      setState(() => _showTermsError = true);
      HapticFeedback.lightImpact();
    }
    if (!formOk || !_acceptedTerms) {
      if (!formOk) HapticFeedback.lightImpact();
      return;
    }

    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final navigator = Navigator.of(context);

    final ok = await auth.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted || !ok) return;

    final user = auth.user;
    if (user != null) {
      await library.loadFor(user.id);
      await subscription.bindAccount(
        userId: user.id,
        appAccountToken: user.appAccountToken,
      );
    }

    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(const LevelSetupScreen()),
      (route) => false,
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.formWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.screenInset,
                  Space.sm,
                  Space.screenInset,
                  Space.xxl,
                ),
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  // زرّ الرجوع في مساره الطبيعي أعلى الشاشة، لا معلّقاً فوق
                  // المحتوى في صندوق خاص به. وحين لا يوجد ما نرجع إليه لا
                  // يُحجز مكانه فارغاً.
                  if (canPop)
                    SizedBox(
                      height: Touch.min,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'رجوع',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: Space.md),
                  const RevealIn(
                    child: AuthTitle(
                      title: 'أنشئ حسابك',
                      subtitle:
                          'خطوة واحدة، ويبدأ مدرّبك الذكي في بناء أول برنامج لك',
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  RevealIn(
                    step: 1,
                    child: AppCard(
                      radius: Radii.xl,
                      padding: const EdgeInsets.all(Space.xxl),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AppTextField(
                              controller: _nameController,
                              label: 'الاسم الكامل',
                              hint: 'مثال: محمد عبدالله',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              isRequired: true,
                              autofillHints: const <String>[AutofillHints.name],
                              onSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                              validator: Validators.name,
                            ),
                            const SizedBox(height: Space.xl),
                            AppTextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              label: 'البريد الإلكتروني',
                              hint: 'name@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              isRequired: true,
                              autofillHints: const <String>[
                                AutofillHints.newUsername,
                                AutofillHints.email,
                              ],
                              onSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                              validator: Validators.email,
                            ),
                            const SizedBox(height: Space.xl),
                            AppTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              label: 'كلمة المرور',
                              icon: Icons.lock_outline_rounded,
                              obscure: true,
                              textInputAction: TextInputAction.next,
                              isRequired: true,
                              autofillHints: const <String>[
                                AutofillHints.newPassword,
                              ],
                              onSubmitted: (_) =>
                                  _confirmFocusNode.requestFocus(),
                              validator: Validators.password,
                            ),
                            // المؤشّر يتمدّد عند أول حرف بدل أن يقفز فيدفع
                            // بقية الحقول لأسفل دفعة واحدة.
                            AnimatedSize(
                              duration: Motion.base,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _passwordController.text.isEmpty
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding:
                                          const EdgeInsets.only(top: Space.md),
                                      child: _PasswordStrengthMeter(
                                        password: _passwordController.text,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: Space.xl),
                            AppTextField(
                              controller: _confirmController,
                              focusNode: _confirmFocusNode,
                              label: 'تأكيد كلمة المرور',
                              icon: Icons.lock_reset_rounded,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              isRequired: true,
                              onSubmitted: (_) => _submit(),
                              validator: (value) => Validators.confirmPassword(
                                value,
                                _passwordController.text,
                              ),
                            ),
                            AnimatedSize(
                              duration: Motion.base,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _confirmController.text.isEmpty ||
                                      _passwordController.text.isEmpty
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding:
                                          const EdgeInsets.only(top: Space.sm),
                                      child: _passwordController.text ==
                                              _confirmController.text
                                          ? const _PasswordMatchBadge()
                                          : Row(
                                              children: <Widget>[
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 14,
                                                  color: AppColors.coral,
                                                ),
                                                const SizedBox(width: Space.xs),
                                                Expanded(
                                                  child: Text(
                                                    'كلمتا المرور غير متطابقتين',
                                                    style: AppType.caption
                                                        .copyWith(
                                                      color: AppColors.coral,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                            ),
                            const SizedBox(height: Space.xl),
                            _TermsCheckboxTile(
                              accepted: _acceptedTerms,
                              showError: _showTermsError && !_acceptedTerms,
                              onChanged: (v) => setState(() {
                                _acceptedTerms = v;
                                if (v) _showTermsError = false;
                              }),
                              onOpenTerms: () => _openUrl(AppConfig.termsUrl),
                              onOpenPrivacy: () =>
                                  _openUrl(AppConfig.privacyPolicyUrl),
                            ),
                            AnimatedSize(
                              duration: Motion.base,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: auth.error == null
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding:
                                          const EdgeInsets.only(top: Space.md),
                                      child: AppNotice(
                                        message: auth.error!,
                                        onDismiss: auth.clearError,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: Space.xl),
                            AppButton.primary(
                              label: 'إنشاء الحساب',
                              isLoading: auth.isBusy,
                              onPressed: auth.isBusy ? null : _submit,
                            ),
                            const SizedBox(height: Space.md),
                            const _SecurityNote(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  RevealIn(
                    step: 2,
                    child: _LoginPrompt(
                      onTap: () {
                        auth.clearError();
                        context.replaceWith(const LoginScreen());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// سطر الطمأنة أسفل الزرّ — مكانه هنا لأنه يخصّ إرسال البيانات نفسه.
class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const ExcludeSemantics(
          child: Icon(
            Icons.lock_outline_rounded,
            size: IconSizes.sm,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            'بياناتك مشفّرة ولا تُشارك مع أحد',
            style: AppType.caption,
          ),
        ),
      ],
    );
  }
}

/// تذييل «لديك حساب بالفعل؟» — نفس تذييل شاشة الدخول بالاتجاه المعاكس.
class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('لديك حساب بالفعل؟', style: AppType.bodySm),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          ),
          child: const Text('سجّل دخولك'),
        ),
      ],
    );
  }
}

/// مؤشّر قوة كلمة المرور.
///
/// أربع قطع + تسمية نصّية. التسمية ليست زينة: القوة لا يجوز أن تُقرأ من
/// اللون وحده — من لا يميّز الأحمر من الأخضر يقرأ «ضعيفة» و«قوية».
class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  int get _score {
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    }
    if (password.length >= 10) score++;
    if (RegExp(r'[!@#\$&*~_.,\-]').hasMatch(password)) score++;
    return score;
  }

  Color get _color => switch (_score) {
        <= 1 => AppColors.danger,
        2 => AppColors.coral,
        3 => AppColors.mint,
        _ => AppColors.mintLight,
      };

  String get _label => switch (_score) {
        <= 1 => 'ضعيفة',
        2 => 'متوسطة',
        3 => 'جيدة',
        _ => 'قوية جداً',
      };

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final color = _color;

    return Semantics(
      label: 'قوة كلمة المرور: $_label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (var i = 0; i < 4; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: Space.xs),
                  Expanded(
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      curve: Curves.easeOut,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < score ? color : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: Space.md),
                Text(
                  _label,
                  style: AppType.caption.copyWith(
                    color: AppColors.asText(color),
                    fontWeight: AppType.semiBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              'ثمانية أحرف على الأقل، تتضمّن حروفاً وأرقاماً',
              style: AppType.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة تأكيد تطابق كلمتي المرور — تظهر بالأخضر فقط عند التطابق لتجنب تكرار رسالة الخطأ.
class _PasswordMatchBadge extends StatelessWidget {
  const _PasswordMatchBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const ExcludeSemantics(
          child: Icon(
            Icons.check_circle_rounded,
            size: IconSizes.sm,
            color: AppColors.mint,
          ),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            'كلمتا المرور متطابقتان',
            style: AppType.caption.copyWith(
              color: AppColors.asText(AppColors.mint),
              fontWeight: AppType.medium,
            ),
          ),
        ),
      ],
    );
  }
}

/// الموافقة على الشروط وسياسة الخصوصية.
///
/// الصندوق كله هدف لمس واحد: الضغط على أي موضع فيه يبدّل الاختيار، عدا
/// الرابطين. والخطأ يظهر تحته مربوطاً به، لا في أعلى الشاشة.
class _TermsCheckboxTile extends StatelessWidget {
  const _TermsCheckboxTile({
    required this.accepted,
    required this.showError,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final bool showError;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppType.bodySm.copyWith(
      color: AppColors.textSecondary,
    );
    final linkStyle = bodyStyle.copyWith(
      color: AppColors.mint,
      fontWeight: AppType.semiBold,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.mint.withValues(alpha: 0.5),
    );

    final borderColor = showError
        ? AppColors.danger
        : (accepted ? AppColors.mint : AppColors.borderSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          checked: accepted,
          label: 'الموافقة على شروط الاستخدام وسياسة الخصوصية',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(!accepted);
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: showError
                      ? AppColors.danger.withValues(alpha: 0.08)
                      : (accepted
                          ? AppColors.mint.withValues(alpha: 0.08)
                          : AppColors.surfaceElevated),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: borderColor.withValues(alpha: accepted ? 0.5 : 1),
                    width: accepted || showError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    ExcludeSemantics(
                      child: SizedBox(
                        width: IconSizes.lg,
                        height: IconSizes.lg,
                        child: Checkbox(
                          value: accepted,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            onChanged(v ?? false);
                          },
                          isError: showError,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text('أوافق على ', style: bodyStyle),
                          GestureDetector(
                            onTap: onOpenTerms,
                            child: Text('شروط الاستخدام', style: linkStyle),
                          ),
                          Text(' و', style: bodyStyle),
                          GestureDetector(
                            onTap: onOpenPrivacy,
                            child: Text('سياسة الخصوصية', style: linkStyle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showError
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    'وافق على الشروط لتتمكّن من إنشاء الحساب.',
                    style: AppType.caption.copyWith(color: AppColors.danger),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
