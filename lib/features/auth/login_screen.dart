import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../routing/app_router.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/subscription_controller.dart';
import '../shell/main_shell.dart';
import 'forgot_password_screen.dart';
import 'level_setup_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_title.dart';

/// تسجيل الدخول.
///
/// حقلان وزرّ واحد. لا أزرار دخول اجتماعي ولا بصمة هنا — التطبيق لا يدعمها
/// فعلاً، وزرّ لا يفعل شيئاً أسوأ من غياب الزرّ.
///
/// الشاشة ثلاث طبقات واضحة بدل قائمة عناصر عائمة فوق الخلفية:
/// 1. **العنوان** — أول ما تقع عليه العين. لا شعار فوقه: العلامة عُرضت في
///    الإقلاع وشاشة التعريف، وتكرارها هنا يدفع الحقول لأسفل بلا مقابل.
/// 2. **لوحة النموذج** — بطاقة واحدة تجمع الحقلين والخطأ والزرّ، فتعرف العين
///    أين تبدأ المهمة وأين تنتهي.
/// 3. **تذييل الحساب الجديد** — خارج اللوحة لأنه مسار آخر لا خطوة تالية.
///
/// المجموعة كلها متمركزة رأسياً: ما دام المحتوى أقصر من الشاشة يبقى في
/// منتصفها، وإن طال بدأ من أعلاها وانزلق.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorOnType);
    _passwordController.addListener(_clearErrorOnType);
  }

  void _clearErrorOnType() {
    final auth = context.read<AuthController>();
    if (auth.error != null) {
      auth.clearError();
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearErrorOnType);
    _passwordController.removeListener(_clearErrorOnType);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.lightImpact();
      return;
    }

    final auth = context.read<AuthController>();
    final library = context.read<LibraryController>();
    final subscription = context.read<SubscriptionController>();
    final navigator = Navigator.of(context);

    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted || !ok) return;

    final user = auth.user;
    if (user == null) return;

    await library.loadFor(user.id);
    await subscription.bindAccount(
      userId: user.id,
      appAccountToken: user.appAccountToken,
    );
    await navigator.pushAndRemoveUntil(
      fadeThroughRoute<void>(
        user.hasCompletedOnboarding
            ? const MainShell()
            : const LevelSetupScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // على الشاشات العريضة يبقى النموذج بعرض مقروء بدل أن يتمدّد.
              constraints: const BoxConstraints(maxWidth: Space.formWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.screenInset,
                  Space.xl,
                  Space.screenInset,
                  Space.xxl,
                ),
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  const RevealIn(
                    child: AuthTitle(
                      title: 'أهلاً بعودتك',
                      subtitle: 'سجّل دخولك لتكمل برنامجك',
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
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hint: 'name@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              isRequired: true,
                              autofillHints: const <String>[
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
                              textInputAction: TextInputAction.done,
                              isRequired: true,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              onSubmitted: (_) => _submit(),
                              validator: Validators.loginPassword,
                            ),
                            const SizedBox(height: Space.xs),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => context.pushPage(
                                  const ForgotPasswordScreen(),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.sm,
                                  ),
                                ),
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                            ),
                            // الخطأ يظهر بتمدّد قصير: يلاحظه المستخدم دون أن
                            // يقفز الزرّ من تحت إصبعه.
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
                              label: 'تسجيل الدخول',
                              isLoading: auth.isBusy,
                              onPressed: auth.isBusy ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  RevealIn(
                    step: 2,
                    child: _SignUpPrompt(
                      onTap: () {
                        auth.clearError();
                        context.replaceWith(const SignUpScreen());
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

/// تذييل «ليس لديك حساب؟» — سطر واحد يلتفّ بأمان على الشاشات الضيقة.
class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('ليس لديك حساب؟', style: AppType.bodySm),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          ),
          child: const Text('أنشئ حساباً'),
        ),
      ],
    );
  }
}
