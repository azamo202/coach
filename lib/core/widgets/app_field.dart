import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// حقل الإدخال الموحّد.
///
/// قواعد ثابتة في كل حقل بالتطبيق:
/// - **عنوان ظاهر دائماً.** النص التلميحي يختفي بمجرد الكتابة، فلا يصلح عنواناً.
/// - **نص مساعد ثابت** تحت الحقل حين تحتاج القاعدة شرحاً، لا داخل التلميح.
/// - **التحقّق عند الخروج من الحقل** لا عند كل حرف — التصحيح أثناء الكتابة
///   يعاقب المستخدم قبل أن ينهي جملته.
/// - **الخطأ تحت الحقل نفسه**، مربوطاً به للقارئ الصوتي.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.isRequired = false,
    this.maxLines = 1,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;

  /// العنوان الظاهر فوق الحقل.
  final String label;

  /// مثال قصير على الشكل المتوقّع — لا يحمل معلومة لا توجد في مكان آخر.
  final String? hint;

  /// شرح ثابت يبقى ظاهراً بعد الكتابة.
  final String? helper;

  final IconData? icon;

  /// يفعّل حقل كلمة المرور مع زرّ إظهار/إخفاء جاهز.
  final bool obscure;

  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  /// حقل يُقرأ ولا يُعدَّل — مختلف بصرياً ودلالياً عن المعطّل.
  final bool readOnly;

  final bool isRequired;
  final int maxLines;
  final List<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscure;
    final interactive = widget.enabled && !widget.readOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text.rich(
            TextSpan(
              text: widget.label,
              children: <InlineSpan>[
                if (widget.isRequired)
                  TextSpan(
                    text: ' *',
                    style: AppType.label.copyWith(color: AppColors.mint),
                  ),
              ],
            ),
            style: AppType.label.copyWith(
              color: interactive
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
            ),
          ),
        ),
        Focus(
          // التحقّق يعمل بعد أن يترك المستخدم الحقل، لا أثناء كتابته فيه.
          onFocusChange: (hasFocus) {
            if (!hasFocus && !_touched) setState(() => _touched = true);
          },
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: isPassword && _hidden,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: isPassword ? 1 : widget.maxLines,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            cursorColor: AppColors.mint,
            style: AppType.body.copyWith(
              color: widget.readOnly
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
            autovalidateMode: _touched
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: widget.validator,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              fillColor: widget.readOnly
                  ? AppColors.spruceDeep
                  : AppColors.surfaceElevated,
              prefixIcon: widget.icon == null
                  ? null
                  : ExcludeSemantics(
                      child: Icon(widget.icon, size: IconSizes.md),
                    ),
              suffixIcon: isPassword
                  ? _RevealButton(
                      hidden: _hidden,
                      onToggle: () => setState(() => _hidden = !_hidden),
                    )
                  : widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.hidden, required this.onToggle});

  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      tooltip: hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: IconSizes.md,
      ),
    );
  }
}
