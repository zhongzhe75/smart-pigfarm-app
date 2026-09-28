import 'package:flutter/material.dart';

import 'responsive_layout.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.children,
    this.padding,
    this.spacing = 16,
  });

  final List<Widget> children;
  final EdgeInsets? padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveLayout(constraints.maxWidth);
        final horizontal = responsive.horizontalPadding;
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.maxContentWidth,
              ),
              child: ListView.separated(
                padding: padding ??
                    EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
                itemBuilder: (context, index) => children[index],
                separatorBuilder: (context, index) => SizedBox(height: spacing),
                itemCount: children.length,
              ),
            ),
          ),
        );
      },
    );
  }
}
