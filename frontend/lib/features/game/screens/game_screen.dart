import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doodle_dash/features/game/providers/game_provider.dart';
import 'package:doodle_dash/features/game/models/game_state.dart';
import 'package:doodle_dash/features/game/widgets/drawing_board.dart';
import 'package:doodle_dash/features/game/widgets/player_list.dart';
import 'package:doodle_dash/features/game/widgets/chat_box.dart';
import 'package:doodle_dash/features/game/widgets/top_bar.dart';
import 'package:doodle_dash/features/game/widgets/game_overlays.dart';

/// The primary screen for the Skribbl game.
/// It initializes the WebSocket connection and arranges the layout based on screen size.
class GameScreen extends ConsumerStatefulWidget {
  final String nickname;
  final String roomId;
  final Map<String, dynamic>? avatar;

  const GameScreen({super.key, required this.nickname, required this.roomId, this.avatar});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProvider.notifier).init(widget.nickname, widget.roomId, widget.avatar);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameProvider, (previous, next) {
      if (next.isKicked && !(previous?.isKicked ?? false)) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromARGB(255, 12, 44, 150),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            title: const Text(
              'Kicked Out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            content: const Text('You have been kicked out of the room.', style: TextStyle(color: Colors.white)),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    context.go('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2CB3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      }
    });

    final gameStateModel = ref.watch(gameProvider);
    final isDrawer = gameStateModel.isDrawer;
    final gameState = gameStateModel.state;
    final wordChoices = gameStateModel.wordChoices;
    final systemMessage = gameStateModel.systemMessage;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/background.png'), repeat: ImageRepeat.repeat),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 64.0),
                child: Image.asset('assets/images/logo.webp', height: 80, fit: BoxFit.contain),
              ),

              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1800),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      children: [
                        const TopBar(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 800) {
                                // Desktop Layout
                                return Row(
                                  children: [
                                    const PlayerList(width: 250),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// A helper widget that builds the central game area, including the drawing board and overlays.
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

    return Stack(
      children: [
        DrawingBoard(isDrawer: isDrawer),
        if (gameState == GameState.choosing)
          GameOverlayWrapper(
            show: true,
            child: isDrawer && wordChoices.isNotEmpty
                ? WordSelectionOverlay(
                    words: wordChoices,
                    onWordSelected: (word) => ref.read(gameProvider.notifier).chooseWord(word),
                  )
                : WordChoosingOverlay(
                    drawerName: ref.read(gameProvider).drawerName,
                    avatar: ref.read(gameProvider).players.where((p) => p.isDrawer).firstOrNull?.avatar,
                  ),
          ),
        if (gameState == GameState.lobby)
          GameOverlayWrapper(show: true, child: const MessageOverlay(message: 'Waiting for players to join...')),
        if (gameState == GameState.starting)
          GameOverlayWrapper(show: true, child: MessageOverlay(message: 'Starting in ${timeLeft}s...')),
        if (gameState == GameState.round)
          GameOverlayWrapper(show: true, child: RoundOverlay(round: ref.read(gameProvider).round)),
        if (gameState == GameState.turnEnd)
          GameOverlayWrapper(
            show: true,
            child: TurnEndLeaderboardOverlay(
              systemMessage: systemMessage,
              word: ref.read(gameProvider).word,
              players: ref.read(gameProvider).players,
            ),
          ),
        if (gameState == GameState.gameOver)
          GameOverlayWrapper(show: true, child: GameOverOverlay(players: ref.read(gameProvider).players)),
      ],
    );
  }
}
