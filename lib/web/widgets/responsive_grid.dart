import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ResponsiveGrid({
    super.key,
    this.crossAxisSpacing = 24.0,
    this.mainAxisSpacing = 24.0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine number of columns based on screen width
    int columns;
    if (screenWidth >= 1200) {
      columns = 4; // Large screens (desktop)
    } else if (screenWidth >= 900) {
      columns = 3; // Medium screens (small desktop, large tablet)
    } else if (screenWidth >= 600) {
      columns = 2; // Tablet portrait
    } else {
      columns = 1; // Mobile phones
    }

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: 1.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}