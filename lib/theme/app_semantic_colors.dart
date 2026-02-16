import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.divider,
    required this.badge,
    required this.badgeMuted,
    required this.notificationIcon,
    required this.notificationIconMuted,
  });

  final Color success;
  final Color warning;
  final Color divider;
  final Color badge;
  final Color badgeMuted;
  final Color notificationIcon;
  final Color notificationIconMuted;

  static const AppSemanticColors light = AppSemanticColors(
    success: AppColors.black,
    warning: AppColors.gray700,
    divider: AppColors.gray200,
    badge: AppColors.gray300,
    badgeMuted: AppColors.gray200,
    notificationIcon: AppColors.gray800,
    notificationIconMuted: AppColors.gray600,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: AppColors.white,
    warning: AppColors.gray300,
    divider: AppColors.gray700,
    badge: AppColors.gray700,
    badgeMuted: AppColors.gray800,
    notificationIcon: AppColors.gray200,
    notificationIconMuted: AppColors.gray400,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? divider,
    Color? badge,
    Color? badgeMuted,
    Color? notificationIcon,
    Color? notificationIconMuted,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      divider: divider ?? this.divider,
      badge: badge ?? this.badge,
      badgeMuted: badgeMuted ?? this.badgeMuted,
      notificationIcon: notificationIcon ?? this.notificationIcon,
      notificationIconMuted:
          notificationIconMuted ?? this.notificationIconMuted,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      badge: Color.lerp(badge, other.badge, t) ?? badge,
      badgeMuted: Color.lerp(badgeMuted, other.badgeMuted, t) ?? badgeMuted,
      notificationIcon:
          Color.lerp(notificationIcon, other.notificationIcon, t) ??
          notificationIcon,
      notificationIconMuted:
          Color.lerp(notificationIconMuted, other.notificationIconMuted, t) ??
          notificationIconMuted,
    );
  }
}

extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppSemanticColors.dark
          : AppSemanticColors.light);
}
