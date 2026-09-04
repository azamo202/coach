/// تحقق من مدخلات النماذج، برسائل عربية.
class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$",
  );

  static String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'اكتب اسمك';
    if (text.length < 2) return 'الاسم قصير جداً';
    if (text.length > 40) return 'الاسم طويل جداً';
    return null;
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'اكتب بريدك الإلكتروني';
    if (!_emailPattern.hasMatch(text)) return 'صيغة البريد غير صحيحة';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'اكتب كلمة المرور';
    if (text.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
    if (!RegExp('[A-Za-z]').hasMatch(text) || !RegExp('[0-9]').hasMatch(text)) {
      return 'استخدم حروفاً وأرقاماً معاً';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'أعد كتابة كلمة المرور';
    if (value != original) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'اكتب كلمة المرور';
    return null;
  }

  static String? sport(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'اكتب اسم الرياضة';
    if (text.length < 2) return 'اسم الرياضة قصير جداً';
    if (text.length > 40) return 'اسم الرياضة طويل جداً';
    return null;
  }

  /// حقول رقمية اختيارية (العمر، الوزن، الطول).
  static String? optionalNumber(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return 'اكتب رقماً صحيحاً';
    if (parsed < min || parsed > max) {
      return '$label يجب أن يكون بين ${min.toStringAsFixed(0)} و ${max.toStringAsFixed(0)}';
    }
    return null;
  }
}
