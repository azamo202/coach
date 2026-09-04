import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_exception.dart';
import '../models/training_program.dart';
import 'api_client.dart';
import 'prompt_builder.dart';

/// يولّد البرامج التدريبية عبر Claude.
///
/// في الإنتاج: يمر الطلب عبر الباك إند حتى لا يُشحن مفتاح Anthropic داخل
/// التطبيق (شرط أساسي لقبول التطبيق في المتاجر ولحماية المفتاح).
/// في التطوير المحلي: يمكن الاتصال مباشرة عبر `--dart-define=ANTHROPIC_API_KEY=...`.
class AiProgramService {
  AiProgramService({ApiClient? api, http.Client? httpClient})
      : _api = api,
        _http = httpClient ?? http.Client();

  final ApiClient? _api;
  final http.Client _http;

  Future<TrainingProgram> generate(ProgramRequest request) async {
    final raw = AppConfig.isOfflineMode || _api == null
        ? await _generateDirect(request)
        : await _generateViaBackend(request);

    return _toProgram(raw, request);
  }

  // ---------------------------------------------------------------------
  // المسار الموصى به: عبر الباك إند
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _generateViaBackend(
    ProgramRequest request,
  ) async {
    final response = await _api!.post(
      '/ai/program',
      body: request.toJson(),
      timeout: AppConfig.networkTimeout,
    );
    final program = response['program'];
    if (program is Map) {
      return program.map((k, v) => MapEntry(k.toString(), v));
    }
    throw AppException.aiBadFormat;
  }

  // ---------------------------------------------------------------------
  // مسار التطوير: اتصال مباشر بـ Anthropic
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _generateDirect(ProgramRequest request) async {
    final key = AppConfig.anthropicApiKeyDev.trim();
    if (key.isEmpty) throw AppException.missingApiKey;

    late final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': AppConfig.anthropicVersion,
            },
            body: jsonEncode(<String, dynamic>{
              'model': AppConfig.anthropicModel,
              'max_tokens': AppConfig.anthropicMaxTokens,
              'system': PromptBuilder.systemPrompt,
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'user',
                  'content': PromptBuilder.build(request),
                },
              ],
            }),
          )
          .timeout(AppConfig.networkTimeout);
    } catch (error) {
      debugPrint('AI request failed: $error');
      throw AppException.network;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('AI HTTP ${response.statusCode}: ${response.body}');
      throw AppException.aiFailed;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw AppException.aiBadFormat;

    final content = decoded['content'];
    if (content is! List) throw AppException.aiBadFormat;

    final text = content
        .whereType<Map>()
        .map((block) => block['text']?.toString() ?? '')
        .join();

    return extractJson(text);
  }

  // ---------------------------------------------------------------------
  // أدوات مساعدة
  // ---------------------------------------------------------------------

  /// يستخرج كائن JSON من نص قد يحتوي على أسوار كود أو شرح زائد.
  @visibleForTesting
  static Map<String, dynamic> extractJson(String raw) {
    var text = raw
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw AppException.aiBadFormat;
    }
    text = text.substring(start, end + 1);

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } on FormatException catch (error) {
      debugPrint('JSON parse failed: $error');
    }
    throw AppException.aiBadFormat;
  }

  /// يحوّل الـ JSON الخام إلى نموذج، ويتحقق أن البرنامج ليس فارغاً.
  static TrainingProgram _toProgram(
    Map<String, dynamic> raw,
    ProgramRequest request,
  ) {
    final enriched = <String, dynamic>{
      ...raw,
      'id': 'prog_${DateTime.now().microsecondsSinceEpoch}',
      'sport': safeString(raw['sport'], fallback: request.sport),
      'level': request.level.id,
      'goal': request.goal.id,
      'accentIndex': _accentIndexFor(request.sport),
      'createdAt': DateTime.now().toIso8601String(),
    };

    final program = TrainingProgram.fromJson(enriched);

    final hasSessions = program.weeks.any((w) => w.days.isNotEmpty);
    if (program.weeks.isEmpty || !hasSessions) {
      throw AppException.aiBadFormat;
    }
    return program;
  }

  static int _accentIndexFor(String sport) {
    var hash = 0;
    for (var i = 0; i < sport.length; i++) {
      hash = (hash * 31 + sport.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash % AccentPalette.gradients.length;
  }

  void dispose() => _http.close();
}
