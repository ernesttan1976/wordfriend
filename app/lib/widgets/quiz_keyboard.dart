import 'package:flutter/material.dart';

class QuizKeyboard extends StatelessWidget {
  const QuizKeyboard({
    super.key,
    required this.onLetter,
    required this.onBackspace,
    required this.onEnter,
    required this.enableBackspace,
    required this.enableEnter,
  });

  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final bool enableBackspace;
  final bool enableEnter;

  Widget _letterKey(BuildContext context, String letter) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: InkWell(
            onTap: () => onLetter(letter),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> letters) {
    return Row(
      children: [
        for (final l in letters) _letterKey(null as BuildContext, l),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = screenHeight / 3;

    return SizedBox(
      height: keyboardHeight,
      child: Container(
        color: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(children: [for (final l in 'qwertyuiop'.split('')) _letterKey(context, l)]),
            Row(children: [for (final l in 'asdfghjkl'.split('')) _letterKey(context, l)]),
            Row(children: [for (final l in 'zxcvbnm'.split('')) _letterKey(context, l)]),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      onPressed: enableBackspace ? onBackspace : null,
                      child: const Text('Backspace'),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      onPressed: () => onLetter(' '),
                      child: const Text('Space'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ElevatedButton(
                      onPressed: enableEnter ? onEnter : null,
                      child: const Text('Enter'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
