import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double largeTablet = 1200;
  static const double maxContentWidth = 1280;
}

enum AppWindowClass { phone, smallTablet, largeTablet, desktop }

@immutable
class ResponsiveLayout {
  const ResponsiveLayout(this.width);

  factory ResponsiveLayout.of(BuildContext context) {
    return ResponsiveLayout(MediaQuery.sizeOf(context).width);
  }

  final double width;

  AppWindowClass get windowClass {
    if (width < AppBreakpoints.phone) return AppWindowClass.phone;
    if (width < AppBreakpoints.tablet) return AppWindowClass.smallTablet;
    if (width < AppBreakpoints.largeTablet) {
      return AppWindowClass.largeTablet;
    }
    return AppWindowClass.desktop;
  }

  bool get isPhone => windowClass == AppWindowClass.phone;
  bool get isTablet =>
      windowClass == AppWindowClass.smallTablet ||
      windowClass == AppWindowClass.largeTablet;

  double get horizontalPadding => switch (windowClass) {
        AppWindowClass.phone => width < 420 ? 12 : 16,
        AppWindowClass.smallTablet => 24,
        AppWindowClass.largeTablet => 32,
        AppWindowClass.desktop => 32,
      };

  int get metricColumns => switch (windowClass) {
        AppWindowClass.phone => 2,
        AppWindowClass.smallTablet => 2,
        AppWindowClass.largeTablet || AppWindowClass.desktop => 4,
      };

  int get compactMetricColumns => switch (windowClass) {
        AppWindowClass.phone => 3,
        AppWindowClass.smallTablet => 3,
        AppWindowClass.largeTablet || AppWindowClass.desktop => 4,
      };

  int get herdColumns => isPhone ? 1 : 2;

  int get quickEntryColumns => switch (windowClass) {
        AppWindowClass.phone => 4,
        AppWindowClass.smallTablet => 4,
        AppWindowClass.largeTablet || AppWindowClass.desktop => 6,
      };

  double gridAspectRatio({
    required double phone,
    double? tablet,
    double? desktop,
  }) {
    return switch (windowClass) {
      AppWindowClass.phone => phone,
      AppWindowClass.smallTablet ||
      AppWindowClass.largeTablet =>
        tablet ?? phone,
      AppWindowClass.desktop => desktop ?? tablet ?? phone,
    };
  }
}
