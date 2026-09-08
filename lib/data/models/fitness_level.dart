import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// مستوى المتدرب — يحدد شكل البرنامج الذي يولّده الذكاء الاصطناعي.
enum FitnessLevel {
  beginner,
  intermediate,
  advanced;

  static FitnessLevel fromId(String? id) {
    switch (id) {
      case 'intermediate':
        return FitnessLevel.intermediate;
      case 'advanced':
        return FitnessLevel.advanced;
      default:
        return FitnessLevel.beginner;
    }
  }

  String get id => name;

  String get label {
    switch (this) {
      case FitnessLevel.beginner:
        return 'مبتدئ';
      case FitnessLevel.intermediate:
        return 'متوسط';
      case FitnessLevel.advanced:
        return 'محترف';
    }
  }

  String get description {
    switch (this) {
      case FitnessLevel.beginner:
        return 'جديد على الرياضة أو راجع بعد انقطاع طويل';
      case FitnessLevel.intermediate:
        return 'أتمرّن بانتظام من 6 أشهر إلى سنتين';
      case FitnessLevel.advanced:
        return 'خبرة تدريب طويلة وأبحث عن أداء تنافسي';
    }
  }

  /// تفاصيل تُحقن في الـ prompt لضبط صعوبة البرنامج.
  String get coachingBrief {
    switch (this) {
      case FitnessLevel.beginner:
        return 'مبتدئ تماماً: ركّز على إتقان الحركة الأساسية، أحجام تدريب '
            'منخفضة، شدة ٥٠-٦٥٪، راحة طويلة بين المجموعات (٦٠-٩٠ ثانية)، '
            'تمارين بوزن الجسم أو أوزان خفيفة، وتجنّب الحركات المركّبة المعقدة '
            'أو القفزات العنيفة.';
      case FitnessLevel.intermediate:
        return 'متوسط: تمارين مركّبة ومهارات نوعية للرياضة، شدة ٦٥-٨٠٪، '
            'راحة ٤٥-٩٠ ثانية، إدخال تدرّج في الحمل أسبوعياً (progressive '
            'overload)، ومزج بين القوة والتحمل والمهارة.';
      case FitnessLevel.advanced:
        return 'محترف: أحجام تدريب عالية وتقسيم دوري (periodization)، شدة '
            '٨٠-٩٥٪، تقنيات متقدمة مثل التدريب العنقودي والبليومترك والتباين، '
            'مؤشرات أداء دقيقة، وأسبوع تفريغ (deload) عند الحاجة.';
    }
  }

  int get defaultWeeks {
    switch (this) {
      case FitnessLevel.beginner:
        return 4;
      case FitnessLevel.intermediate:
        return 6;
      case FitnessLevel.advanced:
        return 8;
    }
  }

  int get defaultSessionsPerWeek {
    switch (this) {
      case FitnessLevel.beginner:
        return 3;
      case FitnessLevel.intermediate:
        return 4;
      case FitnessLevel.advanced:
        return 5;
    }
  }

  Color get color {
    switch (this) {
      case FitnessLevel.beginner:
        return AppColors.levelBeginner;
      case FitnessLevel.intermediate:
        return AppColors.levelIntermediate;
      case FitnessLevel.advanced:
        return AppColors.levelAdvanced;
    }
  }

  IconData get icon {
    switch (this) {
      case FitnessLevel.beginner:
        return Icons.eco_rounded;
      case FitnessLevel.intermediate:
        return Icons.trending_up_rounded;
      case FitnessLevel.advanced:
        return Icons.military_tech_rounded;
    }
  }
}

/// هدف المتدرب من البرنامج.
enum TrainingGoal {
  general,
  strength,
  endurance,
  weightLoss,
  muscle,
  skill,
  speed;

  static TrainingGoal fromId(String? id) => TrainingGoal.values.firstWhere(
        (g) => g.name == id,
        orElse: () => TrainingGoal.general,
      );

  String get id => name;

  String get label {
    switch (this) {
      case TrainingGoal.general:
        return 'لياقة عامة';
      case TrainingGoal.strength:
        return 'قوة';
      case TrainingGoal.endurance:
        return 'تحمّل';
      case TrainingGoal.weightLoss:
        return 'خسارة دهون';
      case TrainingGoal.muscle:
        return 'بناء عضلي';
      case TrainingGoal.skill:
        return 'مهارات الرياضة';
      case TrainingGoal.speed:
        return 'سرعة وانفجارية';
    }
  }

  IconData get icon {
    switch (this) {
      case TrainingGoal.general:
        return Icons.favorite_rounded;
      case TrainingGoal.strength:
        return Icons.fitness_center_rounded;
      case TrainingGoal.endurance:
        return Icons.directions_run_rounded;
      case TrainingGoal.weightLoss:
        return Icons.local_fire_department_rounded;
      case TrainingGoal.muscle:
        return Icons.accessibility_new_rounded;
      case TrainingGoal.skill:
        return Icons.sports_handball_rounded;
      case TrainingGoal.speed:
        return Icons.bolt_rounded;
    }
  }
}
