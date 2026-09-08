import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routing/app_router.dart';
import '../../state/subscription_controller.dart';
import '../sports/new_program_screen.dart';
import 'paywall_screen.dart';

/// بوابة الاشتراك أمام إنشاء البرامج.
///
/// التطبيق مقفول خلف الاشتراك، فلكل طريق يؤدي إلى إنشاء برنامج بوابة
/// واحدة هنا بدل نسخة في كل شاشة. الفائدة ليست اختصاراً فحسب: البوابة
/// الموزّعة تُنسى في مدخل، فيملأ المستخدم نموذجاً كاملاً ثم يُقال له إنه
/// غير مشترك.
///
/// هذه بوابة **تجربة استخدام** لا بوابة أمان. الحارس الحقيقي على الخادم:
/// `POST /ai/program` يرفض بـ402 مهما فعل التطبيق.

/// يتأكد من وجود حصة، ويعرض صفحة الاشتراك إن لم توجد.
///
/// يُرجع `true` إذا جاز المتابعة.
Future<bool> ensureProgramSlot(BuildContext context) async {
  final subscription = context.read<SubscriptionController>();

  // ما نعرفه يكفي للسماح: تأخير كل فتح بنداء شبكة يجعل التطبيق يبدو بطيئاً،
  // والخادم يبقى الحكَم النهائي لحظة التوليد.
  if (subscription.canCreateProgram) return true;

  // ممنوع بحسب ما نعرف — نسأل الخادم قبل أن نعترض طريقه، فقد يكون اشترك
  // للتوّ من جهاز آخر أو تجدّد اشتراكه.
  await subscription.refresh();
  if (!context.mounted) return false;
  if (subscription.canCreateProgram) return true;

  await context.pushPage<void>(
    PaywallScreen(reason: subscription.entitlement.blockReason),
  );
  if (!context.mounted) return false;

  // بعد الرجوع نعيد الفحص ولا نفترض: قد يكون اشترك، وقد يكون أغلقها.
  await subscription.refresh();
  return context.mounted && subscription.canCreateProgram;
}

/// يفتح شاشة إنشاء برنامج بعد اجتياز البوابة.
///
/// هذا هو المدخل الوحيد المعتمد لإنشاء البرامج في كل التطبيق.
Future<void> openNewProgram(BuildContext context, {String? presetSport}) async {
  if (!await ensureProgramSlot(context)) return;
  if (!context.mounted) return;
  await context.pushPage<void>(NewProgramScreen(presetSport: presetSport));
}
