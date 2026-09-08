/**
 * كتالوج خطط الاشتراك.
 *
 * هذا الملف هو **المصدر الوحيد للحقيقة** بخصوص ما يشتريه المستخدم وما يحصل
 * عليه. الأسعار هنا للعرض والتوثيق فقط — السعر الفعلي الذي يُحصَّل هو ما
 * تعرضه App Store Connect دائماً، ولا يُقرأ من هنا إطلاقاً.
 *
 * معرّفات المنتجات قابلة للتجاوز من البيئة حتى يمكن تغيير التسمية في
 * App Store Connect دون نشر إصدار جديد من الخادم.
 */

/** عدد البرامج غير المحدود. */
export const UNLIMITED = -1;

/**
 * حالة «بلا اشتراك».
 *
 * ليست خطة يُنتفع بها: التطبيق مقفول بالكامل خلف الاشتراك، فلا توليد ولا
 * استشارة قبل الشراء. تبقى مُعرَّفة هنا لأنها الحالة الافتراضية لكل حساب،
 * ولأن جعل الحدود بيانات لا شروطاً متناثرة يبقي فتح تجربة مجانية لاحقاً
 * تعديلَ رقمين في هذا الملف لا مطاردةَ شروط في الشيفرة.
 */
export const FREE_PLAN = Object.freeze({
  id: 'free',
  productId: null,
  rank: 0,
  title: 'بلا اشتراك',
  subtitle: 'الاشتراك مطلوب لبناء برامجك التدريبية',
  programSlots: 0,
  lifetimeGenerations: 0,
  coachAdvice: false,
  period: null,
  priceUsd: 0,
});

function productId(envKey, fallback) {
  const value = (process.env[envKey] || '').trim();
  return value || fallback;
}

/** الخطط المدفوعة مرتّبة من الأدنى إلى الأعلى. */
export function paidPlans() {
  return [
    Object.freeze({
      id: 'single_monthly',
      productId: productId('APPLE_PRODUCT_SINGLE_MONTHLY', 'com.coachmint.sub.single.monthly'),
      rank: 1,
      title: 'برنامج واحد',
      subtitle: 'برنامج تدريبي نشط واحد، بدّله وقت ما تبي',
      programSlots: 1,
      lifetimeGenerations: UNLIMITED,
      coachAdvice: true,
      period: 'monthly',
      priceUsd: 10,
    }),
    Object.freeze({
      id: 'trio_monthly',
      productId: productId('APPLE_PRODUCT_TRIO_MONTHLY', 'com.coachmint.sub.trio.monthly'),
      rank: 2,
      title: 'ثلاثة برامج',
      subtitle: 'ثلاث رياضات بالتوازي في نفس الوقت',
      programSlots: 3,
      lifetimeGenerations: UNLIMITED,
      coachAdvice: true,
      period: 'monthly',
      priceUsd: 20,
    }),
    Object.freeze({
      id: 'unlimited_yearly',
      productId: productId('APPLE_PRODUCT_UNLIMITED_YEARLY', 'com.coachmint.sub.unlimited.yearly'),
      rank: 3,
      title: 'برامج بلا حدود',
      subtitle: 'كل الرياضات، سنة كاملة',
      programSlots: UNLIMITED,
      lifetimeGenerations: UNLIMITED,
      coachAdvice: true,
      period: 'yearly',
      priceUsd: 100,
    }),
  ];
}

export function allPlans() {
  return [FREE_PLAN, ...paidPlans()];
}

/** يجد الخطة المقابلة لمعرّف منتج Apple، أو `null` إن كان غير معروف. */
export function planByProductId(id) {
  if (!id) return null;
  return paidPlans().find((plan) => plan.productId === id) || null;
}

export function planById(id) {
  return allPlans().find((plan) => plan.id === id) || null;
}

/** كل معرّفات المنتجات التي يعرفها الخادم. */
export function knownProductIds() {
  return paidPlans().map((plan) => plan.productId);
}

/** يختار الخطة الأعلى بين خطتين — يُستخدم عند وجود اشتراكات متداخلة. */
export function higherPlan(a, b) {
  if (!a) return b;
  if (!b) return a;
  return a.rank >= b.rank ? a : b;
}
