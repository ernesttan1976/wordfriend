import 'package:flutter/material.dart';

class SketchButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;

  const SketchButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
  });

  @override
  State<SketchButton> createState() => _SketchButtonState();
}

class _SketchButtonState extends State<SketchButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = widget.color ?? theme.colorScheme.secondary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.rotationZ(_pressed ? -0.02 : 0.0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
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
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
