import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';

class PlayerList extends ConsumerWidget {
  final double width;

  const PlayerList({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final players = gameState.players;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.builder(
        itemCount: players.length,
        itemBuilder: (context, index) {
          final p = players[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              p.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Score: ${p.score}'),
            trailing: p.isDrawer
                ? const Icon(Icons.brush, color: Colors.deepPurple)
                : null,
            tileColor: p.guessedWord ? Colors.green.shade100 : null,
          );
        },
      ),
    );
  }
}
