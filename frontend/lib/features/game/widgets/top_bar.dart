import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/game_state.dart';

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
        topText = 'GUESS THIS';
        bottomText = gameStateModel.hint;
        wordLength =
            gameStateModel.hint
                .split(' ')
                .where((s) => s.isNotEmpty && s != '_')
                .length +
            gameStateModel.hint.split(' ').where((s) => s == '_').length;
      }
    } else if (systemMessage != null) {
      topText = systemMessage;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                '${gameStateModel.timeLeft}s',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  topText,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                if (bottomText.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bottomText,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      if (wordLength != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$wordLength',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          Text(
            'Round ${gameStateModel.round}/${gameStateModel.maxRounds}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
