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

  Widget _letterKey(String letter) {
    return AspectRatio(
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
    );
  }


  Widget _row(List<String> letters) {
    return Row(
      children: [
        for (final l in letters) _letterKey(l),
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
            _buildLetterRow('qwertyuiop'.split(''), leadingEmpty: 0),
            _buildLetterRow('asdfghjkl'.split(''), leadingEmpty: 0.5),
            _buildLetterRow('zxcvbnm'.split(''), leadingEmpty: 1),
            Row(
              children: [
                for (final key in ['bksp', 'space', 'enter'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                        onPressed: key == 'bksp'
                            ? (enableBackspace ? onBackspace : null)
                            : key == 'enter'
                                ? (enableEnter ? onEnter : null)
                                : () => onLetter(' '),
                        child: Text(
                          key == 'space' ? 'space' : key,
                        ),
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

  Widget _buildLetterRow(List<String> letters,
      {required double leadingEmpty}) {
    // 10 equal slots per row to keep all letter keys same size
    const totalSlots = 10;
    final leadingSlots = (leadingEmpty * 1).round();
    final trailingSlots = totalSlots - letters.length - leadingSlots;

    return Row(
      children: [
        for (int i = 0; i < leadingSlots; i++)
          const Expanded(child: SizedBox()),
        for (final l in letters) Expanded(child: _letterKey(l)),
        for (int i = 0; i < trailingSlots; i++)
          const Expanded(child: SizedBox()),
      ],
    );
  }
}
