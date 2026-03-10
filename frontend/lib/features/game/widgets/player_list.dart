import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doodle_dash/features/game/providers/game_provider.dart';
import 'package:doodle_dash/features/game/models/player.dart';
import 'package:doodle_dash/features/game/widgets/player_list_item.dart';

/// Displays the list of players currently in the room, their scores, and current states (e.g., drawer, guessed).
class PlayerList extends ConsumerWidget {
  final double width;

  const PlayerList({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final players = gameState.players;

    final rankMap = <String, int>{};
    // Backend already sends players sorted by JoinedAt.
    // We still calculate ranks based on scores for visual feedback.
    final sortedByScore = List<Player>.from(players)..sort((a, b) => b.score.compareTo(a.score));

    int currentRank = 1;
    for (int i = 0; i < sortedByScore.length; i++) {
      if (i > 0 && sortedByScore[i].score < sortedByScore[i - 1].score) {
        currentRank = i + 1;
      }
      rankMap[sortedByScore[i].nickname] = currentRank;
    }

    return Container(
      width: width,
      margin: EdgeInsets.only(bottom: 52),
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
