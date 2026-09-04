import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ثيم CoachMint.
///
/// قواعد الهوية المطبَّقة:
/// - **بلا ظلال ولا تأثيرات ثلاثية الأبعاد** — العمق يأتي من طبقات Spruce
///   ومن الحدود، لا من الظل.
/// - **Alexandria** لكل واجهة المستخدم العربية، و**Plus Jakarta Sans**
///   للأرقام واسم العلامة فقط.
/// - النص فوق أي سطح نعناعي يكون Spruce وليس أبيض.
///
/// كل القياسات تأتي من [Space] و[Radii] و[Motion]، وكل الأنماط النصية من
/// [AppType]. لا قيم مباشرة هنا.
class AppTheme {
  const AppTheme._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.spruce,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = AppType.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.spruce,
      canvasColor: AppColors.spruce,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.mint,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.mintDark,
        onPrimaryContainer: AppColors.offWhite,
        secondary: AppColors.coral,
        onSecondary: AppColors.spruce,
        surface: AppColors.spruceDeep,
        onSurface: AppColors.offWhite,
        surfaceContainerHighest: AppColors.surfaceHigh,
        error: AppColors.danger,
        onError: AppColors.offWhite,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSoft,
        scrim: AppColors.scrim,
      ),

      // --- الأشرطة العلوية ------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.xs,
        systemOverlayStyle: overlayStyle,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: IconSizes.lg,
        ),
        titleTextStyle: AppType.h3,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),

      // --- الحقول ---------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        constraints: const BoxConstraints(minHeight: Touch.field),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        hintStyle: AppType.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppType.label.copyWith(color: AppColors.textSecondary),
        helperStyle: AppType.caption,
        helperMaxLines: 3,
        errorStyle: AppType.caption.copyWith(color: AppColors.danger),
        errorMaxLines: 3,
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.mint, width: 1.5),
        disabledBorder: _inputBorder(AppColors.borderSoft),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
      ),

      // --- الأزرار --------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.disabled,
          elevation: 0,
          minimumSize: const Size.fromHeight(Touch.button),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppType.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.disabled,
          minimumSize: const Size.fromHeight(Touch.button),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: AppType.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.mint,
          disabledForegroundColor: AppColors.disabled,
          minimumSize: const Size(Touch.min, Touch.min),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          textStyle: AppType.label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(Touch.min, Touch.min),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),

      // --- الأسطح المؤقتة -------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.spruceDeep,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.surfaceHigh,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppType.h3,
        contentTextStyle: AppType.body.copyWith(
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: AppType.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppType.body,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Space.lg),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        textStyle: AppType.caption.copyWith(color: AppColors.textPrimary),
      ),

      // --- عناصر التحكّم ---------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mint,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
        strokeCap: StrokeCap.round,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppType.label,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.spruce
              : AppColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.surfaceHigh,
        ),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.mint
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll<Color>(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xs * 0.75),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.border,
        ),
      ),

      // --- ردّ الفعل عند اللمس ---------------------------------------------
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppColors.mint.withValues(alpha: 0.06),
      splashColor: AppColors.mint.withValues(alpha: 0.10),
      focusColor: AppColors.focus.withValues(alpha: 0.24),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
