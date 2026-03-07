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

    String centerText = 'WAITING FOR PLAYERS';
    if (gameState == GameState.drawing) {
      // The backend provides 'hint' text. For the drawer, it's the exact word.
      // For guessers, it's the underscores (e.g. `_ _ p _ _`).
      centerText = isDrawer ? gameStateModel.word : gameStateModel.hint;
    } else if (systemMessage != null) {
      centerText = systemMessage;
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
          Text(
            centerText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
