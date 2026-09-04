import '../models/fitness_level.dart';

/// طلب توليد برنامج تدريبي.
class ProgramRequest {
  const ProgramRequest({
    required this.sport,
    required this.level,
    this.goal = TrainingGoal.general,
    this.weeks,
    this.sessionsPerWeek,
    this.profileBrief = '',
    this.healthBrief = '',
    this.notes = '',
    this.equipmentAvailable = '',
  });

  final String sport;
  final FitnessLevel level;
  final TrainingGoal goal;
  final int? weeks;
  final int? sessionsPerWeek;
  final String profileBrief;
  final String healthBrief;
  final String notes;
  final String equipmentAvailable;

  int get resolvedWeeks => weeks ?? level.defaultWeeks;

  int get resolvedSessions => sessionsPerWeek ?? level.defaultSessionsPerWeek;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sport': sport,
        'level': level.id,
        'goal': goal.id,
        'weeks': resolvedWeeks,
        'sessionsPerWeek': resolvedSessions,
        'profileBrief': profileBrief,
        'healthBrief': healthBrief,
        'notes': notes,
        'equipmentAvailable': equipmentAvailable,
      };
}

/// يبني الـ prompt المُرسل إلى Claude.
///
/// نفس المنطق مطبَّق في الباك إند (`backend/src/lib/prompt.js`) حتى يبقى
/// الناتج متطابقاً سواء وُلّد من التطبيق مباشرة أو عبر السيرفر.
class PromptBuilder {
  const PromptBuilder._();

  static const String systemPrompt =
      'أنت مدرب رياضي محترف ومختص في علوم التدريب الرياضي وفسيولوجيا الجهد. '
      'تبني برامج تدريبية آمنة ومتدرجة ومبنية على مبادئ علمية معتبرة '
      '(التدرّج في الحمل، التخصص، الاستشفاء، التنويع). '
      'ترد دائماً بصيغة JSON صالحة فقط، بدون أي نص خارج الـ JSON، '
      'وبدون علامات Markdown أو أسوار كود. كل النصوص باللغة العربية الفصحى '
      'المبسّطة والواضحة.';

  static String build(ProgramRequest request) {
    final weeks = request.resolvedWeeks;
    final sessions = request.resolvedSessions;

    final buffer = StringBuffer()
      ..writeln('ابنِ برنامجاً تدريبياً مخصصاً بالمواصفات التالية:')
      ..writeln()
      ..writeln('الرياضة: ${request.sport}')
      ..writeln('مستوى المتدرب: ${request.level.label}')
      ..writeln('توصيف المستوى: ${request.level.coachingBrief}')
      ..writeln('الهدف الأساسي: ${request.goal.label}')
      ..writeln('مدة البرنامج: $weeks أسابيع')
      ..writeln('عدد الجلسات في الأسبوع: $sessions جلسات بالضبط');

    if (request.profileBrief.trim().isNotEmpty) {
      buffer.writeln('بيانات المتدرب: ${request.profileBrief.trim()}');
    }
    if (request.healthBrief.trim().isNotEmpty) {
      buffer.writeln(
          'بيانات نشاطه من تطبيق الصحة: ${request.healthBrief.trim()}',);
    }
    if (request.equipmentAvailable.trim().isNotEmpty) {
      buffer
          .writeln('الأدوات المتاحة له: ${request.equipmentAvailable.trim()}');
    }
    if (request.notes.trim().isNotEmpty) {
      buffer.writeln('ملاحظات وقيود يجب احترامها: ${request.notes.trim()}');
    }

    buffer
      ..writeln()
      ..writeln('قواعد إلزامية:')
      ..writeln(
        '1. يجب أن يكون البرنامج متدرجاً فعلياً: كل أسبوع أصعب من الذي قبله '
        'في الحجم أو الشدة أو تعقيد الحركة، مع بيان ذلك في حقل intensity.',
      )
      ..writeln(
        '2. التمارين يجب أن تكون نوعية لرياضة "${request.sport}" تحديداً، '
        'وليست تمارين صالة عامة، مع دمج المهارات الخاصة بها.',
      )
      ..writeln(
        '3. صعوبة البرنامج يجب أن تطابق مستوى "${request.level.label}" بدقة، '
        'ولا تعطِ المبتدئ تمارين المحترف ولا العكس.',
      )
      ..writeln(
        '4. حقل howTo يجب أن يشرح طريقة الأداء خطوة بخطوة في جملتين إلى '
        'أربع جمل واضحة، بحيث يستطيع المتدرب تنفيذ الحركة بشكل صحيح دون مدرب.',
      )
      ..writeln(
        '5. كل جلسة تحتوي على 4 إلى 6 تمارين، وتشمل إحماءً وتهدئة مختصرين.',
      )
      ..writeln('6. أعد عدد الأسابيع والجلسات المطلوب بالضبط، لا أكثر ولا أقل.')
      ..writeln()
      ..writeln('أعد JSON فقط بهذا الشكل بالضبط:')
      ..writeln(_schema)
      ..writeln()
      ..writeln('لا تكتب أي شيء قبل الـ JSON أو بعده.');

    return buffer.toString();
  }

  static const String _schema = '''
{
  "sport": "اسم الرياضة بالعربي",
  "summary": "فقرة قصيرة تشرح فلسفة البرنامج وما سيحققه المتدرب",
  "safetyNotes": "تنبيهات سلامة خاصة بهذه الرياضة وهذا المستوى",
  "equipmentNeeded": ["أداة", "أداة"],
  "tips": ["نصيحة عملية", "نصيحة عملية", "نصيحة عملية"],
  "weeks": [
    {
      "title": "عنوان مرحلة الأسبوع",
      "focus": "محور تركيز الأسبوع",
      "intensity": "وصف الشدة والحجم مقارنة بالأسبوع السابق",
      "days": [
        {
          "label": "اسم الجلسة",
          "focus": "محور الجلسة",
          "durationMinutes": 50,
          "warmUp": "وصف الإحماء في جملة",
          "coolDown": "وصف التهدئة في جملة",
          "exercises": [
            {
              "name": "اسم التمرين",
              "sets": 4,
              "reps": "12",
              "restSeconds": 60,
              "tempo": "2-0-2",
              "targetMuscles": "العضلات المستهدفة",
              "equipment": "الأداة المطلوبة أو بدون أدوات",
              "howTo": "شرح طريقة الأداء خطوة بخطوة",
              "cue": "نصيحة تنفيذ قصيرة"
            }
          ]
        }
      ]
    }
  ]
}''';
}
