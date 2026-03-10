import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doodle_dash/features/game/providers/game_provider.dart';
import 'package:doodle_dash/features/game/models/game_state.dart';

/// The persistent top bar displaying the current round, timer, and the word/hint to guess or draw.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameStateModel = ref.watch(gameProvider);
    final isDrawer = gameStateModel.isDrawer;
    final gameState = gameStateModel.state;
    final systemMessage = gameStateModel.systemMessage;

    String topText = 'WAITING FOR PLAYERS';
    String bottomText = '';
    int? wordLength;

    if (gameState == GameState.drawing) {
      if (isDrawer) {
        topText = 'DRAW THIS';
        bottomText = gameStateModel.word;
      } else {
        if (gameStateModel.word.isNotEmpty) {
          topText = 'WORD GUESSED';
          bottomText = gameStateModel.word.toUpperCase();
        } else {
          topText = 'GUESS THIS';
          bottomText = gameStateModel.hint;
          wordLength =
              gameStateModel.hint.split(' ').where((s) => s.isNotEmpty && s != '_').length +
              gameStateModel.hint.split(' ').where((s) => s == '_').length;
        }
      }
    } else if (systemMessage != null) {
      topText = systemMessage;
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Timer and Round
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/images/clock.gif', height: 48),
                  Positioned(
                    top: 14,
                    child: Text(
                      '${gameStateModel.timeLeft}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Text(
                'Round ${gameStateModel.round} of ${gameStateModel.maxRounds}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Center: Word / Hint
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(topText, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                if (bottomText.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bottomText,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                      ),
                      if (wordLength != null) ...[
                        const SizedBox(width: 4),
                        Text('$wordLength', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }
}
