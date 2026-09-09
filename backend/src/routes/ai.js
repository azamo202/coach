import 'dotenv/config';
import OpenAI from 'openai';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

import crypto from 'node:crypto';

import { requireAuth } from '../lib/auth.js';
import { logAiUsage } from '../lib/db.js';
import {
  canAskCoach,
  canCreateProgram,
  consumeFreeGeneration,
  entitlementSync,
  recordGeneration,
} from '../lib/subscriptions.js';
import { generateMockProgram } from '../lib/mock_program.js';
import { SYSTEM_PROMPT, buildPrompt, extractJson, levelInfo } from '../lib/prompt.js';

export const aiRouter = Router();

// إعداد عميل OpenAI واستراتيجية النماذج بشكل آمن وديناميكي
let _openaiInstance = null;
function getOpenAiClient() {
  if (!_openaiInstance) {
    const key = process.env.OPENAI_API_KEY;
    if (!key) {
      throw new Error('OPENAI_API_KEY is not configured in backend environment.');
    }
    _openaiInstance = new OpenAI({ apiKey: key, timeout: 120000 });
  }
  return _openaiInstance;
}

const PROGRAM_MODEL =
  process.env.OPENAI_PROGRAM_MODEL || process.env.OPENAI_MODEL || 'gpt-5-mini';
const COACH_MODEL =
  process.env.OPENAI_COACH_MODEL || process.env.OPENAI_MODEL || 'gpt-5-mini';

// ---------------------------------------------------------------------
// مخططات التحقق (Zod Schemas) — المدخلات والمخرجات
// ---------------------------------------------------------------------

const programRequestSchema = z.object({
  sport: z.string().trim().min(2, 'اسم الرياضة يجب أن يكون حرفين على الأقل').max(60),
  level: z.enum(['beginner', 'intermediate', 'advanced']),
  goal: z
    .enum(['general', 'strength', 'endurance', 'weightLoss', 'muscle', 'skill', 'speed'])
    .default('general'),
  weeks: z.number().int().min(1).max(16).optional(),
  sessionsPerWeek: z.number().int().min(1).max(7).optional(),
  profileBrief: z.string().max(500).optional().default(''),
  healthBrief: z.string().max(500).optional().default(''),
  notes: z.string().max(600).optional().default(''),
  equipmentAvailable: z.string().max(300).optional().default(''),
});

const exerciseSchema = z.object({
  name: z.string().min(1),
  sets: z.coerce.number().int().min(1).max(20).default(3),
  reps: z.union([z.string(), z.number()]).transform((v) => String(v)),
  restSeconds: z.coerce.number().int().min(0).max(600).default(60),
  tempo: z.string().optional().default(''),
  targetMuscles: z.string().optional().default(''),
  equipment: z.string().optional().default(''),
  howTo: z.string().min(1),
  cue: z.string().optional().default(''),
});

const daySchema = z.object({
  label: z.string().min(1),
  focus: z.string().optional().default(''),
  durationMinutes: z.coerce.number().int().min(10).max(240).default(50),
  warmUp: z.string().optional().default(''),
  coolDown: z.string().optional().default(''),
  exercises: z.array(exerciseSchema).min(1),
});

const weekSchema = z.object({
  title: z.string().min(1),
  focus: z.string().optional().default(''),
  intensity: z.string().optional().default(''),
  days: z.array(daySchema).min(1),
});

const programOutputSchema = z.object({
  sport: z.string().optional(),
  summary: z.string().optional().default(''),
  safetyNotes: z.string().optional().default(''),
  equipmentNeeded: z.array(z.string()).optional().default([]),
  tips: z.array(z.string()).optional().default([]),
  weeks: z.array(weekSchema).min(1),
});

