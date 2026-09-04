import 'fitness_level.dart';

/// تمرين واحد داخل جلسة تدريبية.
class Exercise {
  const Exercise({
    required this.name,
    this.sets = 3,
    this.reps = '',
    this.restSeconds = 60,
    this.howTo = '',
    this.cue = '',
    this.targetMuscles = '',
    this.equipment = '',
    this.tempo = '',
  });

  /// اسم التمرين.
  final String name;

  /// عدد المجموعات (السِتّات).
  final int sets;

  /// التكرارات — قد تكون رقماً أو مدة ("12" أو "40 ثانية").
  final String reps;

  /// الراحة بين المجموعات بالثواني.
  final int restSeconds;

  /// طريقة الأداء بالتفصيل — المرجع السريع للمستخدم.
  final String howTo;

  /// نصيحة تنفيذ قصيرة تظهر مع التمرين.
  final String cue;

  /// العضلات المستهدفة.
  final String targetMuscles;

  /// الأدوات المطلوبة.
  final String equipment;

  /// إيقاع الأداء مثل "2-1-2".
  final String tempo;

  String get volumeLabel {
    final parts = <String>[];
    if (sets > 0) parts.add('$sets مجموعات');
    if (reps.trim().isNotEmpty) parts.add(reps.trim());
    return parts.join(' × ');
  }

  String get restLabel {
    if (restSeconds <= 0) return '';
    if (restSeconds < 60) return 'راحة $restSeconds ث';
    final minutes = restSeconds ~/ 60;
    final seconds = restSeconds % 60;
    return seconds == 0 ? 'راحة $minutes د' : 'راحة $minutes د $seconds ث';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
        'howTo': howTo,
        'cue': cue,
        'targetMuscles': targetMuscles,
        'equipment': equipment,
        'tempo': tempo,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: safeString(json['name'], fallback: 'تمرين'),
      sets: safeInt(json['sets'], fallback: 3),
      reps: safeString(json['reps']),
      restSeconds: safeInt(json['restSeconds'], fallback: 60),
      howTo: safeString(json['howTo']),
      cue: safeString(json['cue']),
      targetMuscles: safeString(json['targetMuscles']),
      equipment: safeString(json['equipment']),
      tempo: safeString(json['tempo']),
    );
  }
}

/// جلسة تدريبية (يوم) داخل الأسبوع.
class TrainingDay {
  const TrainingDay({
    required this.label,
    this.focus = '',
    this.durationMinutes = 45,
    this.warmUp = '',
    this.coolDown = '',
    this.exercises = const <Exercise>[],
  });

  final String label;
  final String focus;
  final int durationMinutes;
  final String warmUp;
  final String coolDown;
  final List<Exercise> exercises;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'focus': focus,
        'durationMinutes': durationMinutes,
        'warmUp': warmUp,
        'coolDown': coolDown,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory TrainingDay.fromJson(Map<String, dynamic> json) {
    return TrainingDay(
      label: safeString(json['label'], fallback: 'جلسة تدريبية'),
      focus: safeString(json['focus']),
      durationMinutes: safeInt(json['durationMinutes'], fallback: 45),
      warmUp: safeString(json['warmUp']),
      coolDown: safeString(json['coolDown']),
      exercises: safeMapList(json['exercises'])
          .map(Exercise.fromJson)
          .toList(growable: false),
    );
  }
}

/// أسبوع تدريبي.
class TrainingWeek {
  const TrainingWeek({
    required this.title,
    this.focus = '',
    this.intensity = '',
    this.days = const <TrainingDay>[],
  });

  final String title;
  final String focus;

  /// وصف شدة الأسبوع، مثل "شدة متوسطة 70%".
  final String intensity;

