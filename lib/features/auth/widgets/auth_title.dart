import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// عنوان شاشة مصادقة: سطر رئيسي وسطر شارح تحته، متمركزان.
///
/// هو أول ما تقع عليه العين في شاشات المسار الثلاث — لا شعار فوقه: العلامة
/// عُرضت في شاشة التعريف والإقلاع، وتكرارها فوق كل نموذج يدفع الحقول لأسفل
/// بلا مقابل.
///
/// موجود هنا لا داخل كل شاشة حتى يبقى المقاس والمسافة بين السطرين واحداً في
/// المسار كله.
class AuthTitle extends StatelessWidget {
  const AuthTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(title, textAlign: TextAlign.center, style: AppType.h1),
        const SizedBox(height: Space.sm),
        Text(subtitle, textAlign: TextAlign.center, style: AppType.bodySm),
      ],
    );
  }
}
