import 'fitness_level.dart';

/// المستخدم المسجَّل في التطبيق.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.level = FitnessLevel.beginner,
    this.goal = TrainingGoal.general,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.hasCompletedOnboarding = false,
    this.healthSyncEnabled = false,
    this.appAccountToken,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final FitnessLevel level;
  final TrainingGoal goal;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final bool hasCompletedOnboarding;
  final bool healthSyncEnabled;

  /// رمز يربط عمليات الشراء في StoreKit بهذا الحساب.
  ///
  /// يولّده الخادم كـUUID لأن Apple لا تقبل غيره في `appAccountToken`،
  /// ثم تعيده لنا داخل العملية الموقّعة فيثبت أن الشراء يخصّ هذا الحساب.
  final String? appAccountToken;

  final DateTime? createdAt;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) {
      return parts.first.safeFirst();
    }
    return '${parts[0].safeFirst()}${parts[1].safeFirst()}';
  }

  /// ملخّص يُمرَّر للذكاء الاصطناعي لتخصيص البرنامج.
  String get profileBrief {
    final buffer = StringBuffer();
    if (age != null) buffer.write('العمر: $age سنة. ');
    if (gender != null && gender!.isNotEmpty) buffer.write('الجنس: $gender. ');
    if (weightKg != null) {
      buffer.write('الوزن: ${weightKg!.toStringAsFixed(0)} كجم. ');
    }
    if (heightCm != null) {
      buffer.write('الطول: ${heightCm!.toStringAsFixed(0)} سم. ');
    }
    return buffer.toString().trim();
  }

  AppUser copyWith({
    String? name,
    String? email,
    FitnessLevel? level,
    TrainingGoal? goal,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    bool? hasCompletedOnboarding,
    bool? healthSyncEnabled,
    String? appAccountToken,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
      appAccountToken: appAccountToken ?? this.appAccountToken,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'level': level.id,
        'goal': goal.id,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'gender': gender,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'healthSyncEnabled': healthSyncEnabled,
        'appAccountToken': appAccountToken,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      level: FitnessLevel.fromId(json['level'] as String?),
      goal: TrainingGoal.fromId(json['goal'] as String?),
      age: _asInt(json['age']),
      weightKg: _asDouble(json['weightKg']),
      heightCm: _asDouble(json['heightCm']),
      gender: json['gender'] as String?,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
      healthSyncEnabled: json['healthSyncEnabled'] == true,
      appAccountToken: (json['appAccountToken'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['appAccountToken'] as String).trim(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

extension _FirstChar on String {
  String safeFirst() => isEmpty ? '' : substring(0, 1);
}