const coachAdviceInputSchema = z.object({
  question: z.string().trim().min(2).max(500),
  exercise: z
    .object({
      name: z.string().min(1),
      sets: z.number().optional(),
      reps: z.union([z.string(), z.number()]).optional(),
      targetMuscles: z.string().optional(),
      equipment: z.string().optional(),
    })
    .optional(),
  userContext: z
    .object({
      sport: z.string().optional(),
      level: z.string().optional(),
      goal: z.string().optional(),
      injuries: z.string().optional(),
    })
    .optional(),
});

const coachAdviceOutputSchema = z.object({
  answer: z.string().min(1),
  recommendation: z.string().min(1),
  alternativeExercise: z.string().optional().default(''),
  warning: z.string().nullable().optional().default(null),
});

// ---------------------------------------------------------------------
// حدود الاستخدام (Rate Limiting)
// ---------------------------------------------------------------------

const generateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: {
    code: 'rate_limited',
    message: 'وصلت للحد الأقصى لتوليد البرامج لهذه الساعة. جرّب لاحقاً.',
  },
});

const adviceLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 40,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: {
    code: 'rate_limited',
    message: 'وصلت للحد الأقصى لاستشارات المدرب لهذه الساعة. جرّب بعد قليل.',
  },
});

// ---------------------------------------------------------------------
// بوابات الاشتراك
// ---------------------------------------------------------------------
//
// التحقق من الصلاحية يقع هنا، على الخادم، وقبل أي نداء مدفوع للذكاء
// الاصطناعي. أي بوابة في التطبيق وحده قابلة للتجاوز، ولا تحمي التكلفة.
//
// نستخدم 402 لا 403: عميل التطبيق يعامل 401 و403 كانتهاء جلسة ويخرج
// المستخدم، ونحن هنا لا نريد إخراجه بل عرض صفحة الاشتراك.

function subscriptionBlocked(res, gate) {
  const { plan, activePrograms, isSubscribed } = gate.entitlement;
  return res.status(402).json({
    code: gate.code,
    message: gate.message,
    entitlement: {
      planId: plan.id,
      isSubscribed,
      programSlots: plan.programSlots,
      activePrograms,
    },
  });
}

/// يمنع توليد برنامج جديد إذا استُهلكت الحصة أو انتهى الاشتراك.
function requireProgramSlot(req, res, next) {
  const gate = canCreateProgram(req.user.id);
  if (gate.allowed) return next();
  return subscriptionBlocked(res, gate);
}

/// استشارة المدرّب الذكي ميزة للمشتركين.
function requireCoachAccess(req, res, next) {
  const gate = canAskCoach(req.user.id);
  if (gate.allowed) return next();
  return subscriptionBlocked(res, gate);
}

// ---------------------------------------------------------------------
// آلية إعادة المحاولة مع Exponential Backoff للأخطاء العابرة
// ---------------------------------------------------------------------

