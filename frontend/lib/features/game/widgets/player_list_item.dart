import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doodle_dash/features/game/providers/game_provider.dart';
import 'package:doodle_dash/features/game/models/player.dart';
import 'package:doodle_dash/features/shared/widgets/avatar_display.dart';

/// Represents an individual player row within the [PlayerList], handling kick votes and temporary chat/vote bubbles.
class PlayerListItem extends ConsumerStatefulWidget {
  final Player player;
  final int rank;
  final bool isEven;
  final GameStateModel gameState;
  final double listWidth;

  const PlayerListItem({
    super.key,
    required this.player,
    required this.rank,
    required this.isEven,
    required this.gameState,
    required this.listWidth,
  });

  @override
  ConsumerState<PlayerListItem> createState() => PlayerListItemState();
}

class PlayerListItemState extends ConsumerState<PlayerListItem> {
  Timer? _bubbleTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void didUpdateWidget(PlayerListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameState.chatMessages.length > oldWidget.gameState.chatMessages.length) {
      final latestMsg = widget.gameState.chatMessages.last;

      if (latestMsg['sender'] == widget.gameState.nickname) return;

      if (latestMsg['sender'] == widget.player.nickname) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (latestMsg['isVote'] == 'true') {
            final voteType = latestMsg['voteType'];
            _showVoteBubble(voteType == 'like');
            _resetTimer();
          } else if (latestMsg['isSystem'] != 'true') {
            final msgContent = latestMsg['content'] ?? '';
            final displayMsg = msgContent.length > 15 ? '${msgContent.substring(0, 15)}...' : msgContent;
            _showTextBubble(displayMsg);
            _resetTimer();
          }
        });
      }
    }
  }

  void _resetTimer() {
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _hideBubble();
      }
    });
  }

  void _showTextBubble(String msg) {
    _hideBubble();
    _overlayEntry = _createOverlayEntry(
      child: Text(msg, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showVoteBubble(bool isLike) {
    _hideBubble();
    _overlayEntry = _createOverlayEntry(
      child: Image.asset(isLike ? 'assets/images/thumbsup.gif' : 'assets/images/thumbsdown.gif', width: 24, height: 24),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry({required Widget child}) {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(widget.listWidth, 5),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideBubble() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showKickDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(255, 12, 44, 150),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarDisplay(
                colorIndex: widget.player.avatar.color,
                eyesIndex: widget.player.avatar.eyes,
                mouthIndex: widget.player.avatar.mouth,
                scale: 1.0,
              ),
              const SizedBox(height: 4),
              Text(
                widget.player.nickname,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(gameProvider.notifier).sendKickVote(widget.player.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2CB3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Vote Kick'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideBubble();
    _bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.player.nickname == widget.gameState.nickname ? null : _showKickDialog,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: widget.player.guessedWord
                ? (widget.isEven ? Colors.green.shade400 : Colors.green.shade300)
                : (widget.isEven ? Colors.white : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text('#${widget.rank}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.player.nickname == widget.gameState.nickname
                          ? '${widget.player.nickname} (You)'
                          : widget.player.nickname,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('${widget.player.score} points', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              if (widget.player.isDrawer) Image.asset("assets/images/pen.gif", width: 30, height: 30),
              const SizedBox(width: 8),
              AvatarDisplay(
                colorIndex: widget.player.avatar.color,
                eyesIndex: widget.player.avatar.eyes,
                mouthIndex: widget.player.avatar.mouth,
                scale: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
