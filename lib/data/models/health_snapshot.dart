/// لقطة من بيانات الصحة (Apple HealthKit / Health Connect - Google Fit).
class HealthSnapshot {
  const HealthSnapshot({
    this.steps = 0,
    this.activeCalories = 0,
    this.workoutMinutes = 0,
    this.restingHeartRate,
    this.distanceMeters = 0,
    this.sleepHours,
    this.updatedAt,
    this.isAuthorized = false,
    this.isAvailable = true,
  });

  final int steps;
  final double activeCalories;
  final int workoutMinutes;
  final double? restingHeartRate;
  final double distanceMeters;
  final double? sleepHours;
  final DateTime? updatedAt;

  /// هل منح المستخدم صلاحية القراءة؟
  final bool isAuthorized;

  /// هل الخدمة متاحة على هذا الجهاز أصلاً؟
  final bool isAvailable;

  double get distanceKm => distanceMeters / 1000;

  bool get hasData =>
      steps > 0 ||
      activeCalories > 0 ||
      workoutMinutes > 0 ||
      distanceMeters > 0;

  static const HealthSnapshot empty = HealthSnapshot();

  HealthSnapshot copyWith({
    int? steps,
    double? activeCalories,
    int? workoutMinutes,
    double? restingHeartRate,
    double? distanceMeters,
    double? sleepHours,
    DateTime? updatedAt,
    bool? isAuthorized,
    bool? isAvailable,
  }) {
    return HealthSnapshot(
      steps: steps ?? this.steps,
      activeCalories: activeCalories ?? this.activeCalories,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      sleepHours: sleepHours ?? this.sleepHours,
      updatedAt: updatedAt ?? this.updatedAt,
      isAuthorized: isAuthorized ?? this.isAuthorized,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// ملخّص نصّي يُمرَّر للذكاء الاصطناعي ليأخذ نشاط المستخدم بالحسبان.
  String get aiBrief {
    if (!hasData) return '';
    final parts = <String>[];
    if (steps > 0) parts.add('متوسط الخطوات اليومية: $steps');
    if (activeCalories > 0) {
      parts.add('سعرات نشطة: ${activeCalories.round()} سعرة');
    }
    if (workoutMinutes > 0) {
      parts.add('دقائق تمرين مسجّلة أسبوعياً: $workoutMinutes');
    }
    if (restingHeartRate != null) {
      parts.add('نبض الراحة: ${restingHeartRate!.round()} نبضة/د');
    }
    return parts.join('، ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'steps': steps,
        'activeCalories': activeCalories,
        'workoutMinutes': workoutMinutes,
        'restingHeartRate': restingHeartRate,
        'distanceMeters': distanceMeters,
        'sleepHours': sleepHours,
        'updatedAt': updatedAt?.toIso8601String(),
        'isAuthorized': isAuthorized,
        'isAvailable': isAvailable,
      };

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) =>
        v == null ? null : double.tryParse(v.toString());
    return HealthSnapshot(
      steps: int.tryParse((json['steps'] ?? 0).toString()) ?? 0,
      activeCalories: asDouble(json['activeCalories']) ?? 0,
      workoutMinutes:
          int.tryParse((json['workoutMinutes'] ?? 0).toString()) ?? 0,
      restingHeartRate: asDouble(json['restingHeartRate']),
      distanceMeters: asDouble(json['distanceMeters']) ?? 0,
      sleepHours: asDouble(json['sleepHours']),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
      isAuthorized: json['isAuthorized'] == true,
      isAvailable: json['isAvailable'] != false,
    );
  }
}
