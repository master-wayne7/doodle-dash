import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/player.dart';
import 'package:frontend/features/game/widgets/player_list_item.dart';

class PlayerList extends ConsumerWidget {
  final double width;

  const PlayerList({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final players = gameState.players;

    final sortedByScore = List.from(players)
      ..sort((a, b) => ((b as Player).score).compareTo(a.score));
    final rankMap = <String, int>{};
    int currentRank = 1;
    for (int i = 0; i < sortedByScore.length; i++) {
      if (i > 0 && sortedByScore[i].score < sortedByScore[i - 1].score) {
        currentRank = i + 1;
      }
      rankMap[sortedByScore[i].nickname] = currentRank;
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.builder(
        clipBehavior: Clip.none,
        itemCount: players.length,
        itemBuilder: (context, index) {
          final p = players[index];
          return PlayerListItem(
            player: p,
            rank: rankMap[p.nickname] ?? 1,
            isEven: index % 2 == 0,
            gameState: gameState,
            listWidth: width,
          );
        },
      ),
    );
  }
}
