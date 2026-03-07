import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/game_state.dart';
import 'package:frontend/features/game/widgets/drawing_board.dart';
import 'package:frontend/features/game/widgets/player_list.dart';
import 'package:frontend/features/game/widgets/chat_box.dart';
import 'package:frontend/features/game/widgets/top_bar.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String nickname;
  final String roomId;

  const GameScreen({super.key, required this.nickname, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).init(widget.nickname, widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameStateModel = ref.watch(gameProvider);
    final isDrawer = gameStateModel.isDrawer;
    final gameState = gameStateModel.state;
    final wordChoices = gameStateModel.wordChoices;
    final systemMessage = gameStateModel.systemMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skribbl Clone'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5A4AE3),
        elevation: 1,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Room: ${gameStateModel.roomId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                // Desktop Layout
                return Row(
                  children: [
                    const PlayerList(width: 200),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MainGameArea(
                        isDrawer: isDrawer,
                        gameState: gameState,
                        wordChoices: wordChoices,
                        systemMessage: systemMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ChatBox(width: 300),
                  ],
                );
              } else {
                // Mobile Layout
                return Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _MainGameArea(
                        isDrawer: isDrawer,
                        gameState: gameState,
                        wordChoices: wordChoices,
                        systemMessage: systemMessage,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const PlayerList(width: 120),
                          const SizedBox(width: 8),
                          const Expanded(child: ChatBox()),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _MainGameArea extends ConsumerWidget {
  final bool isDrawer;
  final GameState gameState;
  final List<String> wordChoices;
  final String? systemMessage;

  const _MainGameArea({
    required this.isDrawer,
    required this.gameState,
    required this.wordChoices,
    required this.systemMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLeft = ref.watch(gameProvider).timeLeft;

    return Column(
      children: [
        const TopBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              DrawingBoard(isDrawer: isDrawer),
              if (gameState == GameState.choosing &&
                  isDrawer &&
                  wordChoices.isNotEmpty)
                _buildWordSelectionOverlay(ref),
              if (gameState == GameState.lobby)
                _buildOverlayMessage('Waiting for players to join...'),
              if (gameState == GameState.starting)
                _buildOverlayMessage('Starting in ${timeLeft}s...'),
              if (gameState == GameState.round)
                _buildRoundTransitionOverlay(ref),
              if (gameState == GameState.turnEnd) _buildTurnEndOverlay(ref),
              if (gameState == GameState.gameOver) _buildGameOverOverlay(ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordSelectionOverlay(WidgetRef ref) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a word to draw',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: wordChoices.map((word) {
                    return ElevatedButton(
                      onPressed: () =>
                          ref.read(gameProvider.notifier).chooseWord(word),
                      child: Text(word),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayMessage(String msg) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 4)],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRoundTransitionOverlay(WidgetRef ref) {
    final round = ref.read(gameProvider).round;
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            Text(
              'Round $round',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 8, color: Colors.amber)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnEndOverlay(WidgetRef ref) {
    final state = ref.read(gameProvider);
    final players = List.from(state.players)
      ..sort((a, b) => (b.turnScore as num).compareTo(a.turnScore as num));

    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.systemMessage ?? 'Turn Over!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Leaderboard',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: players.map((p) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p.nickname,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '+${p.turnScore} pts',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(WidgetRef ref) {
    final state = ref.read(gameProvider);
    final players = List.from(state.players)
      ..sort((a, b) => (b.score as num).compareTo(a.score as num));

    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over!',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 8, color: Colors.redAccent)],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: players.take(3).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final isWinner = idx == 0;
                final height = isWinner ? 150.0 : (idx == 1 ? 120.0 : 100.0);
                final color = isWinner
                    ? Colors.amber
                    : (idx == 1 ? Colors.grey.shade300 : Colors.brown.shade300);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${p.score}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: height,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