  final List<TrainingDay> days;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'focus': focus,
        'intensity': intensity,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory TrainingWeek.fromJson(Map<String, dynamic> json) {
    return TrainingWeek(
      title: safeString(json['title'], fallback: 'مرحلة تدريبية'),
      focus: safeString(json['focus']),
      intensity: safeString(json['intensity']),
      days: safeMapList(json['days'])
          .map(TrainingDay.fromJson)
          .toList(growable: false),
    );
  }
}

/// البرنامج التدريبي الكامل لرياضة واحدة.
class TrainingProgram {
  const TrainingProgram({
    required this.id,
    required this.sport,
    required this.level,
    required this.goal,
    required this.weeks,
    required this.createdAt,
    this.summary = '',
    this.tips = const <String>[],
    this.equipmentNeeded = const <String>[],
    this.safetyNotes = '',
    this.accentIndex = 0,
  });

  final String id;
  final String sport;
  final FitnessLevel level;
  final TrainingGoal goal;
  final List<TrainingWeek> weeks;
  final String summary;
  final List<String> tips;
  final List<String> equipmentNeeded;
  final String safetyNotes;
  final int accentIndex;
  final DateTime createdAt;

  int get totalWeeks => weeks.length;

  int get totalSessions => weeks.fold<int>(0, (sum, w) => sum + w.days.length);

  int get totalExercises => weeks.fold<int>(
        0,
        (sum, w) => sum + w.days.fold<int>(0, (s, d) => s + d.exercises.length),
      );

  /// إجمالي الدقائق التقديرية للبرنامج.
  int get totalMinutes => weeks.fold<int>(
        0,
        (sum, w) => sum + w.days.fold<int>(0, (s, d) => s + d.durationMinutes),
      );

  TrainingDay? dayAt(int weekIndex, int dayIndex) {
    if (weekIndex < 0 || weekIndex >= weeks.length) return null;
    final days = weeks[weekIndex].days;
    if (dayIndex < 0 || dayIndex >= days.length) return null;
    return days[dayIndex];
  }

  TrainingProgram copyWith({
    String? id,
    int? accentIndex,
    List<TrainingWeek>? weeks,
  }) {
    return TrainingProgram(
      id: id ?? this.id,
      sport: sport,
      level: level,
      goal: goal,
      weeks: weeks ?? this.weeks,
      summary: summary,
      tips: tips,
      equipmentNeeded: equipmentNeeded,
      safetyNotes: safetyNotes,
      accentIndex: accentIndex ?? this.accentIndex,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sport': sport,
        'level': level.id,
        'goal': goal.id,
        'summary': summary,
        'tips': tips,
        'equipmentNeeded': equipmentNeeded,
        'safetyNotes': safetyNotes,
        'accentIndex': accentIndex,
        'createdAt': createdAt.toIso8601String(),
        'weeks': weeks.map((w) => w.toJson()).toList(),
      };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    return TrainingProgram(
      id: safeString(
        json['id'],
        fallback: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
      sport: safeString(json['sport'], fallback: 'رياضة'),
      level: FitnessLevel.fromId(json['level'] as String?),
      goal: TrainingGoal.fromId(json['goal'] as String?),
      summary: safeString(json['summary']),
      tips: safeStringList(json['tips']),
      equipmentNeeded: safeStringList(json['equipmentNeeded']),
      safetyNotes: safeString(json['safetyNotes']),
      accentIndex: safeInt(json['accentIndex']),
      createdAt:
          DateTime.tryParse(safeString(json['createdAt'])) ?? DateTime.now(),
      weeks: safeMapList(json['weeks'])
          .map(TrainingWeek.fromJson)
          .toList(growable: false),
    );
  }
}

// ---------------------------------------------------------------------------
// أدوات تحويل آمنة — تحمي التطبيق من أي رد غير متوقع من الذكاء الاصطناعي.
// ---------------------------------------------------------------------------

String safeString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int safeInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final digits = value.toString().replaceAll(RegExp('[^0-9]'), '');
  return int.tryParse(digits) ?? fallback;
}

List<Map<String, dynamic>> safeMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .toList(growable: false);
}

List<String> safeStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
