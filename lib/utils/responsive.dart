import 'package:flutter/widgets.dart';

import '../config/constants.dart';

enum DeviceType { mobile, tablet, desktop }

/// Breakpoints compartidos por toda la UI, para que HomeScreen/PlayerScreen
/// decidan entre layout de lista (mobile) y layout de grid/side-panel
/// (desktop/tablet) de forma consistente.
class Responsive {
  Responsive._();

  static DeviceType deviceTypeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.tabletBreakpoint) return DeviceType.desktop;
    if (width >= AppConstants.mobileBreakpoint) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      deviceTypeOf(context) == DeviceType.desktop;

  /// Número de columnas para grids de álbumes/playlists según el ancho.
  static int gridColumns(BuildContext context) {
    switch (deviceTypeOf(context)) {
      case DeviceType.mobile:
        return 2;
      case DeviceType.tablet:
        return 3;
      case DeviceType.desktop:
        return 5;
    }
  }
}