async function callOpenAiWithRetry(apiCall, maxRetries = 2) {
  let attempt = 0;
  while (attempt <= maxRetries) {
    try {
      return await apiCall();
    } catch (error) {
      attempt++;
      const status = error?.status;
      const isTransient =
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        error?.code === 'ETIMEDOUT' ||
        error?.code === 'ECONNRESET' ||
        error?.name === 'APIConnectionTimeoutError';

      if (!isTransient || attempt > maxRetries) {
        throw error;
      }

      const delay = attempt * 1200;
      console.warn(`[OpenAI Retry] محاولة ${attempt} بعد ${delay}ms... الخطأ: ${error?.message}`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

/**
 * يحجز حصة للبرنامج المولَّد ويعيد معرّفه.
 *
 * المعرّف يُولَّد هنا لا في التطبيق: هو مفتاح الحصة، ولا يجوز أن يختاره
 * الطرف الذي تُحسب عليه الحصة.
 */
function claimSlot(userId, sport) {
  const programId = `prog_${crypto.randomUUID()}`;
  recordGeneration({
    userId,
    programId,
    sport,
    planId: entitlementSync(userId).plan.id,
  });
  return programId;
}

// ---------------------------------------------------------------------
// وضع المحاكاة — للتطوير وحده
// ---------------------------------------------------------------------

/**
 * هل نعمل بمولّد القوالب بدل الذكاء الاصطناعي؟
 *
 * الشرط **صريح** عمداً: `MOCK_AI=true` فقط. كان الشرط سابقاً يشمل «غياب
 * `OPENAI_API_KEY`»، وهذا أخطر إعداد ممكن في الإنتاج: مفتاح ناقص على
 * الخادم يعني أن كل مشترك يدفع مقابل «برنامج يبنيه الذكاء الاصطناعي»
 * فيستلم قالباً ثابتاً — ويحرق حصةً حقيقية من خطته. لا خطأ يظهر، ولا سجل
 * يشتكي، والمراجع في App Store يرى استشارة مدرّب واحدة مكرّرة حرفياً على
 * كل سؤال يسأله. عيب الإعداد يجب أن يظهر كعطل صريح، لا كخدمة مزيّفة.
 */
export function isMockAiEnabled() {
  return process.env.MOCK_AI === 'true' && process.env.NODE_ENV !== 'production';
}

/** هل مفتاح الذكاء الاصطناعي حاضر فعلاً؟ */
export function isAiConfigured() {
  const key = (process.env.OPENAI_API_KEY || '').trim();
  return Boolean(key) && !key.includes('xxxx');
}

/**
 * يردّ بعطل صريح حين ينقص إعداد الذكاء الاصطناعي.
 *
 * 503 لا 500: هذا عطل مؤقّت في الخدمة يُصلحه المشغّل، والتطبيق يعرض
 * للمستخدم زرّ «حاول مرة ثانية» بدل رسالة نهائية. ولا حصة تُستهلك —
 * `claimSlot` لم يُستدعَ بعد.
 */
function aiUnavailable(res, userId, feature) {
  console.error(
    `[AI] مفتاح OPENAI_API_KEY غير مهيّأ — رفضنا طلب ${feature}. ` +
      'لا تُشغّل الإنتاج بلا مفتاح.',
  );
  logAiUsage({ userId, feature, model: 'unconfigured', status: 'error', errorCode: 'ai_unavailable' });
  return res.status(503).json({
    code: 'ai_unavailable',
    message: 'خدمة المدرّب الذكي غير متاحة الآن. حاول بعد قليل.',
  });
}

// ---------------------------------------------------------------------
// 1. مسار توليد البرنامج التدريبي (POST /ai/program)
// ---------------------------------------------------------------------

aiRouter.post('/program', requireAuth, generateLimiter, requireProgramSlot, async (req, res) => {
  const parsed = programRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      code: 'bad_request',
      message: 'بيانات الطلب غير مكتملة أو غير صحيحة.',
      errors: parsed.error.issues,
    });
  }

  const request = parsed.data;
  const level = levelInfo(request.level);
  const userId = req.user.id;

  if (!isMockAiEnabled() && !isAiConfigured()) {
    return aiUnavailable(res, userId, 'program_generation');
  }

  if (isMockAiEnabled()) {
    console.log(`[AI Mock] توليد برنامج تدريبي لرياضة: ${request.sport} (${level.label})`);
    const program = generateMockProgram(request);
    logAiUsage({
      userId,
      feature: 'program_generation',
      model: 'mock-generator',
      status: 'success',
    });
    consumeFreeGeneration(userId);
    program.id = claimSlot(userId, request.sport);
    return res.json({
      program,
      meta: {
        model: 'coachmint-smart-generator (mock)',
        level: level.label,
        weeks: program.weeks.length,
      },
    });
  }

  try {
    const promptContent = buildPrompt(request);

    const response = await callOpenAiWithRetry(() =>
      getOpenAiClient().chat.completions.create({
        model: PROGRAM_MODEL,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: promptContent },
        ],
        max_completion_tokens: 12000,
      }),
    );

    const text = response.choices?.[0]?.message?.content || '';
    const rawProgram = extractJson(text);

    if (!rawProgram) {
      logAiUsage({
        userId,
        feature: 'program_generation',
        model: PROGRAM_MODEL,
        status: 'failed',
        errorCode: 'ai_bad_json',
      });
      return res.status(502).json({
        code: 'ai_bad_format',
        message: 'وصلنا رد غير مكتمل من المدرب الذكي. جرّب مرة ثانية.',
      });
    }

    // التحقق الصارم من صحة هيكل البرنامج بواسطة Zod
    const validatedOutput = programOutputSchema.safeParse(rawProgram);
    if (!validatedOutput.success) {
      console.error('Program schema validation failed:', validatedOutput.error.issues);
      logAiUsage({
        userId,
        feature: 'program_generation',
        model: PROGRAM_MODEL,
        status: 'failed',
        errorCode: 'schema_validation_failed',
      });
      return res.status(502).json({
        code: 'ai_bad_format',
        message: 'مواصفات البرنامج المولّد لم تطابق المعايير التدريبية. أعد المحاولة.',
      });
    }

    const program = validatedOutput.data;
    program.sport = program.sport || request.sport;
    program.level = request.level;
    program.goal = request.goal;

    // تسجيل استهلاك التوكنات
    const usage = response.usage || {};
    logAiUsage({
      userId,
      feature: 'program_generation',
      model: PROGRAM_MODEL,
      promptTokens: usage.prompt_tokens || 0,
      completionTokens: usage.completion_tokens || 0,
      totalTokens: usage.total_tokens || 0,
      status: 'success',
    });

    // الحصة تُخصم بعد نجاح التوليد فقط: فشل الطلب لا يحرق تجربة المستخدم.
    consumeFreeGeneration(userId);
    program.id = claimSlot(userId, request.sport);

    res.json({
      program,
      meta: {
        model: PROGRAM_MODEL,
        level: level.label,
        weeks: program.weeks.length,
      },
    });
  } catch (error) {
    console.error('OpenAI program generation failed:', error?.message || error);

    logAiUsage({
      userId,
      feature: 'program_generation',
      model: PROGRAM_MODEL,
      status: 'failed',
      errorCode: error?.code || error?.status?.toString() || 'unknown',
    });

    const isRateLimited = error?.status === 429;
    res.status(isRateLimited ? 429 : 502).json({
      code: isRateLimited ? 'rate_limited' : 'ai_failed',
      message: isRateLimited
        ? 'الخدمة الذكية مزدحمة حالياً. انتظر دقيقة ثم حاول مجدداً.'
        : 'تعذّر إعداد البرنامج التدريبي في الوقت الحالي. حاول مجدداً بعد لحظات.',
    });
  }
});

