import 'package:flutter/material.dart';

/// انتقال بتلاشٍ وانزلاق خفيف — يُستخدم في كل الشاشات لتوحيد الإحساس.
Route<T> fadeThroughRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

extension NavigatorX on BuildContext {
  Future<T?> pushPage<T>(Widget page, {bool fullscreenDialog = false}) =>
      Navigator.of(this).push<T>(
        fadeThroughRoute<T>(page, fullscreenDialog: fullscreenDialog),
      );

  Future<T?> replaceWith<T>(Widget page) =>
      Navigator.of(this).pushReplacement<T, dynamic>(fadeThroughRoute<T>(page));

  Future<T?> resetTo<T>(Widget page) => Navigator.of(this)
      .pushAndRemoveUntil<T>(fadeThroughRoute<T>(page), (route) => false);
}
