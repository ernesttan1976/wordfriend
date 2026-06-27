import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const SketchChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: SketchTheme.s16,
            vertical: SketchTheme.s12,
          ),
          decoration: BoxDecoration(
            color: selected ? SketchTheme.dustyBlue : SketchTheme.paperSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SketchTheme.ink,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
