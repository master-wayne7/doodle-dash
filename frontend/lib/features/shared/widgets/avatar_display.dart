import 'package:flutter/material.dart';

class AvatarDisplay extends StatelessWidget {
  final int colorIndex;
  final int eyesIndex;
  final int mouthIndex;
  final double scale;

  const AvatarDisplay({
    super.key,
    required this.colorIndex,
    required this.eyesIndex,
    required this.mouthIndex,
    this.scale = 2.0,
  });

  Widget _buildSprite({required String asset, required int index, int columns = 10, double spriteSize = 48.0}) {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildSprite(asset: 'assets/images/avatar/color_atlas.gif', index: colorIndex),
        _buildSprite(asset: 'assets/images/avatar/eyes_atlas.gif', index: eyesIndex),
        _buildSprite(asset: 'assets/images/avatar/mouth_atlas.gif', index: mouthIndex),
      ],
    );
  }
}
