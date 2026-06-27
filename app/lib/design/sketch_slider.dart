import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchSlider extends StatefulWidget {
  final double value; // 0.0 - 1.0
  final ValueChanged<double> onChanged;

  const SketchSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SketchSlider> createState() => _SketchSliderState();
}

class _SketchSliderState extends State<SketchSlider> {
  double _localValue = 0;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant SketchSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value.clamp(0.0, 1.0);
    }
  }

  void _update(Offset localPosition, double width) {
    final newValue = (localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _localValue = newValue);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbLeft = _localValue * width;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              _update(details.localPosition, width),
          onTapDown: (details) => _update(details.localPosition, width),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: SketchTheme.paperSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SketchTheme.ink,
                      width: 2,
                    ),
                  ),
                ),

                // Filled portion
                Container(
                  width: thumbLeft,
                  height: 8,
                  decoration: BoxDecoration(
                    color: SketchTheme.warmOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // Thumb
                Positioned(
                  left: (thumbLeft - 12).clamp(0.0, width - 24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: SketchTheme.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SketchTheme.ink,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
