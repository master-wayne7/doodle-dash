import 'dart:math';
import 'package:flutter/material.dart';
import 'package:doodle_dash/features/shared/widgets/avatar_display.dart';

class AvatarSelector extends StatefulWidget {
  final void Function(int color, int eyes, int mouth) onAvatarChanged;

  const AvatarSelector({super.key, required this.onAvatarChanged});

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  int _colorIndex = 11; // Default looking good
  int _eyesIndex = 30;
  int _mouthIndex = 23;

  final int _maxColors = 28;
  final int _maxEyes = 57;
  final int _maxMouths = 51;

  void _randomize() {
    final random = Random();
    setState(() {
      _colorIndex = random.nextInt(_maxColors);
      _eyesIndex = random.nextInt(_maxEyes);
      _mouthIndex = random.nextInt(_maxMouths);
    });
    _notifyChange();
  }

  void _notifyChange() {
    widget.onAvatarChanged(_colorIndex, _eyesIndex, _mouthIndex);
  }

  void _change(String part, int delta) {
    setState(() {
      if (part == 'color') {
        _colorIndex = (_colorIndex + delta) % _maxColors;
        if (_colorIndex < 0) _colorIndex += _maxColors;
      } else if (part == 'eyes') {
        _eyesIndex = (_eyesIndex + delta) % _maxEyes;
        if (_eyesIndex < 0) _eyesIndex += _maxEyes;
      } else if (part == 'mouth') {
        _mouthIndex = (_mouthIndex + delta) % _maxMouths;
        if (_mouthIndex < 0) _mouthIndex += _maxMouths;
      }
    });
    _notifyChange();
  }

  Widget _buildSprite({
    required String asset,
    required int index,
    int columns = 10,
    double spriteSize = 48.0,
    double scale = 2.0,
  }) {
    final int row = index ~/ columns;
    final int col = index % columns;
    final double atlasSize = spriteSize * columns;

    return SizedBox(
      width: spriteSize * scale,
      height: spriteSize * scale,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: atlasSize * scale,
          maxHeight: atlasSize * scale,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-col * spriteSize * scale, -row * spriteSize * scale),
            child: Image.asset(
              asset,
              width: atlasSize * scale,
              height: atlasSize * scale,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none, // Point sampling for pixel art
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrow(bool isLeft, VoidCallback onTap) {
    final int index = isLeft ? 0 : 2; // 0 is white left, 2 is white right from 2x2 grid
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _buildSprite(
            asset: 'assets/images/arrow.gif',
            index: index,
            columns: 2,
            spriteSize: 16.0,
            scale: 2.0, // Render 32x32 size
          ),
        ),
      ),
    );
  }

  Widget _buildRowControls(String part) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildArrow(true, () => _change(part, -1)),
        const SizedBox(width: 80), // Space for avatar
        _buildArrow(false, () => _change(part, 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background container to match image style
        Container(width: 400, height: 180, decoration: BoxDecoration(color: const Color(0x1A000000))),

        // Avatar Display
        AvatarDisplay(colorIndex: _colorIndex, eyesIndex: _eyesIndex, mouthIndex: _mouthIndex, scale: 2.50),

        // Controls
        SizedBox(
          width: 250,
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_buildRowControls('eyes'), _buildRowControls('mouth'), _buildRowControls('color')],
          ),
        ),

        // Randomize Button
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: _randomize,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Image.asset(
                'assets/images/randomize.gif',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
