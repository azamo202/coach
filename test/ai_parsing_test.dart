import 'package:flutter_test/flutter_test.dart';
import 'package:coachmint/core/utils/app_exception.dart';
import 'package:coachmint/data/models/fitness_level.dart';
import 'package:coachmint/data/services/ai_program_service.dart';
import 'package:coachmint/data/services/prompt_builder.dart';

void main() {
  group('AiProgramService.extractJson', () {
    test('يقرأ JSON نظيفاً', () {
      final result = AiProgramService.extractJson('{"sport":"جري"}');
      expect(result['sport'], 'جري');
    });

    test('يزيل أسوار الكود', () {
      const raw = '```json\n{"sport":"سباحة","weeks":[]}\n```';
      final result = AiProgramService.extractJson(raw);
      expect(result['sport'], 'سباحة');
    });

    test('يتجاهل النص الزائد قبل الـ JSON وبعده', () {
      const raw = 'تفضل البرنامج:\n{"sport":"بادل"}\nبالتوفيق!';
      final result = AiProgramService.extractJson(raw);
      expect(result['sport'], 'بادل');
    });

    test('يرمي خطأ عند غياب JSON', () {
      expect(
        () => AiProgramService.extractJson('ما فيه JSON هنا'),
        throwsA(isA<AppException>()),
      );
    });

    test('يرمي خطأ عند JSON مقطوع', () {
      expect(
        () => AiProgramService.extractJson('{"sport":"جري", "weeks": ['),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('PromptBuilder', () {
    test('يحقن المستوى والرياضة في الـ prompt', () {
      const request = ProgramRequest(
        sport: 'ملاكمة',
        level: FitnessLevel.advanced,
        goal: TrainingGoal.speed,
      );

      final prompt = PromptBuilder.build(request);

      expect(prompt, contains('ملاكمة'));
      expect(prompt, contains('محترف'));
      expect(prompt, contains('سرعة وانفجارية'));
      expect(prompt, contains(FitnessLevel.advanced.coachingBrief));
    });

    test('يستخدم الإعدادات الافتراضية لكل مستوى', () {
      const beginner = ProgramRequest(
        sport: 'جري',
        level: FitnessLevel.beginner,
      );
      const advanced = ProgramRequest(
        sport: 'جري',
        level: FitnessLevel.advanced,
      );

      expect(beginner.resolvedWeeks, FitnessLevel.beginner.defaultWeeks);
      expect(advanced.resolvedWeeks, FitnessLevel.advanced.defaultWeeks);
      expect(beginner.resolvedWeeks, lessThan(advanced.resolvedWeeks));
    });

    test('القيم الصريحة تتقدّم على الافتراضية', () {
      const request = ProgramRequest(
        sport: 'يوغا',
        level: FitnessLevel.beginner,
        weeks: 12,
        sessionsPerWeek: 6,
      );

      expect(request.resolvedWeeks, 12);
      expect(request.resolvedSessions, 6);
      expect(PromptBuilder.build(request), contains('12 أسابيع'));
    });

    test('يضيف الملاحظات والإصابات عند وجودها فقط', () {
      const withNotes = ProgramRequest(
        sport: 'كرة قدم',
        level: FitnessLevel.intermediate,
        notes: 'إصابة في الركبة اليمنى',
      );
      const withoutNotes = ProgramRequest(
        sport: 'كرة قدم',
        level: FitnessLevel.intermediate,
      );

      expect(
          PromptBuilder.build(withNotes), contains('إصابة في الركبة اليمنى'),);
      expect(
          PromptBuilder.build(withoutNotes), isNot(contains('ملاحظات وقيود')),);
    });
  });
}
