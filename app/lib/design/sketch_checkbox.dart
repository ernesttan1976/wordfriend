import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  const SketchCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value ? SketchTheme.sage : SketchTheme.paperSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SketchTheme.ink,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: SketchTheme.ink,
                    )
                  : null,
            ),
            if (label != null) ...[
              const SizedBox(width: SketchTheme.s12),
              Flexible(
                child: Text(
                  label!,
                  style: textTheme.bodyLarge,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
