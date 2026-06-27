import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SketchSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 56,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? SketchTheme.sage : SketchTheme.paperSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SketchTheme.ink,
                width: 2,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: SketchTheme.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SketchTheme.ink,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
