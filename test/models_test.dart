import 'package:flutter_test/flutter_test.dart';
import 'package:coachmint/data/models/fitness_level.dart';
import 'package:coachmint/data/models/program_progress.dart';
import 'package:coachmint/data/models/training_program.dart';

TrainingProgram buildProgram({int weeks = 3, int daysPerWeek = 3}) {
  return TrainingProgram(
    id: 'p1',
    sport: 'كرة السلة',
    level: FitnessLevel.intermediate,
    goal: TrainingGoal.skill,
    createdAt: DateTime(2026, 1, 1),
    weeks: List<TrainingWeek>.generate(
      weeks,
      (w) => TrainingWeek(
        title: 'أسبوع ${w + 1}',
        days: List<TrainingDay>.generate(
          daysPerWeek,
          (d) => TrainingDay(
            label: 'جلسة ${d + 1}',
            exercises: const <Exercise>[Exercise(name: 'تمرين')],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TrainingProgram', () {
    test('يحسب إجمالي الأسابيع والجلسات والتمارين', () {
      final program = buildProgram(weeks: 4, daysPerWeek: 3);

      expect(program.totalWeeks, 4);
      expect(program.totalSessions, 12);
      expect(program.totalExercises, 12);
    });

    test('dayAt يرجع null خارج الحدود', () {
      final program = buildProgram(weeks: 2, daysPerWeek: 2);

      expect(program.dayAt(0, 0), isNotNull);
      expect(program.dayAt(5, 0), isNull);
      expect(program.dayAt(0, 9), isNull);
      expect(program.dayAt(-1, 0), isNull);
    });

    test('يمر بدورة JSON كاملة دون فقد بيانات', () {
      final program = buildProgram();
      final restored = TrainingProgram.fromJson(program.toJson());

      expect(restored.sport, program.sport);
      expect(restored.level, program.level);
      expect(restored.goal, program.goal);
      expect(restored.totalSessions, program.totalSessions);
    });

    test('يتحمل ردوداً ناقصة من الذكاء الاصطناعي', () {
      final program = TrainingProgram.fromJson(<String, dynamic>{
        'weeks': <dynamic>[
          <String, dynamic>{
            'days': <dynamic>[
              <String, dynamic>{'exercises': <dynamic>[]},
            ],
          },
        ],
      });

      expect(program.sport, 'رياضة');
      expect(program.level, FitnessLevel.beginner);
      expect(program.weeks.first.title, 'مرحلة تدريبية');
      expect(program.weeks.first.days.first.label, 'جلسة تدريبية');
    });
  });

  group('FitnessLevel', () {
    test('كل مستوى له إعدادات مختلفة', () {
      expect(
        FitnessLevel.beginner.defaultWeeks,
        lessThan(
          FitnessLevel.advanced.defaultWeeks,
        ),
      );
      expect(
        FitnessLevel.beginner.defaultSessionsPerWeek,
        lessThan(FitnessLevel.advanced.defaultSessionsPerWeek),
      );
      expect(
        FitnessLevel.beginner.coachingBrief,
        isNot(equals(FitnessLevel.advanced.coachingBrief)),
      );
    });

    test('fromId يرجع مبتدئ عند قيمة غير معروفة', () {
      expect(FitnessLevel.fromId('advanced'), FitnessLevel.advanced);
      expect(FitnessLevel.fromId('غير معروف'), FitnessLevel.beginner);
      expect(FitnessLevel.fromId(null), FitnessLevel.beginner);
    });
  });

  group('ProgramProgress', () {
    test('toggle يضيف ويحذف الجلسة', () {
      final program = buildProgram(weeks: 2, daysPerWeek: 2);
      var progress = const ProgramProgress();

      expect(progress.isDone(0, 0), isFalse);

      progress = progress.toggle(0, 0);
      expect(progress.isDone(0, 0), isTrue);
      expect(progress.completedCount, 1);

      progress = progress.toggle(0, 0);
      expect(progress.isDone(0, 0), isFalse);
      expect(progress.percentFor(program), 0);
    });

    test('يحسب النسبة المئوية بدقة', () {
      final program = buildProgram(weeks: 2, daysPerWeek: 2); // 4 جلسات
      var progress = const ProgramProgress();

      progress = progress.toggle(0, 0).toggle(0, 1);

      expect(progress.percentFor(program), 50);
      expect(progress.completedInWeek(0), 2);
      expect(progress.completedInWeek(1), 0);
      expect(progress.isComplete(program), isFalse);
    });

    test('nextSession يرجع أول جلسة غير مكتملة', () {
      final program = buildProgram(weeks: 2, daysPerWeek: 2);
      var progress = const ProgramProgress();

      expect(progress.nextSession(program)?.weekIndex, 0);
      expect(progress.nextSession(program)?.dayIndex, 0);

      progress = progress.toggle(0, 0);
      expect(progress.nextSession(program)?.dayIndex, 1);

      progress = progress.toggle(0, 1).toggle(1, 0).toggle(1, 1);
      expect(progress.nextSession(program), isNull);
      expect(progress.isComplete(program), isTrue);
    });

    test('currentWeekIndex ينتقل للأسبوع التالي بعد اكتمال الحالي', () {
      final program = buildProgram(weeks: 3, daysPerWeek: 2);
      var progress = const ProgramProgress();

      expect(progress.currentWeekIndex(program), 0);

      progress = progress.toggle(0, 0).toggle(0, 1);
      expect(progress.currentWeekIndex(program), 1);
    });

    test('يحسب السلسلة اليومية المتتالية', () {
      final now = DateTime.now();
      final progress = ProgramProgress(
        completed: <String, DateTime>{
          '0-0': now,
          '0-1': now.subtract(const Duration(days: 1)),
          '0-2': now.subtract(const Duration(days: 2)),
          // فجوة يوم كامل تكسر السلسلة
          '1-0': now.subtract(const Duration(days: 5)),
        },
      );

      expect(progress.streakDays, 3);
      expect(progress.completedInLastDays(3), 3);
    });

    test('السلسلة تساوي صفراً بعد انقطاع أكثر من يوم', () {
      final progress = ProgramProgress(
        completed: <String, DateTime>{
          '0-0': DateTime.now().subtract(const Duration(days: 4)),
        },
      );

      expect(progress.streakDays, 0);
    });

    test('reset يمسح الجلسات المكتملة', () {
      final program = buildProgram();
      final progress = const ProgramProgress().toggle(0, 0).reset();

      expect(progress.completedCount, 0);
      expect(progress.ratioFor(program), 0);
    });
  });

  group('SavedProgram', () {
    test('يمر بدورة JSON مع الحفاظ على التقدّم', () {
      final entry = SavedProgram(
        program: buildProgram(weeks: 2, daysPerWeek: 2),
        progress: const ProgramProgress().toggle(0, 0),
      );

      final restored = SavedProgram.fromJson(entry.toJson());

      expect(restored.id, entry.id);
      expect(restored.progress.isDone(0, 0), isTrue);
      expect(restored.percent, 25);
    });
  });
}
