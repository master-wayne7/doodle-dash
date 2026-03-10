import 'package:flutter/material.dart';
import 'package:doodle_dash/features/game/models/player.dart';
import 'package:doodle_dash/features/shared/widgets/avatar_display.dart';

/// A wrapper widget that animates the appearance and disappearance of its child overlay.
class GameOverlayWrapper extends StatefulWidget {
  final Widget child;
  final bool show;

  const GameOverlayWrapper({super.key, required this.child, this.show = true});

  @override
  State<GameOverlayWrapper> createState() => _GameOverlayWrapperState();
}

class _GameOverlayWrapperState extends State<GameOverlayWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.2), // Emerging from slightly above
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    if (widget.show) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(GameOverlayWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward();
    } else if (!widget.show && oldWidget.show) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 52),
      color: const Color.fromARGB(179, 0, 0, 0),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _offsetAnimation, child: widget.child),
      ),
    );
  }
}

/// Overlay shown to guessers while the current drawer is selecting a word.
class WordChoosingOverlay extends StatelessWidget {
  final String drawerName;
  final AvatarData? avatar;

  const WordChoosingOverlay({super.key, required this.drawerName, this.avatar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$drawerName is choosing a word!",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (avatar != null)
            AvatarDisplay(colorIndex: avatar!.color, eyesIndex: avatar!.eyes, mouthIndex: avatar!.mouth, scale: 1.5)
          else
            const CircularProgressIndicator(color: Colors.white),
        ],
      ),
    );
  }
}

/// Overlay shown at the end of a round, displaying the correct word and points awarded.
class TurnEndLeaderboardOverlay extends StatelessWidget {
  final String? systemMessage;
  final String word;
  final List<Player> players;

  const TurnEndLeaderboardOverlay({super.key, required this.systemMessage, required this.word, required this.players});

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = List<Player>.from(players)
      ..sort((a, b) => (b.turnScore as num).compareTo(a.turnScore as num));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70),
              children: [
                const TextSpan(text: "The word was "),
                TextSpan(
                  text: word,
                  style: const TextStyle(color: Color(0xFFFFE082)), // Light yellow
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text("Time is up!", style: TextStyle(fontSize: 20, color: Colors.white54)),
          const SizedBox(height: 32),
          SizedBox(
            width: 250,
            child: Column(
              children: sortedPlayers.map((p) {
                final isPositive = (p.turnScore as num) > 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nickname,
                          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        "${isPositive ? '+' : ''}${p.turnScore}",
                        style: TextStyle(
                          fontSize: 18,
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
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
    );
  }
}

/// Overlay shown to the drawer at the start of their turn to select a word from predefined options.
class WordSelectionOverlay extends StatelessWidget {
  final List<String> words;
  final Function(String) onWordSelected;

  const WordSelectionOverlay({super.key, required this.words, required this.onWordSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Choose a word",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: words.map((word) {
              return _WordButton(word: word, onTap: () => onWordSelected(word));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WordButton extends StatefulWidget {
  final String word;
  final VoidCallback onTap;

  const _WordButton({required this.word, required this.onTap});

  @override
  State<_WordButton> createState() => _WordButtonState();
}

class _WordButtonState extends State<_WordButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _isHovered
              ? ClipRect(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        widget.word,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(179, 0, 0, 0),
                        ),
                      ),
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.clear),
                        child: Text(
                          widget.word,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  widget.word,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      ),
    );
  }
}

/// A simple reusable overlay for displaying full-screen text messages (e.g., "Waiting for players").
class MessageOverlay extends StatelessWidget {
  final String message;

  const MessageOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Overlay displayed briefly at the start of a new round to indicate the round number.
class RoundOverlay extends StatelessWidget {
  final int round;

  const RoundOverlay({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Round $round',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// The final leaderboard overlay shown when the game concludes, featuring a podium for the top 3 players.
class GameOverOverlay extends StatelessWidget {
  final List<Player> players;

  const GameOverOverlay({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = List<Player>.from(players)..sort((a, b) => b.score.compareTo(a.score));
    final winners = sortedPlayers.take(3).toList();
    final others = sortedPlayers.skip(3).toList();
    final winner = winners.isNotEmpty ? winners[0] : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (winner != null)
            Text(
              "${winner.nickname} is the winner!",
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          const SizedBox(height: 48),
          _PodiumView(winners: winners),
          const SizedBox(height: 48),
          if (others.isNotEmpty)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: others.map((p) {
                return Column(
                  children: [
                    AvatarDisplay(
                      colorIndex: p.avatar.color,
                      eyesIndex: p.avatar.eyes,
                      mouthIndex: p.avatar.mouth,
                      scale: 1,
                    ),
                    Text(p.nickname, style: const TextStyle(fontSize: 14, color: Colors.white)),
                    Text("${p.score} pts", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _PodiumView extends StatelessWidget {
  final List<Player> winners;

  const _PodiumView({required this.winners});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd, 1st, 3rd
    final podiumOrder = <Player?>[null, null, null];
    if (winners.length > 1) podiumOrder[0] = winners[1]; // 2nd
    if (winners.isNotEmpty) podiumOrder[1] = winners[0]; // 1st
    if (winners.length > 2) podiumOrder[2] = winners[2]; // 3rd

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: podiumOrder.asMap().entries.map((entry) {
        final idx = entry.key;
        final player = entry.value;
        if (player == null) return const SizedBox(width: 120);

        final isFirst = idx == 1;
        final height = isFirst ? 160.0 : (idx == 0 ? 120.0 : 100.0);
        final color = isFirst
            ? const Color(0xFFFFD700)
            : (idx == 0 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
        final label = isFirst ? "#1" : (idx == 0 ? "#2" : "#3");

        return Container(
          width: 130,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  if (isFirst)
                    Positioned(
                      right: -40,
                      bottom: 0,
                      child: Image.asset('assets/images/trophy.gif', height: 80, fit: BoxFit.cover),
                    ),
                  AvatarDisplay(
                    colorIndex: player.avatar.color,
                    eyesIndex: player.avatar.eyes,
                    mouthIndex: player.avatar.mouth,
                    scale: isFirst ? 2 : 1.5,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomPaint(
                size: Size(130, height),
                painter: _PodiumPainter(color: color, label: label),
                child: Container(
                  width: 130,
                  height: height,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        player.nickname,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      Text("${player.score} points", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PodiumPainter extends CustomPainter {
  final Color color;
  final String label;

  _PodiumPainter({required this.color, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(8, 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
