import 'package:flutter/material.dart';
import '../monster_mascot.dart';

class MascotTestScreen extends StatefulWidget {
  const MascotTestScreen({super.key});

  @override
  State<MascotTestScreen> createState() => _MascotTestScreenState();
}

class _MascotTestScreenState extends State<MascotTestScreen> {
  MonsterPose _pose = MonsterPose.idle;
  bool _facingRight = true;
  double _size = 160;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mascot Animation Test'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: MonsterMascot(
                size: _size,
                pose: _pose,
                facingRight: _facingRight,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pose'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: MonsterPose.values.map((pose) {
                    final selected = pose == _pose;
                    return ChoiceChip(
                      label: Text(pose.name),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _pose = pose;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Facing right'),
                    const Spacer(),
                    Switch(
                      value: _facingRight,
                      onChanged: (value) {
                        setState(() {
                          _facingRight = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Size'),
                Slider(
                  min: 80,
                  max: 300,
                  divisions: 11,
                  value: _size,
                  label: _size.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _size = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
