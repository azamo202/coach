import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/auth_controller.dart';
import 'widgets/auth_title.dart';

/// استعادة كلمة المرور — خطوة واحدة ثم تأكيد.
///
/// نفس بنية شاشتَي الدخول والتسجيل: عنوان ثم لوحة واحدة. الحالتان
/// (النموذج ثم التأكيد) تتبادلان داخل اللوحة نفسها بتلاشٍ متقاطع، فلا يبدو
/// النجاح شاشة جديدة بل نتيجة ما فعله المستخدم للتوّ.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.lightImpact();
      return;
    }

    final ok = await context.read<AuthController>().requestPasswordReset(
          _emailController.text,
        );
    if (!mounted) return;
    if (ok) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

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
                  ),
                  RevealIn(
                    child: AuthTitle(
                      title: _sent ? 'تحقّق من بريدك' : 'نسيت كلمة المرور؟',
                      subtitle: _sent
                          ? 'أرسلنا رابط إعادة التعيين'
                          : 'اكتب بريدك ونرسل لك رابط إعادة التعيين',
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  RevealIn(
                    step: 1,
                    child: AppCard(
                      radius: Radii.xl,
                      padding: const EdgeInsets.all(Space.xxl),
                      child: AnimatedSize(
                        duration: Motion.base,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: Motion.base,
                          child: _sent
                              ? _SentState(
                                  email: _emailController.text.trim(),
                                  onBack: () =>
                                      Navigator.of(context).maybePop(),
                                )
                              : _buildForm(auth),
                        ),
                      ),
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

  Widget _buildForm(AuthController auth) {
    return Form(
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
            textInputAction: TextInputAction.done,
            isRequired: true,
            autofillHints: const <String>[AutofillHints.email],
            onSubmitted: (_) => _submit(),
            validator: Validators.email,
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: auth.error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: AppNotice(
                      message: auth.error!,
                      onDismiss: auth.clearError,
                    ),
                  ),
          ),
          const SizedBox(height: Space.xl),
          AppButton.primary(
            label: 'إرسال الرابط',
            isLoading: auth.isBusy,
            onPressed: auth.isBusy ? null : _submit,
          ),
          const SizedBox(height: Space.md),
          Text(
            'واجهت مشكلة؟ راسلنا على ${AppConfig.supportEmail}',
            textAlign: TextAlign.center,
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

/// حالة «أُرسل الرابط» داخل اللوحة نفسها.
class _SentState extends StatelessWidget {
  const _SentState({required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: Touch.min + Space.xl,
            height: Touch.min + Space.xl,
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
            ),
            child: const ExcludeSemantics(
              child: Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.mint,
                size: IconSizes.xl,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(
          'راجع بريد $email واتبع الرابط لإعادة تعيين كلمة المرور. قد يصل '
          'الرابط إلى مجلّد الرسائل غير المرغوبة.',
          textAlign: TextAlign.center,
          style: AppType.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        AppButton.primary(label: 'رجوع لتسجيل الدخول', onPressed: onBack),
      ],
    );
  }
}
