import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum MonsterPose { idle, walk, wave, cry, cheer }

class MonsterMascot extends StatefulWidget {
  final double size;
  final MonsterPose pose;
  final bool facingRight;

  const MonsterMascot({
    super.key,
    this.size = 120,
    this.pose = MonsterPose.idle,
    this.facingRight = true,
  });

  @override
  State<MonsterMascot> createState() => _MonsterMascotState();
}

class _MonsterMascotState extends State<MonsterMascot>
    with SingleTickerProviderStateMixin {
  static const double designSize = 256.0;

  late final AnimationController _controller;
  Timer? _blinkTimer;

  _EyeState _eyeState = _EyeState.open;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 2000 + Random().nextInt(3000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted) return;
      if (widget.pose != MonsterPose.cry &&
          widget.pose != MonsterPose.cheer) {
        setState(() => _eyeState = _EyeState.half);
        await Future.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
        setState(() => _eyeState = _EyeState.closed);
        await Future.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
        setState(() => _eyeState = _EyeState.half);
        await Future.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
        setState(() => _eyeState = _EyeState.open);
      }
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.size / designSize;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value * 2 * pi;

        final breath = 1 + sin(t * 1.2) * 0.02;
        final bodyBob = sin(t * 1.2) * 2 * scale;

        final walkCycle = sin(t * 4);

        double leftLeg = 0;
        double rightLeg = 0;
        double leftArm = 0;
        double rightArm = 0;
        double rootShakeX = 0;

        switch (widget.pose) {
          case MonsterPose.idle:
            leftArm = sin(t * 0.8) * 0.05;
            rightArm = -sin(t * 0.8) * 0.05;
            break;
          case MonsterPose.walk:
            leftLeg = walkCycle * 0.4;
            rightLeg = -walkCycle * 0.4;
            leftArm = -walkCycle * 0.5;
            rightArm = walkCycle * 0.5;
            break;
          case MonsterPose.wave:
            rightArm = 3.1 - sin(t * 8) * 0.9;
            break;
          case MonsterPose.cry:
            rootShakeX = sin(t * 20) * 1.5 * scale;
            break;
          case MonsterPose.cheer:
            leftArm = -1.2;
            rightArm = 1.2;
            break;
        }

        return Transform.scale(
          scaleX: widget.facingRight ? 1 : -1,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(rootShakeX, bodyBob),
                  child: _buildCharacter(
                    scale,
                    breath,
                    leftLeg,
                    rightLeg,
                    leftArm,
                    rightArm,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacter(
    double scale,
    double breath,
    double leftLeg,
    double rightLeg,
    double leftArm,
    double rightArm,
  ) {
    return SizedBox(
      width: designSize * scale,
      height: designSize * scale,
      child: Stack(
        children: [
          // LEFT LEG
          _part(
            asset: 'assets/character/monster_leg_left.png',
            angle: leftLeg,
            position: const Offset(55, 190),
            pivot: const Offset(20, 10),
            scale: scale,
            partScale: 0.25
          ),

          // RIGHT LEG
          _part(
            asset: 'assets/character/monster_leg_right.png',
            angle: rightLeg,
            position: const Offset(140, 190),
            pivot: const Offset(20, 10),
            scale: scale,
            partScale: 0.25
          ),

          // BODY (base layer)
          Positioned(
            left: 0,
            top: 0,
            child: Transform.scale(
              scale: breath,
              child: Image.asset(
                'assets/character/monster_body.png',
                width: designSize * scale,
              ),
            ),
          ),

          

          // EYES
          Positioned(
            left: scale * 66,
            top: scale * 60,
            child: Image.asset(
              _eyeAsset(),
              width: designSize * scale * 0.47,
            ),
          ),

          // MOUTH
          Positioned(
            left: scale * 100,
            top: scale * 105,
            child: Image.asset(
              _mouthAsset(),
              width: designSize * scale * 0.20,
            ),
          ),

          // LEFT ARM
          _part(
            asset: _leftArmAsset(),
            angle: leftArm,
            position: const Offset(15, 120),
            pivot: const Offset(25, 10),
            scale: scale,
            partScale: 0.2
          ),

          // RIGHT ARM
          _part(
            asset: _rightArmAsset(),
            angle: rightArm,
            position: const Offset(180, 120),
            pivot: const Offset(25, 10),
            scale: scale,
            partScale: 0.2
          ),
        ],
      ),
    );
  }

  Widget _part({
    required String asset,
    required double angle,
    required Offset position,
    required Offset pivot,
    required double scale,
    double partScale = 1.0,
  }) {
    return Positioned(
      left: position.dx * scale,
      top: position.dy * scale,
      child: Transform.translate(
        offset: Offset(pivot.dx * scale, pivot.dy * scale),
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-pivot.dx * scale, -pivot.dy * scale),
            child: Image.asset(
              asset,
              width: designSize * scale * partScale,
            ),
          ),
        ),
      ),
    );
  }

  String _eyeAsset() {
    if (widget.pose == MonsterPose.cry) {
      return 'assets/character/monster_eyes_crying.png';
    }
    if (widget.pose == MonsterPose.cheer) {
      return 'assets/character/monster_eyes_cheering.png';
    }
    switch (_eyeState) {
      case _EyeState.open:
        return 'assets/character/monster_eyes_open.png';
      case _EyeState.half:
        return 'assets/character/monster_eyes_half_open.png';
      case _EyeState.closed:
        return 'assets/character/monster_eyes_closed.png';
    }
  }

  String _mouthAsset() {
    switch (widget.pose) {
      case MonsterPose.cry:
        return 'assets/character/monster_mouth_open.png';
      case MonsterPose.cheer:
        return 'assets/character/monster_mouth_big_smile.png';
      case MonsterPose.wave:
        return 'assets/character/monster_mouth_smile.png';
      case MonsterPose.walk:
        return 'assets/character/monster_mouth_neutral.png';
      case MonsterPose.idle:
        return 'assets/character/monster_mouth_smile.png';
    }
  }

  String _leftArmAsset() {
    return 'assets/character/monster_arm_left_down.png';
  }

  String _rightArmAsset() {
    if (widget.pose == MonsterPose.wave) {
      return 'assets/character/monster_arm_right_wave.png';
    }
    return 'assets/character/monster_arm_right_down.png';
  }
}

enum _EyeState { open, half, closed }
