import 'package:flutter/material.dart';

class SketchCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const SketchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.onSurface,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            offset: Offset(2, 2),
            blurRadius: 4,
            color: Colors.black26,
          ),
        ],
      ),
      child: child,
    );
  }
}
