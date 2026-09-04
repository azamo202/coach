import 'dart:io';
import 'dart:math' as math;

import 'package:coachmint/core/theme/app_colors.dart';
import 'package:coachmint/data/models/fitness_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// حرّاس الهوية البصرية.
///
/// أي تعديل يخرج عن دليل هوية CoachMint يُسقط هذه الاختبارات.
void main() {
  group('لوحة ألوان الهوية', () {
    test('القيم مطابقة لدليل الهوية حرفياً', () {
      expect(AppColors.spruce, const Color(0xFF132420));
      expect(AppColors.spruceDeep, const Color(0xFF1B342D));
      expect(AppColors.mintLight, const Color(0xFF8BFFCB));
      expect(AppColors.mint, const Color(0xFF4FE3A6));
      expect(AppColors.mintDark, const Color(0xFF16A97A));
      expect(AppColors.coral, const Color(0xFFFF7A50));
      expect(AppColors.offWhite, const Color(0xFFF5F7F4));
      expect(AppColors.sage, const Color(0xFF8FA69B));
    });

    test('تدرّج النعناع من الفاتح إلى الغامق ولا يُعكس', () {
      expect(AppColors.mintGradient, <Color>[
        AppColors.mintLight,
        AppColors.mintDark,
      ]);
    });

    test('الخلفية والأسطح من عائلة Spruce', () {
      expect(AppColors.background, AppColors.spruce);
      expect(AppColors.surface, AppColors.spruceDeep);
    });

    test('النص فوق الأسطح النعناعية هو Spruce وليس أبيض', () {
      expect(AppColors.onPrimary, AppColors.spruce);
    });
  });

  group('تدرّجات تمييز الرياضات', () {
    test('كلها من عائلة النعناع — الأخضر هو المكوّن الأقوى', () {
      for (final gradient in AccentPalette.gradients) {
        expect(gradient.length, 2);
        for (final color in gradient) {
          expect(
            color.g,
            greaterThan(color.r),
            reason: 'لون خارج عائلة النعناع: $color',
          );
          expect(
            color.g,
            greaterThan(color.b),
            reason: 'لون خارج عائلة النعناع: $color',
          );
        }
      }
    });

    test('أول تدرّج هو تدرّج الهوية الرسمي', () {
      expect(AccentPalette.gradients.first, AppColors.mintGradient);
    });

    test('نفس اسم الرياضة يعطي نفس التدرّج دائماً', () {
      expect(
        AccentPalette.byName('كرة السلة'),
        AccentPalette.byName('كرة السلة'),
      );
    });

    test('المرجاني لا يدخل في تمييز الرياضات', () {
      for (final gradient in AccentPalette.gradients) {
        expect(gradient, isNot(contains(AppColors.coral)));
      }
    });
  });

  group('ألوان المستويات', () {
    test('تدرّج طاقة: نعناع فاتح ← نعناع ← مرجاني', () {
      expect(FitnessLevel.beginner.color, AppColors.mintLight);
      expect(FitnessLevel.intermediate.color, AppColors.mint);
      expect(FitnessLevel.advanced.color, AppColors.coral);
    });
  });

  group('قواعد الهوية في الكود', () {
    /// كل ملفات Dart تحت lib/.
    List<File> dartFiles() {
      final dir = Directory('lib');
      if (!dir.existsSync()) return <File>[];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test('لا ظلال ولا تأثيرات ثلاثية الأبعاد في أي مكان', () {
      final offenders = <String>[];
      for (final file in dartFiles()) {
        if (file.readAsStringSync().contains('BoxShadow')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'دليل الهوية يمنع الظلال. الملفات المخالفة: $offenders',
      );
    });

    test('شاشات الواجهة لا تعرّف ألواناً خارج AppColors', () {
      final offenders = <String>[];
      final hexColor = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
      for (final file in dartFiles()) {
        // ملف اللوحة نفسه هو المكان الوحيد المسموح فيه بتعريف الألوان.
        if (file.path.endsWith('app_colors.dart')) continue;
        if (hexColor.hasMatch(file.readAsStringSync())) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'الألوان تُعرَّف في app_colors.dart فقط. المخالف: $offenders',
      );
    });
  });

  group('نظام التصميم في الكود', () {
    /// ملفات الواجهة فقط — الشاشات والمكوّنات.
    List<File> uiFiles() {
      final dirs = <String>['lib/features', 'lib/core/widgets'];
      final files = <File>[];
      for (final path in dirs) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;
        files.addAll(
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
        );
      }
      return files;
    }

    /// يبحث عن نمط في ملفات الواجهة ويرجع المخالفين.
    List<String> offendersOf(Pattern pattern, {Set<String> allow = const {}}) {
      final offenders = <String>[];
      for (final file in uiFiles()) {
        final name = file.uri.pathSegments.last;
        if (allow.contains(name)) continue;
        if (file.readAsStringSync().contains(pattern)) offenders.add(file.path);
      }
      return offenders;
    }

    test('لا أنماط نصية خام — كل النصوص من AppType', () {
      expect(
        offendersOf('TextStyle('),
        isEmpty,
        reason: 'استخدم AppType بدل TextStyle مباشرة.',
      );
    });

    test('لا وصول مباشر لـ textTheme داخل الشاشات', () {
      expect(
        offendersOf('textTheme'),
        isEmpty,
        reason: 'سلّم الخطوط الوحيد هو AppType.',
      );
    });

    test('لا أوزان خط أثقل من w700', () {
      expect(
        offendersOf(RegExp(r'w[89]00')),
        isEmpty,
        reason: 'الوزن الأثقل من w700 يُلغي التسلسل البصري.',
      );
    });

    test('لا استخدام لـ withOpacity المهجورة', () {
      expect(offendersOf('withOpacity('), isEmpty);
    });

    test('أسهم الاتجاه تُكتب باتجاه القراءة الطبيعي لا بشكلها النهائي', () {
      // أيقونات Material الاتجاهية تنعكس تلقائياً مع اتجاه الواجهة. كتابة
      // `chevron_left` في واجهة عربية تُنتج سهماً يشير يميناً — عكس المقصود.
      // نكتب دائماً الاتجاه المنطقي (`right` = للأمام) وندع الإطار يعكسه.
      expect(
        offendersOf('chevron_left'),
        isEmpty,
        reason: 'استخدم chevron_right ليشير يساراً في العربية.',
      );
      expect(
        offendersOf('arrow_forward_rounded'),
        isEmpty,
        reason: 'زرّ الرجوع هو arrow_back — ينعكس وحده في RTL.',
      );
    });
  });

  group('تباين الألوان (WCAG AA)', () {
    /// الإضاءة النسبية حسب WCAG 2.
    double luminance(Color c) {
      double channel(double v) {
        final s = v;
        return s <= 0.03928
            ? s / 12.92
            : math.pow((s + 0.055) / 1.055, 2.4) as double;
      }

      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    /// كل الأسطح التي قد يقع فوقها نصّ.
    const surfaces = <String, Color>{
      'Spruce': AppColors.spruce,
      'Spruce Deep': AppColors.spruceDeep,
      'Surface Elevated': AppColors.surfaceElevated,
      'Surface High': AppColors.surfaceHigh,
    };

    /// أسطح المحتوى وحدها — Surface High مسار شريط تقدّم لا سطح نصّ.
    const contentSurfaces = <String, Color>{
      'Spruce': AppColors.spruce,
      'Spruce Deep': AppColors.spruceDeep,
      'Surface Elevated': AppColors.surfaceElevated,
    };

    test('درجات النص الثلاث تتجاوز 4.5:1 فوق كل سطح', () {
      const tiers = <String, Color>{
        'primary': AppColors.textPrimary,
        'secondary': AppColors.textSecondary,
        'tertiary': AppColors.textTertiary,
      };

      for (final tier in tiers.entries) {
        for (final surface in surfaces.entries) {
          expect(
            contrast(tier.value, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'النص ${tier.key} فوق ${surface.key} تحت الحد.',
          );
        }
      }
    });

    test('نص الزرّ فوق تدرّج النعناع يتجاوز 4.5:1 عند طرفيه', () {
      for (final stop in AppColors.mintGradient) {
        expect(contrast(AppColors.onPrimary, stop), greaterThanOrEqualTo(4.5));
      }
    });

    test('تدرّج أي لون مستوى يبقى صالحاً لنص Spruce', () {
      for (final level in FitnessLevel.values) {
        for (final stop in AppColors.accentGradient(level.color)) {
          expect(
            contrast(AppColors.onPrimary, stop),
            greaterThanOrEqualTo(4.5),
            reason: 'زرّ مستوى ${level.label} تحت الحد عند $stop.',
          );
        }
      }
    });

    test('ألوان الهوية كنصّ صغير تتجاوز 4.5:1 فوق أسطح المحتوى', () {
      const accents = <Color>[
        AppColors.mint,
        AppColors.mintLight,
        AppColors.coral,
        AppColors.danger,
        AppColors.info,
      ];
      for (final accent in accents) {
        for (final surface in contentSurfaces.entries) {
          expect(
            contrast(AppColors.asText(accent), surface.value),
            greaterThanOrEqualTo(4.5),
            reason: '$accent فوق ${surface.key} تحت الحد.',
          );
        }
      }
    });
  });
}
