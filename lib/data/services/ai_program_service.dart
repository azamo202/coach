import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_exception.dart';
import '../models/coach_advice.dart';
import '../models/training_program.dart';
import 'api_client.dart';
import 'prompt_builder.dart';

/// خدمة الذكاء الاصطناعي لتوليد البرامج الرياضية وتقديم استشارات التدريب.
///
/// تم تصميم الخدمة وفق البنية الآمنة الموصى بها للإنتاج:
/// جميع الطلبات تمر حصراً عبر خادم الباك إند الآمن لحماية مفاتيح OpenAI
/// وتطبيق آليات التحقق المزدوج وإعادة المحاولة وتتبع الاستهلاك.
class AiProgramService {
  AiProgramService({required ApiClient? api}) : _api = api;

  final ApiClient? _api;

  /// توليد برنامج تدريبي مخصص عبر الباك إند المتصل بـ OpenAI.
  Future<TrainingProgram> generate(ProgramRequest request) async {
    final client = _api;
    if (client == null) {
      throw const AppException(
        'تعذّر الاتصال بخادم CoachMint. تأكد من تشغيل السيرفر.',
        code: 'server_unavailable',
      );
    }

    final response = await client.post(
      '/ai/program',
      body: request.toJson(),
      timeout: AppConfig.networkTimeout,
    );

    final programData = response['program'];
    if (programData is Map) {
      final raw = programData.map((k, v) => MapEntry(k.toString(), v));
      return _toProgram(raw, request);
    }
    throw AppException.aiBadFormat;
  }

  /// الحصول على استشارة تدريبية ذكية وآمنة من المدرب الذكي (OpenAI).
  Future<CoachAdvice> getCoachAdvice({
    required String question,
    Exercise? exercise,
    String? sport,
    String? level,
    String? goal,
  }) async {
    final client = _api;
    if (client == null) {
      throw const AppException(
        'خدمة المدرب الذكي تتطلب الاتصال بالسيرفر.',
        code: 'server_unavailable',
      );
    }

    final response = await client.post(
      '/ai/coach-advice',
      body: <String, dynamic>{
        'question': question,
        if (exercise != null)
          'exercise': <String, dynamic>{
            'name': exercise.name,
            'sets': exercise.sets,
            'reps': exercise.reps,
            'targetMuscles': exercise.targetMuscles,
            'equipment': exercise.equipment,
          },
        'userContext': <String, dynamic>{
          if (sport != null) 'sport': sport,
          if (level != null) 'level': level,
          if (goal != null) 'goal': goal,
        },
      },
      timeout: const Duration(seconds: 45),
    );

    final adviceMap = response['advice'];
    if (adviceMap is Map) {
      return CoachAdvice.fromJson(
        adviceMap.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    throw AppException.aiBadFormat;
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

  /// يحوّل الـ JSON الخام إلى نموذج، ويتحقق أن البرنامج مكتمل العناصر.
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
}
