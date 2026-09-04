import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/health_snapshot.dart';

/// ملخّص نشاط المستخدم من HealthKit / Health Connect.
///
/// أربعة مقاييس محايدة اللون. لو لوّنّا كل مقياس بلون مختلف لبدت البطاقة
/// لوحة ألوان لا بيانات — الأيقونة وحدها تكفي للتمييز.
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    this.isBusy = false,
  });

  final HealthSnapshot snapshot;
  final VoidCallback onRefresh;
  final bool isBusy;

  String get _sourceName =>
      (!kIsWeb && Platform.isIOS) ? 'تطبيق الصحة' : 'Health Connect';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('نشاطك', style: AppType.h4),
                    const SizedBox(height: Space.xxs),
                    Text(
                      'من $_sourceName · آخر ٧ أيام',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(Space.md),
                  child: SizedBox(
                    width: IconSizes.md,
                    height: IconSizes.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'تحديث بيانات الصحة',
                  color: AppColors.textTertiary,
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          _body(),
        ],
      ),
    );
  }

  Widget _body() {
    // كل حالة تقول ما الذي ينقص وأين يُصلَح، لا «لا توجد بيانات» وحدها.
    if (!snapshot.isAvailable) {
      return _note('خدمة الصحة غير متاحة على هذا الجهاز.');
    }
    if (!snapshot.isAuthorized) {
      return _note('نحتاج صلاحية القراءة. فعّلها من «حسابي ← ربط الصحة».');
    }
    if (!snapshot.hasData) {
      return _note('ما سُجّل نشاط في آخر ٧ أيام.');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _metric('${snapshot.steps}', 'خطوة/يوم', Icons.directions_walk_rounded),
        _metric(
          snapshot.activeCalories.round().toString(),
          'سعرة نشطة',
          Icons.local_fire_department_rounded,
        ),
        _metric(
          '${snapshot.workoutMinutes}',
          'دقيقة تمرين',
          Icons.timer_outlined,
        ),
        if (snapshot.restingHeartRate != null)
          _metric(
            snapshot.restingHeartRate!.round().toString(),
            'نبض الراحة',
            Icons.monitor_heart_outlined,
          ),
      ],
    );
  }

  Widget _note(String message) => Text(message, style: AppType.bodySm);

  Widget _metric(String value, String label, IconData icon) {
    return Expanded(
      child: Semantics(
        label: label,
        value: value,
        child: ExcludeSemantics(
          child: Column(
            children: <Widget>[
              Icon(icon, size: IconSizes.sm, color: AppColors.textTertiary),
              const SizedBox(height: Space.sm),
              Text(value, style: AppType.number(size: 16)),
              const SizedBox(height: Space.xxs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.overline.copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
