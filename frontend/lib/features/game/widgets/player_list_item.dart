import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/player.dart';

class PlayerListItem extends StatefulWidget {
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
  State<PlayerListItem> createState() => PlayerListItemState();
}

class PlayerListItemState extends State<PlayerListItem> {
  Timer? _bubbleTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void didUpdateWidget(PlayerListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameState.chatMessages.length >
        oldWidget.gameState.chatMessages.length) {
      final latestMsg = widget.gameState.chatMessages.last;

      // Hide bubbles for the user themselves
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
            final displayMsg = msgContent.length > 15
                ? '${msgContent.substring(0, 15)}...'
                : msgContent;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showVoteBubble(bool isLike) {
    _hideBubble();
    _overlayEntry = _createOverlayEntry(
      child: Icon(
        isLike ? Icons.thumb_up : Icons.thumb_down,
        color: isLike ? Colors.green : Colors.red,
        size: 24,
      ),
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
            offset: Offset(widget.listWidth - 10, 15),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: widget.player.guessedWord
              ? Colors.green.shade100
              : (widget.isEven ? Colors.white : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              '#${widget.rank}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.player.nickname == widget.gameState.nickname
                          ? Colors.blue
                          : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.player.score} points',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (widget.player.isDrawer)
              const Icon(Icons.brush, size: 20, color: Colors.amber),
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
