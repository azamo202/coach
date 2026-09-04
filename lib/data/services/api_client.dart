import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/utils/app_exception.dart';

/// عميل REST بسيط للتعامل مع الباك إند.
///
/// يضيف توكن الدخول تلقائياً، ويحوّل أخطاء السيرفر إلى [AppException]
/// برسائل عربية جاهزة للعرض.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  String? _token;

  String get baseUrl => _baseUrl;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  void setToken(String? token) => _token = token;

  Map<String, String> _headers() => <String, String>{
        'content-type': 'application/json; charset=utf-8',
        'accept': 'application/json',
        if (hasToken) 'authorization': 'Bearer $_token',
      };

  Uri _uri(String path) =>
      Uri.parse('$_baseUrl${path.startsWith('/') ? path : '/$path'}');

  Future<Map<String, dynamic>> get(
    String path, {
    Duration? timeout,
  }) =>
      _send(() => _http.get(_uri(path), headers: _headers()), timeout);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) =>
      _send(
        () => _http.post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ),
        timeout,
      );

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) =>
      _send(
        () => _http.put(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ),
        timeout,
      );

  Future<Map<String, dynamic>> delete(String path, {Duration? timeout}) =>
      _send(() => _http.delete(_uri(path), headers: _headers()), timeout);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Duration? timeout,
  ) async {
    late final http.Response response;
    try {
      response =
          await request().timeout(timeout ?? const Duration(seconds: 25));
    } catch (error) {
      debugPrint('API request failed: $error');
      throw AppException.network;
    }

    Map<String, dynamic> decoded = <String, dynamic>{};
    if (response.bodyBytes.isNotEmpty) {
      try {
        final value = jsonDecode(utf8.decode(response.bodyBytes));
        if (value is Map) {
          decoded = value.map((k, v) => MapEntry(k.toString(), v));
        }
      } on FormatException catch (error) {
        debugPrint('API decode failed: $error');
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      final message = decoded['message']?.toString();
      final code = decoded['code']?.toString() ?? 'unauthorized';
      if (message != null && message.isNotEmpty) {
        throw AppException(message, code: code, canRetry: false);
      }
      throw AppException.unauthorized;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString();
      throw AppException(
        message != null && message.isNotEmpty
            ? message
            : 'صار خطأ في الخدمة (${response.statusCode}). حاول مرة ثانية.',
        code: decoded['code']?.toString(),
      );
    }

    return decoded;
  }

  void dispose() => _http.close();
}
