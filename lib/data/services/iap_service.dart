import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';

/// غلاف رقيق حول StoreKit.
///
/// مسؤوليته الوحيدة هي التحدّث إلى المتجر: جلب المنتجات، بدء الشراء،
/// الاستعادة، وتمرير ما يصل من عمليات. **لا يقرّر شيئاً عن الصلاحية** —
/// ذلك القرار للخادم وحده، و[SubscriptionController] هو من ينفّذ السياسة.
///
/// الفصل مقصود: خلط «ماذا قال المتجر» بـ«ماذا يستحق المستخدم» هو الخطأ
/// الذي يجعل تجاوز الدفع ممكناً بتعديل التطبيق.
class IapService {
  IapService({InAppPurchase? plugin}) : _override = plugin;

  final InAppPurchase? _override;

  /// المكوّن الإضافي يُطلب عند الحاجة لا عند البناء.
  ///
  /// `InAppPurchase.instance` يتطلّب منصّة مسجَّلة، والوصول إليه على
  /// منصّة غير مدعومة (أو داخل اختبار) يفشل. التأجيل يجعل بناء الخدمة
  /// آمناً في كل مكان، ويترك الفشل لحظة الاستخدام الفعلي وحدها.
  InAppPurchase get _iap => _override ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<PurchaseDetails> _purchases =
      StreamController<PurchaseDetails>.broadcast();

  bool _available = false;
  bool _started = false;
  List<ProductDetails> _products = const <ProductDetails>[];

  /// هل المتجر متاح على هذا الجهاز؟ (يكون false على المحاكي أو مع قيود الشراء)
  bool get isAvailable => _available;

  /// المنتجات كما أعادها المتجر — بأسعار المستخدم وعملته.
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// كل عملية تصل من StoreKit: شراء جديد، استعادة، أو فشل.
  Stream<PurchaseDetails> get purchaseUpdates => _purchases.stream;

  /// المنصّة الوحيدة المدعومة حالياً هي iOS.
  static bool get isSupportedPlatform => !kIsWeb && Platform.isIOS;

  ProductDetails? productFor(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  /// يبدأ الإصغاء لعمليات المتجر.
  ///
  /// يجب أن يُستدعى عند إقلاع التطبيق لا عند فتح صفحة الاشتراك: StoreKit
  /// يعيد إرسال أي عملية لم تُنهَ بعد فور بدء الإصغاء، وتلك العمليات هي
  /// بالضبط ما يضيع حين يُدفع المستخدم ثم يُغلق التطبيق قبل التحقق.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!isSupportedPlatform) {
      _available = false;
      return;
    }

    // الإصغاء أولاً: بدؤه هو ما يوقظ StoreKit ليسلّم المعلّق.
    _subscription = _iap.purchaseStream.listen(
      (batch) {
        for (final details in batch) {
          _purchases.add(details);
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('StoreKit stream error: $error');
      },
    );

    try {
      _available = await _iap.isAvailable();
    } catch (error) {
      debugPrint('StoreKit availability check failed: $error');
      _available = false;
    }
  }

  /// يجلب تفاصيل المنتجات الثلاثة من App Store.
  ///
  /// يرمي [AppException] برسالة عربية واضحة عند فشل الجلب، لأن صفحة
  /// اشتراك بلا أسعار لا يجوز أن تُعرض وكأنها تعمل.
  Future<List<ProductDetails>> loadProducts() async {
    if (!isSupportedPlatform) {
      throw const AppException(
        'الاشتراك متاح حالياً على أجهزة iPhone وiPad فقط.',
        code: 'iap_unsupported_platform',
        canRetry: false,
      );
    }
    if (!_available) {
      throw const AppException(
        'متجر التطبيقات غير متاح على هذا الجهاز. تأكد من تسجيل الدخول بحساب '
        'Apple ومن أن الشراء غير مقيّد في الإعدادات.',
        code: 'iap_unavailable',
        canRetry: false,
      );
    }

    final ProductDetailsResponse response;
    try {
      response = await _iap
          .queryProductDetails(AppConfig.subscriptionProductIds)
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      debugPrint('queryProductDetails failed: $error');
      throw AppException.network;
    }

    if (response.error != null) {
      debugPrint('StoreKit product error: ${response.error}');
      throw const AppException(
        'ما قدرنا نجيب باقات الاشتراك من المتجر. حاول مرة ثانية.',
        code: 'iap_query_failed',
      );
    }

    // معرّف مفقود يعني خطأ إعداد في App Store Connect، لا خطأ مستخدم.
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('StoreKit products not found: ${response.notFoundIDs}');
    }

    if (response.productDetails.isEmpty) {
      throw const AppException(
        'باقات الاشتراك غير متاحة الآن. حاول لاحقاً أو راسل الدعم.',
        code: 'iap_no_products',
      );
    }

    // نرتّبها بترتيب الكتالوج لا بترتيب رد المتجر.
    final order = AppConfig.subscriptionProductIds.toList();
    _products = response.productDetails.toList()
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));

    return products;
  }

  /// يبدأ شراء اشتراك.
  ///
  /// [appAccountToken] يجب أن يكون UUID صالحاً — Apple ترفض غيره. نمرّره
  /// ليعود إلينا داخل العملية الموقّعة، فيثبت للخادم أن هذا الشراء يخصّ
  /// هذا الحساب تحديداً ولا يمكن إعادة استخدامه في حساب آخر.
  Future<void> buy(ProductDetails product, {String? appAccountToken}) async {
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: _validUuidOrNull(appAccountToken),
    );

    final started = await _iap.buyNonConsumable(purchaseParam: param);
    if (!started) {
      throw const AppException(
        'ما قدرنا نبدأ عملية الشراء. حاول مرة ثانية.',
        code: 'iap_purchase_not_started',
      );
    }
  }

  /// يطلب من StoreKit إعادة إرسال المشتريات السابقة.
  ///
  /// النتائج تصل عبر [purchaseUpdates] بحالة `restored` كغيرها.
  Future<void> restore() async {
    if (!isSupportedPlatform) {
      throw const AppException(
        'الاستعادة متاحة على أجهزة Apple فقط.',
        code: 'iap_unsupported_platform',
        canRetry: false,
      );
    }
    try {
      await _iap.restorePurchases();
    } catch (error) {
      debugPrint('restorePurchases failed: $error');
      throw const AppException(
        'ما قدرنا نستعيد مشترياتك. تأكد من اتصالك وحاول مرة ثانية.',
        code: 'iap_restore_failed',
      );
    }
  }

  /// ينهي العملية لدى StoreKit.
  ///
  /// حتى تُنهى، يعيد النظام إرسالها عند كل إقلاع. لا تُستدعى إلا بعد
  /// حسم مصير العملية: تحقّق ناجح، أو رفض نهائي لا فائدة من إعادته.
  Future<void> complete(PurchaseDetails details) async {
    if (!details.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(details);
    } catch (error) {
      debugPrint('completePurchase failed: $error');
    }
  }

  /// Apple تشترط UUID في `appAccountToken` وترفض العملية إن كان غيره.
  static String? _validUuidOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(trimmed);
    if (isUuid) return trimmed;
    debugPrint('Ignoring non-UUID appAccountToken: $trimmed');
    return null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _purchases.close();
  }
}
