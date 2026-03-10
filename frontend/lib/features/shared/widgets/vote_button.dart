import 'package:flutter/material.dart';

/// Like/dislike vote button shown to non-drawer players during the drawing phase.
class VoteButton extends StatelessWidget {
  final String image;
  final VoidCallback onTap;

  const VoteButton({super.key, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(image, width: 60, height: 60),
    );
  }
}
