import 'training_program.dart';

/// تتبّع تقدّم المستخدم داخل برنامج واحد.
///
/// المفتاح لكل جلسة هو "رقم الأسبوع-رقم الجلسة" مثل `0-2`.
class ProgramProgress {
  const ProgramProgress({
    this.completed = const <String, DateTime>{},
    this.lastOpenedAt,
  });

  /// الجلسات المكتملة ووقت إكمال كل واحدة.
  final Map<String, DateTime> completed;

  final DateTime? lastOpenedAt;

  static String keyFor(int weekIndex, int dayIndex) => '$weekIndex-$dayIndex';

  bool isDone(int weekIndex, int dayIndex) =>
      completed.containsKey(keyFor(weekIndex, dayIndex));

  DateTime? doneAt(int weekIndex, int dayIndex) =>
      completed[keyFor(weekIndex, dayIndex)];

  int get completedCount => completed.length;

  int completedInWeek(int weekIndex) =>
      completed.keys.where((k) => k.startsWith('$weekIndex-')).length;

  /// نسبة الإنجاز من 0 إلى 1.
  double ratioFor(TrainingProgram program) {
    final total = program.totalSessions;
    if (total == 0) return 0;
    return (completedCount / total).clamp(0.0, 1.0);
  }

  int percentFor(TrainingProgram program) => (ratioFor(program) * 100).round();

  /// أول أسبوع لم يكتمل بعد — يُستخدم لفتح البرنامج على المكان الصحيح.
  int currentWeekIndex(TrainingProgram program) {
    for (var w = 0; w < program.weeks.length; w++) {
      final days = program.weeks[w].days.length;
      if (days == 0) continue;
      if (completedInWeek(w) < days) return w;
    }
    return program.weeks.isEmpty ? 0 : program.weeks.length - 1;
  }

  /// الجلسة القادمة المقترحة، أو null إذا اكتمل البرنامج.
  ({int weekIndex, int dayIndex, TrainingDay day})? nextSession(
    TrainingProgram program,
  ) {
    for (var w = 0; w < program.weeks.length; w++) {
      final days = program.weeks[w].days;
      for (var d = 0; d < days.length; d++) {
        if (!isDone(w, d)) {
          return (weekIndex: w, dayIndex: d, day: days[d]);
        }
      }
    }
    return null;
  }

  bool isComplete(TrainingProgram program) =>
      program.totalSessions > 0 && completedCount >= program.totalSessions;

  /// عدد الأيام المتتالية التي أُنجزت فيها جلسة واحدة على الأقل.
  int get streakDays {
    if (completed.isEmpty) return 0;
    final days = completed.values
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (days.first != today && days.first != yesterday) return 0;

    var streak = 1;
    for (var i = 0; i < days.length - 1; i++) {
      if (days[i].difference(days[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// عدد الجلسات المكتملة خلال آخر [days] يوماً.
  int completedInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return completed.values.where((d) => d.isAfter(cutoff)).length;
  }

  ProgramProgress toggle(int weekIndex, int dayIndex) {
    final key = keyFor(weekIndex, dayIndex);
    final next = Map<String, DateTime>.from(completed);
    if (next.containsKey(key)) {
      next.remove(key);
    } else {
      next[key] = DateTime.now();
    }
    return ProgramProgress(completed: next, lastOpenedAt: DateTime.now());
  }

  ProgramProgress markOpened() => ProgramProgress(
        completed: completed,
        lastOpenedAt: DateTime.now(),
      );

  ProgramProgress reset() => ProgramProgress(lastOpenedAt: lastOpenedAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'completed': completed.map(
          (k, v) => MapEntry(k, v.toIso8601String()),
        ),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      };

  factory ProgramProgress.fromJson(Map<String, dynamic> json) {
    final raw = json['completed'];
    final map = <String, DateTime>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final parsed = DateTime.tryParse(value?.toString() ?? '');
        if (parsed != null) map[key.toString()] = parsed;
      });
    }
    return ProgramProgress(
      completed: map,
      lastOpenedAt: DateTime.tryParse((json['lastOpenedAt'] ?? '').toString()),
    );
  }
}

/// برنامج محفوظ في مكتبة المستخدم = البرنامج + تقدّمه.
class SavedProgram {
  const SavedProgram({required this.program, required this.progress});

  final TrainingProgram program;
  final ProgramProgress progress;

  String get id => program.id;

  int get percent => progress.percentFor(program);

  double get ratio => progress.ratioFor(program);

  bool get isComplete => progress.isComplete(program);

  SavedProgram copyWith({
    TrainingProgram? program,
    ProgramProgress? progress,
  }) =>
      SavedProgram(
        program: program ?? this.program,
        progress: progress ?? this.progress,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'program': program.toJson(),
        'progress': progress.toJson(),
      };

  factory SavedProgram.fromJson(Map<String, dynamic> json) {
    final programJson = json['program'];
    final progressJson = json['progress'];
    return SavedProgram(
      program: TrainingProgram.fromJson(
        programJson is Map
            ? programJson.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      ),
      progress: ProgramProgress.fromJson(
        progressJson is Map
            ? progressJson.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      ),
    );
  }
}