// ---------------------------------------------------------------------
// 2. مسار استشارة المدرب الذكي (POST /ai/coach-advice)
// ---------------------------------------------------------------------

const COACH_SYSTEM_PROMPT = `أنت المدرب الذكي الرسمي في تطبيق CoachMint (خبير في فسيولوجيا التمارين والتكنيك الرياضي والأداء الحركي).
مهمتك: تقديم نصائح تدريبية وتكنيكية عملية وموجزة ومباشرة باللغة العربية الفصحى المبسطة لمساعدة المتدرب.

قواعد السلامة الطبية الصارمة (إلزامية):
1. لست طبيباً، ولا تقدم أي تشخيص طبي إطلاقاً.
2. إذا كان السؤال يشير إلى ألم حاد، طقطقة مصحوبة بوجع، تنميل، أو اشتباه إصابة: يجب فوراً تضمين تنبيه واضح في حقل warning ينصح بالتوقف الفوري عن التمرين واستشارة طبيب أو أخصائي علاج طبيعي.
3. قدم بديلاً آمناً للتمرين في حقل alternativeExercise (مثلاً بدون أجهزة، أو بوزن الجسم، أو حركة ذات حمل أخف على المفصل).
4. املأ حقل recommendation بنصيحة تنفيذية مركزة (تعديل وضعية القدمين، التنفس، تخفيف الحمل).

يجب أن يكون الرد دائماً بصيغة JSON صالحة فقط بالحقول التالية:
{
  "answer": "شرح مباشر لسؤال المتدرب وسبب ما يشعر به من زاوية التكنيك والحمل التدريبي",
  "recommendation": "نصيحة عملية لتصحيح الأداء أو الحمل",
  "alternativeExercise": "اسم تمرين بديل آمن (إذا دعت الحاجة أو طلب بديلاً)",
  "warning": "تنبيه طبي وقائي عند وجود ألم أو null إن لم يكن هناك خطر"
}`;

