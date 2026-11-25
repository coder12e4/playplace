import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xDDFBFFFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x5580B996)),
            boxShadow: const [
              BoxShadow(color: Color(0x102E7547), blurRadius: 18, offset: Offset(0, 7)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
