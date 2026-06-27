import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const SketchBadge({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(
        horizontal: SketchTheme.s12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color ?? SketchTheme.mutedYellow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SketchTheme.ink,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(fontSize: 14),
      ),
    );
  }
}
