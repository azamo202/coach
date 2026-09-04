/// بناء الـ prompt — نسخة مطابقة لما في التطبيق (lib/data/services/prompt_builder.dart)
/// حتى يكون الناتج واحداً سواء وُلّد من الجوال مباشرة أو عبر السيرفر.

const LEVELS = {
  beginner: {
    label: 'مبتدئ',
    weeks: 4,
    sessions: 3,
    brief:
      'مبتدئ تماماً: ركّز على إتقان الحركة الأساسية، أحجام تدريب منخفضة، ' +
      'شدة 50-65%، راحة طويلة بين المجموعات (60-90 ثانية)، تمارين بوزن الجسم ' +
      'أو أوزان خفيفة، وتجنّب الحركات المركّبة المعقدة أو القفزات العنيفة.',
  },
  intermediate: {
    label: 'متوسط',
    weeks: 6,
    sessions: 4,
    brief:
      'متوسط: تمارين مركّبة ومهارات نوعية للرياضة، شدة 65-80%، راحة 45-90 ثانية، ' +
      'إدخال تدرّج في الحمل أسبوعياً (progressive overload)، ومزج بين القوة ' +
      'والتحمل والمهارة.',
  },
  advanced: {
    label: 'محترف',
    weeks: 8,
    sessions: 5,
    brief:
      'محترف: أحجام تدريب عالية وتقسيم دوري (periodization)، شدة 80-95%، ' +
      'تقنيات متقدمة مثل التدريب العنقودي والبليومترك والتباين، مؤشرات أداء ' +
      'دقيقة، وأسبوع تفريغ (deload) عند الحاجة.',
  },
};

const GOALS = {
  general: 'لياقة عامة',
  strength: 'قوة',
  endurance: 'تحمّل',
  weightLoss: 'خسارة دهون',
  muscle: 'بناء عضلي',
  skill: 'مهارات الرياضة',
  speed: 'سرعة وانفجارية',
};

export const SYSTEM_PROMPT =
  'أنت مدرب رياضي محترف ومختص في علوم التدريب الرياضي وفسيولوجيا الجهد. ' +
  'تبني برامج تدريبية آمنة ومتدرجة ومبنية على مبادئ علمية معتبرة ' +
  '(التدرّج في الحمل، التخصص، الاستشفاء، التنويع). ' +
  'ترد دائماً بصيغة JSON صالحة فقط، بدون أي نص خارج الـ JSON، ' +
  'وبدون علامات Markdown أو أسوار كود. كل النصوص باللغة العربية الفصحى ' +
  'المبسّطة والواضحة.';

const SCHEMA = `{
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
}`;

export function levelInfo(levelId) {
  return LEVELS[levelId] || LEVELS.beginner;
}

export function buildPrompt(request) {
  const level = levelInfo(request.level);
  const weeks = request.weeks || level.weeks;
  const sessions = request.sessionsPerWeek || level.sessions;
  const goalLabel = GOALS[request.goal] || GOALS.general;

  const lines = [
    'ابنِ برنامجاً تدريبياً مخصصاً بالمواصفات التالية:',
    '',
    `الرياضة: ${request.sport}`,
    `مستوى المتدرب: ${level.label}`,
    `توصيف المستوى: ${level.brief}`,
    `الهدف الأساسي: ${goalLabel}`,
    `مدة البرنامج: ${weeks} أسابيع`,
    `عدد الجلسات في الأسبوع: ${sessions} جلسات بالضبط`,
  ];

  if (request.profileBrief) lines.push(`بيانات المتدرب: ${request.profileBrief}`);
  if (request.healthBrief) {
    lines.push(`بيانات نشاطه من تطبيق الصحة: ${request.healthBrief}`);
  }
  if (request.equipmentAvailable) {
    lines.push(`الأدوات المتاحة له: ${request.equipmentAvailable}`);
  }
  if (request.notes) {
    lines.push(`ملاحظات وقيود يجب احترامها: ${request.notes}`);
  }

  lines.push(
    '',
    'قواعد إلزامية:',
    '1. يجب أن يكون البرنامج متدرجاً فعلياً: كل أسبوع أصعب من الذي قبله في ' +
      'الحجم أو الشدة أو تعقيد الحركة، مع بيان ذلك في حقل intensity.',
    `2. التمارين يجب أن تكون نوعية لرياضة "${request.sport}" تحديداً، وليست ` +
      'تمارين صالة عامة، مع دمج المهارات الخاصة بها.',
    `3. صعوبة البرنامج يجب أن تطابق مستوى "${level.label}" بدقة، ولا تعطِ ` +
      'المبتدئ تمارين المحترف ولا العكس.',
    '4. حقل howTo يجب أن يشرح طريقة الأداء خطوة بخطوة في جملتين إلى أربع ' +
      'جمل واضحة، بحيث يستطيع المتدرب تنفيذ الحركة بشكل صحيح دون مدرب.',
    '5. كل جلسة تحتوي على 4 إلى 6 تمارين، وتشمل إحماءً وتهدئة مختصرين.',
    '6. أعد عدد الأسابيع والجلسات المطلوب بالضبط، لا أكثر ولا أقل.',
    '',
    'أعد JSON فقط بهذا الشكل بالضبط:',
    SCHEMA,
    '',
    'لا تكتب أي شيء قبل الـ JSON أو بعده.',
  );

  return lines.join('\n');
}

/// يستخرج كائن JSON من رد قد يحتوي على أسوار كود أو شرح زائد.
export function extractJson(raw) {
  let text = String(raw || '')
    .replaceAll('```json', '')
    .replaceAll('```JSON', '')
    .replaceAll('```', '')
    .trim();

  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;

  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}
