import 'package:flutter/material.dart';
import 'sketch_theme.dart';

class SketchEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? action;

  const SketchEmptyState({
    super.key,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SketchTheme.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mascot
            Image.asset(
              'assets/monster.png',
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: SketchTheme.s24),
            Text(
              title,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: SketchTheme.s12),
              Text(
                message!,
                style: textTheme.bodyLarge?.copyWith(
                  color: SketchTheme.mutedGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: SketchTheme.s24),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: action!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
