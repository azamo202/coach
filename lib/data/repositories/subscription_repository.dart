import '../../core/utils/app_exception.dart';
import '../models/subscription.dart';
import '../services/api_client.dart';

/// بوابة التطبيق إلى صلاحيات الاشتراك على الخادم.
///
/// كل دالة هنا تُرجع [Entitlement] كما يقرّره الخادم. التطبيق لا يستنتج
/// صلاحية من ردّ StoreKit مباشرة أبداً.
class SubscriptionRepository {
  const SubscriptionRepository(this._api);

  final ApiClient _api;

  static const Duration _timeout = Duration(seconds: 30);

  /// الحالة الحالية. الخادم قد يسأل Apple إن بدت نسخته قديمة.
  Future<Entitlement> fetch() async {
    final response = await _api.get('/subscriptions/me', timeout: _timeout);
    return _entitlementFrom(response);
  }

  /// يؤكّد عملية شراء تمّت للتوّ.
  ///
  /// [signedTransaction] هو تمثيل JWS الذي يعطيه StoreKit 2 — موقّع من
  /// Apple ومقروء من الخادم. [transactionId] احتياط لعمليات StoreKit 1.
  Future<Entitlement> verify({
    String? signedTransaction,
    String? transactionId,
  }) async {
    final response = await _api.post(
      '/subscriptions/apple/verify',
      body: <String, dynamic>{
        if (signedTransaction != null && signedTransaction.isNotEmpty)
          'signedTransaction': signedTransaction,
        if (transactionId != null && transactionId.isNotEmpty)
          'transactionId': transactionId,
      },
      timeout: _timeout,
    );
    return _entitlementFrom(response);
  }

  Entitlement _entitlementFrom(Map<String, dynamic> response) {
    final raw = response['entitlement'];
    if (raw is Map) {
      return Entitlement.fromJson(raw.map((k, v) => MapEntry(k.toString(), v)));
    }
    throw const AppException(
      'رد غير متوقع من خدمة الاشتراكات.',
      code: 'bad_response',
    );
  }
}
