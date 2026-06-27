import 'package:flutter/material.dart';

class SketchDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget> actions;

  const SketchDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.onSurface,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              offset: Offset(3, 3),
              blurRadius: 6,
              color: Colors.black26,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              DefaultTextStyle.merge(
                style: theme.textTheme.titleLarge,
                child: title!,
              ),
              const SizedBox(height: 16),
            ],
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
