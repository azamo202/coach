import 'package:coachmint/core/config/app_config.dart';
import 'package:coachmint/data/models/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات نموذج الاشتراك.
///
/// النموذج هو ما يترجم ردّ الخادم إلى ما تعرضه الواجهة وتمنعه. خطأ صامت
/// هنا يعني إما بابًا مدفوعاً مفتوحاً، أو مشتركاً محجوباً عمّا دفع مقابله.
void main() {
  group('كتالوج الخطط', () {
    test('معرّفات المنتجات تطابق ما في الإعدادات', () {
      expect(
        SubscriptionPlan.singleMonthly.productId,
        AppConfig.productSingleMonthly,
      );
      expect(
        SubscriptionPlan.trioMonthly.productId,
        AppConfig.productTrioMonthly,
      );
      expect(
        SubscriptionPlan.unlimitedYearly.productId,
        AppConfig.productUnlimitedYearly,
      );
    });

    test('كل منتج يُعرَف من معرّفه', () {
      for (final plan in SubscriptionPlan.paid) {
        expect(SubscriptionPlan.fromProductId(plan.productId), plan);
      }
      expect(SubscriptionPlan.fromProductId('com.other.app.pro'), isNull);
    });

    test('معرّف مجهول يسقط إلى الخطة المجانية لا إلى خطة مدفوعة', () {
      expect(SubscriptionPlan.fromId('enterprise_lifetime'),
          SubscriptionPlan.free,);
      expect(SubscriptionPlan.fromId(null), SubscriptionPlan.free);
    });

    test('الحصص تطابق ما يعلنه التسعير', () {
      expect(SubscriptionPlan.singleMonthly.programSlots, 1);
      expect(SubscriptionPlan.trioMonthly.programSlots, 3);
      expect(SubscriptionPlan.unlimitedYearly.isUnlimited, isTrue);
    });

    test('حالة «بلا اشتراك» لا تمنح أي حصة', () {
      // التطبيق مقفول بالكامل خلف الاشتراك — لا تجربة مجانية.
      expect(SubscriptionPlan.free.programSlots, 0);
      expect(SubscriptionPlan.free.coachAdvice, isFalse);
      expect(SubscriptionPlan.free.productId, isNull);
    });

    test('وصف الحصة بصيغة عربية سليمة العدد', () {
      expect(SubscriptionPlan.singleMonthly.slotsLabel, 'برنامج واحد');
      expect(SubscriptionPlan.trioMonthly.slotsLabel, '3 برامج');
      expect(SubscriptionPlan.unlimitedYearly.slotsLabel, 'برامج بلا حدود');
    });

    test('الترتيب تصاعدي ويطابق ترتيب الخادم', () {
      expect(SubscriptionPlan.free.rank, 0);
      expect(SubscriptionPlan.singleMonthly.rank, 1);
      expect(SubscriptionPlan.trioMonthly.rank, 2);
      expect(SubscriptionPlan.unlimitedYearly.rank, 3);
    });
  });

  group('الحالة الافتراضية', () {
    test('قبل وصول رد الخادم لا يُسمح بالتوليد', () {
      // فتح الباب ثم إغلاقه أسوأ من إبقائه مغلقاً حتى يصل الجواب.
      expect(Entitlement.unknown.canCreateProgram, isFalse);
      expect(Entitlement.unknown.isSubscribed, isFalse);
      expect(Entitlement.unknown.plan, SubscriptionPlan.free);
    });
  });

  group('قراءة رد الخادم', () {
    test('يقرأ اشتراكاً فعّالاً بكل حقوله', () {
      final entitlement = Entitlement.fromJson(<String, dynamic>{
        'planId': 'trio_monthly',
        'isSubscribed': true,
        'activePrograms': 2,
        'remainingSlots': 1,
        'canCreateProgram': true,
        'coachAdvice': true,
        'expiresAt': '2026-10-08T12:00:00.000Z',
        'autoRenew': true,
        'inGracePeriod': false,
        'isTrial': false,
        'billingIssue': false,
      });

      expect(entitlement.plan, SubscriptionPlan.trioMonthly);
      expect(entitlement.isSubscribed, isTrue);
      expect(entitlement.remainingSlots, 1);
      expect(entitlement.autoRenew, isTrue);
      expect(entitlement.expiresAt?.year, 2026);
      expect(entitlement.blockReason, isNull);
    });

    test('رد ناقص لا ينهار ولا يمنح صلاحية', () {
      final entitlement = Entitlement.fromJson(<String, dynamic>{});
      expect(entitlement.isSubscribed, isFalse);
      expect(entitlement.canCreateProgram, isFalse);
      expect(entitlement.plan, SubscriptionPlan.free);
    });

    test('يقرأ الخطة المفتوحة بحصص غير محدودة', () {
      final entitlement = Entitlement.fromJson(<String, dynamic>{
        'planId': 'unlimited_yearly',
        'isSubscribed': true,
        'canCreateProgram': true,
        'remainingSlots': null,
      });
      expect(entitlement.isUnlimited, isTrue);
      expect(entitlement.remainingSlots, isNull);
    });
  });

  group('سبب المنع المعروض للمستخدم', () {
    /// الحالة الفعلية في الإنتاج: الخادم لا يمنح أي تجربة مجانية.
    Entitlement lockedOut() => Entitlement.fromJson(<String, dynamic>{
          'planId': 'free',
          'isSubscribed': false,
          'canCreateProgram': false,
          'programSlots': 0,
          'freeGenerationsUsed': 0,
          'freeGenerationsLimit': 0,
        });

    test('حساب جديد يُدعى للاشتراك لا يُلام على استهلاك تجربة', () {
      final entitlement = lockedOut();

      expect(entitlement.hasFreeTier, isFalse);
      expect(entitlement.freeTrialUsedUp, isFalse);
      expect(entitlement.blockReason, contains('الاشتراك مطلوب'));
      // الخلط بين الرسالتين يترك المستخدم أمام إجراء لا يحلّ مشكلته.
      expect(entitlement.blockReason, isNot(contains('استهلكت')));
      expect(entitlement.blockReason, isNot(contains('احذف')));
    });

    test('التجربة المجانية يقرّرها الخادم لا التطبيق', () {
      // لو أعاد الخادم حداً مجانياً لاحقاً، يتبدّل السلوك بلا إصدار جديد.
      final withTrial = Entitlement.fromJson(<String, dynamic>{
        'planId': 'free',
        'isSubscribed': false,
        'canCreateProgram': false,
        'freeGenerationsUsed': 1,
        'freeGenerationsLimit': 1,
      });

      expect(withTrial.hasFreeTier, isTrue);
      expect(withTrial.freeTrialUsedUp, isTrue);
      expect(withTrial.blockReason, contains('استهلكت برنامجك المجاني'));
    });

    test('مشترك امتلأت حصصه يُوجَّه للحذف أو الترقية', () {
      final entitlement = Entitlement.fromJson(<String, dynamic>{
        'planId': 'single_monthly',
        'isSubscribed': true,
        'canCreateProgram': false,
        'activePrograms': 1,
        'remainingSlots': 0,
      });

      final reason = entitlement.blockReason!;
      expect(reason, contains('برنامج واحد'));
      expect(reason, contains('احذف'));
    });

    test('من يستطيع التوليد لا يُعرض له سبب منع', () {
      final entitlement = Entitlement.fromJson(<String, dynamic>{
        'planId': 'single_monthly',
        'isSubscribed': true,
        'canCreateProgram': true,
      });
      expect(entitlement.blockReason, isNull);
    });
  });
}