aiRouter.post('/coach-advice', requireAuth, adviceLimiter, requireCoachAccess, async (req, res) => {
  const parsed = coachAdviceInputSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      code: 'bad_request',
      message: 'بيانات الاستشارة غير صالحة.',
      errors: parsed.error.issues,
    });
  }

  const { question, exercise, userContext } = parsed.data;
  const userId = req.user.id;

  if (!isMockAiEnabled() && !isAiConfigured()) {
    return aiUnavailable(res, userId, 'coach_advice');
  }

  if (isMockAiEnabled()) {
    return res.json({
      advice: {
        answer: 'احرص على أداء الحركة بمدى حركي مريح ولا تقفل المفاصل في نهاية الدفع.',
        recommendation: 'ركّز على النزول البطيء (ثانيتين) والتنفس المنتظم أثناء الأداء.',
        alternativeExercise: exercise?.name ? `بديل بوزن الجسم لـ ${exercise.name}` : '',
        warning: 'إذا كان هناك ألم مستمر، أوقف التمرين واستشر مختصاً.',
      },
    });
  }

  try {
    const userPrompt = [
      `سؤال المتدرب: ${question}`,
      exercise?.name ? `التمرين الحالي: ${exercise.name}` : null,
      exercise?.targetMuscles ? `العضلات المستهدفة: ${exercise.targetMuscles}` : null,
      exercise?.equipment ? `الأدوات: ${exercise.equipment}` : null,
      userContext?.sport ? `الرياضة: ${userContext.sport}` : null,
      userContext?.level ? `المستوى: ${userContext.level}` : null,
      userContext?.goal ? `الهدف: ${userContext.goal}` : null,
      userContext?.injuries ? `إصابات أو قيود: ${userContext.injuries}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    const response = await callOpenAiWithRetry(() =>
      getOpenAiClient().chat.completions.create({
        model: COACH_MODEL,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: COACH_SYSTEM_PROMPT },
          { role: 'user', content: userPrompt },
        ],
        max_completion_tokens: 1500,
      }),
    );

    const text = response.choices?.[0]?.message?.content || '';
    const rawAdvice = extractJson(text);

    const validatedAdvice = coachAdviceOutputSchema.safeParse(rawAdvice);
    if (!validatedAdvice.success) {
      return res.status(502).json({
        code: 'ai_bad_format',
        message: 'تعذر تنسيق نصيحة المدرب. جرّب صياغة سؤالك مجدداً.',
      });
    }

    const usage = response.usage || {};
    logAiUsage({
      userId,
      feature: 'coach_advice',
      model: COACH_MODEL,
      promptTokens: usage.prompt_tokens || 0,
      completionTokens: usage.completion_tokens || 0,
      totalTokens: usage.total_tokens || 0,
      status: 'success',
    });

    res.json({
      advice: validatedAdvice.data,
      meta: { model: COACH_MODEL },
    });
  } catch (error) {
    console.error('OpenAI coach advice failed:', error?.message || error);

    logAiUsage({
      userId,
      feature: 'coach_advice',
      model: COACH_MODEL,
      status: 'failed',
      errorCode: error?.code || error?.status?.toString() || 'unknown',
    });

    res.status(error?.status === 429 ? 429 : 502).json({
      code: 'ai_failed',
      message: 'المدرب الذكي غير متاح الآن. جرّب مرة ثانية بعد لحظات.',
    });
  }
});
