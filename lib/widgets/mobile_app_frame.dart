import 'package:flutter/material.dart';

class MobileAppFrame extends StatelessWidget {
  const MobileAppFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
