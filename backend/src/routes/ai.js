import Anthropic from '@anthropic-ai/sdk';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

import { requireAuth } from '../lib/auth.js';
import { SYSTEM_PROMPT, buildPrompt, extractJson, levelInfo } from '../lib/prompt.js';

export const aiRouter = Router();

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-6';

const requestSchema = z.object({
  sport: z.string().trim().min(2).max(60),
  level: z.enum(['beginner', 'intermediate', 'advanced']),
  goal: z
    .enum(['general', 'strength', 'endurance', 'weightLoss', 'muscle', 'skill', 'speed'])
    .default('general'),
  weeks: z.number().int().min(2).max(16).optional(),
  sessionsPerWeek: z.number().int().min(2).max(7).optional(),
  profileBrief: z.string().max(500).optional().default(''),
  healthBrief: z.string().max(500).optional().default(''),
  notes: z.string().max(600).optional().default(''),
  equipmentAvailable: z.string().max(300).optional().default(''),
});

// حد استخدام: التوليد مكلف، فنمنع الإفراط لكل مستخدم.
const generateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: {
    code: 'rate_limited',
    message: 'وصلت للحد الأقصى من التوليد هذه الساعة. جرّب بعد شوي.',
  },
});

aiRouter.post('/program', requireAuth, generateLimiter, async (req, res) => {
  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    return res
      .status(400)
      .json({ code: 'bad_request', message: 'بيانات الطلب غير صحيحة.' });
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    return res.status(500).json({
      code: 'missing_api_key',
      message: 'إعدادات الخدمة ناقصة. راجع مسؤول النظام.',
    });
  }

  const request = parsed.data;
  const level = levelInfo(request.level);

  try {
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 8000,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: buildPrompt(request) }],
    });

    const text = (response.content || [])
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('');

    const program = extractJson(text);

    if (!program || !Array.isArray(program.weeks) || program.weeks.length === 0) {
      console.error('AI returned unusable payload', text.slice(0, 400));
      return res.status(502).json({
        code: 'ai_bad_format',
        message: 'وصلنا رد غير مكتمل من المدرب الذكي. جرّب مرة ثانية.',
      });
    }

    // نضمن أن الحقول الأساسية موجودة حتى لو أهملها النموذج.
    program.sport = program.sport || request.sport;
    program.level = request.level;
    program.goal = request.goal;

    res.json({
      program,
      meta: {
        model: MODEL,
        level: level.label,
        weeks: program.weeks.length,
      },
    });
  } catch (error) {
    console.error('Anthropic request failed:', error?.message || error);
    const status = error?.status === 429 ? 429 : 502;
    res.status(status).json({
      code: 'ai_failed',
      message:
        status === 429
          ? 'الخدمة مزدحمة حالياً. جرّب بعد دقيقة.'
          : 'ما قدرنا نجهّز البرنامج الآن. جرّب مرة ثانية بعد لحظات.',
    });
  }
});
