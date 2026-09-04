/// مكتبة مكوّنات CoachMint.
///
/// كل شاشة تستورد هذا الملف وحده. المكوّنات موزّعة على ملفات حسب دورها:
///
/// | الملف | المكوّنات |
/// |-------|-----------|
/// | `app_button.dart`   | `AppButton` · `AppIconButton` |
/// | `app_field.dart`    | `AppTextField` |
/// | `app_motion.dart`   | `RevealIn` |
/// | `app_surface.dart`  | `BrandBackdrop` · `AppCard` · `ScreenHeader` · `SectionHeader` |
/// | `app_chip.dart`     | `AppChip` · `AppTag` · `AppMetricPill` |
/// | `app_data.dart`     | `SportMark` · `AppAvatar` · `ProgressBar` · `ProgressRing` · `StatTile` · `StatRow` |
/// | `app_feedback.dart` | `EmptyState` · `ErrorStateView` · `AppNotice` · `Skeleton` · `SkeletonList` · `showConfirmDialog` · `showAppSnack` |
///
/// لا تُنشئ نسخة محلية من أي مكوّن هنا داخل شاشة. إن احتاج المكوّن حالة
/// جديدة، أضفها إليه في مكانه ليستفيد منها التطبيق كله.
library;

export 'app_button.dart';
export 'app_chip.dart';
export 'app_data.dart';
export 'app_feedback.dart';
export 'app_field.dart';
export 'app_motion.dart';
export 'app_surface.dart';
