import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/utils/app_exception.dart';
import '../data/models/subscription.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/services/iap_service.dart';
import '../data/services/local_store.dart';

/// أين وصلت عملية الشراء الجارية.
enum PurchaseStage {
  idle,

  /// المستخدم داخل شاشة الدفع، أو العملية بانتظار موافقة (Ask to Buy).
  buying,

  /// الدفع تم ونحن نؤكّده مع الخادم.
  verifying,

  /// جارٍ سؤال المتجر عن مشتريات سابقة.
  restoring,
}

/// يدير الاشتراك: الصلاحية، المنتجات، والشراء والاستعادة.
///
/// السياسة المركزية هنا سطران:
///
/// 1. **الصلاحية تأتي من الخادم فقط.** ما يقوله StoreKit هو «تمّ الدفع»،
///    وهذا ليس نفسه «يستحق الميزة». الخادم يسأل Apple ثم يقرر.
/// 2. **لا تُنهى عملية شراء قبل حسم مصيرها.** ما دامت غير منتهية يعيد
///    النظام إرسالها عند كل إقلاع — وهذا بالضبط ما ينقذ دفعةً حصلت بينما
///    كان خادمنا متوقفاً.
class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    required IapService iap,
    required SubscriptionRepository repository,
    required LocalStore store,
  })  : _iap = iap,
        _repository = repository,
        _store = store;

  final IapService _iap;
  final SubscriptionRepository _repository;
  final LocalStore _store;

  StreamSubscription<PurchaseDetails>? _purchaseSub;

  Entitlement _entitlement = Entitlement.unknown;

  /// هل لدينا صورة صالحة للصلاحية (من الخادم أو من الذاكرة المحلية)؟
  ///
  /// الفرق بين «لا نعرف بعد» و«نعرف أنه غير مشترك» هو ما يحدّد سلوكنا عند
  /// انقطاع الشبكة: الأولى تُظهر خطأ، والثانية تُبقي ما نعرفه.
  bool _hasKnownState = false;

  bool _refreshing = false;

  PurchaseStage _stage = PurchaseStage.idle;
  String? _error;
  String? _notice;

  List<ProductDetails> _products = const <ProductDetails>[];
  bool _loadingProducts = false;
  String? _productsError;

  String? _appAccountToken;

  // ------------------------------------------------------------------
  // القراءة
  // ------------------------------------------------------------------

  Entitlement get entitlement => _entitlement;
  PurchaseStage get stage => _stage;
  bool get isBusy => _stage != PurchaseStage.idle;
  bool get isRefreshing => _refreshing;
  String? get error => _error;

  /// رسالة إعلامية لا تمثّل خطأ — «تمّ الاشتراك»، «ما لقينا مشتريات».
  String? get notice => _notice;

  List<ProductDetails> get products => List.unmodifiable(_products);
  bool get isLoadingProducts => _loadingProducts;
  String? get productsError => _productsError;
  bool get storeAvailable => _iap.isAvailable;

  bool get isSubscribed => _entitlement.isSubscribed;
  bool get canCreateProgram => _entitlement.canCreateProgram;
  bool get canAskCoach => _entitlement.coachAdvice;

  ProductDetails? productFor(SubscriptionPlan plan) =>
      plan.productId == null ? null : _iap.productFor(plan.productId!);

  /// السعر كما يعرضه المتجر بعملة المستخدم، أو تلميح ثابت قبل وصوله.
  String priceLabel(SubscriptionPlan plan) =>
      productFor(plan)?.price ?? plan.priceHint;

  // ------------------------------------------------------------------
  // دورة الحياة
  // ------------------------------------------------------------------

  /// يبدأ الإصغاء للمتجر. يُستدعى مرة واحدة عند إقلاع التطبيق.
  ///
  /// يسبق تسجيل الدخول عمداً: العمليات المعلّقة من جلسة سابقة تصل فور بدء
  /// الإصغاء، ولا يجوز أن نفوّتها بانتظار المستخدم.
  Future<void> start() async {
    await _iap.start();
    _purchaseSub ??= _iap.purchaseUpdates.listen(
      _onPurchase,
      onError: (Object error) => debugPrint('Purchase stream error: $error'),
    );
  }

  /// يربط الجلسة بحساب المستخدم ويحمّل صلاحيته.
  Future<void> bindAccount({
    required String userId,
    String? appAccountToken,
  }) async {
    _appAccountToken = appAccountToken;
    final cached = _readCache(userId);
    if (cached != null) {
      _entitlement = cached;
      _hasKnownState = true;
    } else {
      _entitlement = Entitlement.unknown;
      _hasKnownState = false;
    }
    _cacheOwner = userId;
    notifyListeners();
    await refresh();
  }

  String? _cacheOwner;

  /// يعيد الحالة إلى ما قبل تسجيل الدخول.
  void clear() {
    _appAccountToken = null;
    _cacheOwner = null;
    _entitlement = Entitlement.unknown;
    _hasKnownState = false;
    _stage = PurchaseStage.idle;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // تحديث الصلاحية
  // ------------------------------------------------------------------

  /// يسأل الخادم عن الصلاحية الحالية.
  ///
  /// عند فشل الاتصال نحتفظ بآخر صلاحية معروفة بدل إسقاط المشترك إلى
  /// الخطة المجانية: انقطاع الشبكة ليس انتهاء اشتراك.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();

    try {
      _entitlement = await _repository.fetch();
      _hasKnownState = true;
      _writeCache();
      _error = null;
    } on AppException catch (error) {
      debugPrint('Entitlement refresh failed: ${error.message}');
      // لا نُظهر خطأً فوق صورة نعرفها: المشترك بلا إنترنت يبقى مشتركاً.
      if (!_hasKnownState) _error = error.message;
    } catch (error) {
      debugPrint('Entitlement refresh failed: $error');
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // المنتجات
  // ------------------------------------------------------------------

  Future<void> loadProducts({bool force = false}) async {
    if (_loadingProducts) return;
    if (!force && _products.isNotEmpty) return;

    _loadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      _products = await _iap.loadProducts();
    } on AppException catch (error) {
      _productsError = error.message;
    } catch (error) {
      debugPrint('Product load failed: $error');
      _productsError = 'ما قدرنا نجيب باقات الاشتراك. حاول مرة ثانية.';
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // الشراء
  // ------------------------------------------------------------------

  /// يبدأ شراء خطة. النتيجة تصل عبر مجرى العمليات لا كقيمة راجعة.
  Future<void> purchase(SubscriptionPlan plan) async {
    if (isBusy) return;

    final product = productFor(plan);
    if (product == null) {
      _fail('هذه الباقة غير متاحة الآن. حدّث الصفحة أو حاول لاحقاً.');
      return;
    }

    _stage = PurchaseStage.buying;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      await _iap.buy(product, appAccountToken: _appAccountToken);
    } on AppException catch (error) {
      _fail(error.message);
    } catch (error) {
      debugPrint('Purchase start failed: $error');
      _fail('ما قدرنا نفتح شاشة الدفع. حاول مرة ثانية.');
    }
  }

  /// يستعيد اشتراكاً سابقاً على نفس Apple ID.
  ///
  /// Apple تشترط وجود هذا الزر في أي تطبيق يبيع اشتراكات.
  Future<void> restore() async {
    if (isBusy) return;

    _stage = PurchaseStage.restoring;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      await _iap.restore();
    } on AppException catch (error) {
      _fail(error.message);
      return;
    }

    // الاستعادة لا تُرجع نتيجة: ما يوجد يصل عبر المجرى، وما لا يوجد لا
    // يصل شيء عنه. فننتظر وصول ما سيصل ثم نسأل الخادم عن الحصيلة.
    await Future<void>.delayed(const Duration(seconds: 3));
    await refresh();

    _stage = PurchaseStage.idle;
    _notice = _entitlement.isSubscribed
        ? 'رجّعنا اشتراكك ✓'
        : 'ما لقينا اشتراكاً سابقاً على حساب Apple هذا.';
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // معالجة ما يصل من المتجر
  // ------------------------------------------------------------------

  Future<void> _onPurchase(PurchaseDetails details) async {
    switch (details.status) {
      case PurchaseStatus.pending:
        // شراء ينتظر موافقة ولي الأمر مثلاً. لا نُنهيه ولا نمنح شيئاً.
        _stage = PurchaseStage.buying;
        _notice = 'الشراء بانتظار الموافقة. نفتح لك الاشتراك فور اكتماله.';
        notifyListeners();

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyThenFinish(details);

      case PurchaseStatus.error:
        debugPrint('Purchase error: ${details.error}');
        await _iap.complete(details);
        _fail(
          'ما تمّت عملية الشراء. لم يُخصم منك شيء — جرّب مرة ثانية.',
        );

      case PurchaseStatus.canceled:
        await _iap.complete(details);
        _stage = PurchaseStage.idle;
        notifyListeners();
    }
  }

  /// يؤكّد العملية مع الخادم ثم يقرر إنهاءها لدى StoreKit.
  Future<void> _verifyThenFinish(PurchaseDetails details) async {
    _stage = PurchaseStage.verifying;
    _error = null;
    notifyListeners();

    final signed = details.verificationData.serverVerificationData;

    try {
      _entitlement = await _repository.verify(
        signedTransaction: signed.isNotEmpty ? signed : null,
        transactionId: details.purchaseID,
      );
      _hasKnownState = true;
      _writeCache();

      // نجح التحقق: الآن فقط يجوز إنهاء العملية.
      await _iap.complete(details);

      _stage = PurchaseStage.idle;
      _error = null;
      _notice = details.status == PurchaseStatus.restored
          ? 'رجّعنا اشتراكك ✓'
          : 'تم تفعيل اشتراكك ✓';
      notifyListeners();
    } on AppException catch (error) {
      await _handleVerificationFailure(details, error);
    } catch (error) {
      debugPrint('Verification crashed: $error');
      // خطأ لا نعرفه: نُبقي العملية معلّقة لتُعاد المحاولة لاحقاً.
      _fail('ما قدرنا نأكّد اشتراكك الآن. نعيد المحاولة تلقائياً.');
    }
  }

  /// يقرر مصير عملية فشل التحقق منها.
  ///
  /// الفرق حاسم: خطأ عابر (شبكة، خادم متوقف) يجب أن تبقى معه العملية
  /// معلّقة حتى تُعاد المحاولة، وإلا ضاعت دفعة المستخدم. أما رفض نهائي
  /// (اشتراك مرتبط بحساب آخر) فإبقاؤه معلّقاً يعني حلقة لا تنتهي عند كل
  /// إقلاع، فنُنهيه ونشرح للمستخدم.
  Future<void> _handleVerificationFailure(
    PurchaseDetails details,
    AppException error,
  ) async {
    const permanentCodes = <String>{
      'subscription_bound_to_other_account',
      'subscription_not_found',
      'bad_request',
      'apple_jws_invalid',
    };

    final isPermanent = permanentCodes.contains(error.code) || !error.canRetry;

    if (isPermanent) {
      await _iap.complete(details);
      _fail(error.message);
      return;
    }

    _fail(
      '${error.message} اشتراكك محفوظ لدى Apple وسنؤكّده تلقائياً عند فتح '
      'التطبيق مرة ثانية.',
    );
  }

  // ------------------------------------------------------------------
  // أدوات
  // ------------------------------------------------------------------

  void _fail(String message) {
    _stage = PurchaseStage.idle;
    _error = message;
    _notice = null;
    notifyListeners();
  }

  void clearMessages() {
    if (_error == null && _notice == null) return;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // ذاكرة محلية للصلاحية
  // ------------------------------------------------------------------
  //
  // تمنع قفل مشترك يفتح التطبيق بلا إنترنت. ليست مصدر ثقة: الخادم يرفض
  // أي طلب مدفوع بلا اشتراك فعلي مهما قالت هذه الذاكرة.

  String _cacheKey(String userId) => 'entitlement_$userId';

  Entitlement? _readCache(String userId) {
    final raw = _store.getJson(_cacheKey(userId));
    if (raw == null) return null;
    try {
      return Entitlement.fromJson(raw);
    } catch (error) {
      debugPrint('Entitlement cache unreadable: $error');
      return null;
    }
  }

  void _writeCache() {
    final owner = _cacheOwner;
    if (owner == null) return;
    _store.setJson(_cacheKey(owner), <String, dynamic>{
      'planId': _entitlement.plan.id,
      'isSubscribed': _entitlement.isSubscribed,
      'activePrograms': _entitlement.activePrograms,
      'remainingSlots': _entitlement.remainingSlots,
      'canCreateProgram': _entitlement.canCreateProgram,
      'coachAdvice': _entitlement.coachAdvice,
      'freeGenerationsUsed': _entitlement.freeGenerationsUsed,
      'freeGenerationsLimit': _entitlement.freeGenerationsLimit,
      'expiresAt': _entitlement.expiresAt?.toIso8601String(),
      'autoRenew': _entitlement.autoRenew,
      'inGracePeriod': _entitlement.inGracePeriod,
      'isTrial': _entitlement.isTrial,
      'billingIssue': _entitlement.billingIssue,
    });
  }
}
