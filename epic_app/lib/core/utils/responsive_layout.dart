import 'package:flutter/material.dart';

/// Landscape adjustments are opt-in so portrait layouts keep their dimensions.
class ResponsiveLayout {
  ResponsiveLayout._();

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static int gridColumns(
    BuildContext context, {
    int portraitColumns = 2,
    double tileWidth = 210,
    int maxColumns = 4,
  }) {
    if (!isLandscape(context)) return portraitColumns;
    final width = MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        48;
    return (width / tileWidth).ceil().clamp(portraitColumns, maxColumns);
  }

  static double scannerSize(Size size) => size.shortestSide * 0.7;

  static double landscapeNavigationSpace(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // extendBody already includes the floating navigation in body padding.
    return bottom > 64 ? bottom : 64 + (bottom > 0 ? bottom : 12);
  }
}

/// Keeps short, centered status pages reachable without changing portrait.
/// The child must not contain Expanded/Spacer in landscape.
class LandscapeScrollView extends StatelessWidget {
  const LandscapeScrollView({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveLayout.isLandscape(context)) return child;
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      );
    });
  }
}
