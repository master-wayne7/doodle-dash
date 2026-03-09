import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';

/// Displays the real-time chat messages, system notifications, and provides an input field for guessing.
class ChatBox extends ConsumerStatefulWidget {
  final double? width;

  const ChatBox({super.key, this.width});

  @override
  ConsumerState<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends ConsumerState<ChatBox> {
  final TextEditingController chatController = TextEditingController();
  final FocusNode chatFocus = FocusNode();
  final ValueNotifier<int> charCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    chatController.addListener(() {
      charCount.value = chatController.text.length;
    });
  }

  @override
  void dispose() {
    chatController.dispose();
    chatFocus.dispose();
    charCount.dispose();
    super.dispose();
  }

  void sendChat(WidgetRef ref) {
    final text = chatController.text.trim();
    if (text.isNotEmpty) {
      ref.read(gameProvider.notifier).sendChat(text);
      chatController.clear();
      chatFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final chatMessages = gameState.chatMessages;
    final isDrawer = gameState.isDrawer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDrawer && !chatFocus.hasFocus) {
        FocusScope.of(context).requestFocus(chatFocus);
      }
    });

    return Container(
      width: widget.width,
      margin: EdgeInsets.only(bottom: 52),
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: chatMessages.where((m) => m['isVote'] != 'true').length,
              itemBuilder: (context, index) {
                final filtered = chatMessages.where((m) => m['isVote'] != 'true').toList();
                final msg = filtered[filtered.length - 1 - index];
                final isSystem = msg['isSystem'] == 'true';
                final isDark = msg['colorIndex'] == '0';
                final colorStr = msg['color'] ?? 'black';

                Color textColor;
                switch (colorStr) {
                  case 'green':
                    textColor = Colors.green.shade700;
                    break;
                  case 'red':
                    textColor = Colors.red.shade700;
                    break;
                  case 'blue':
                    textColor = Colors.blue.shade700;
                    break;
                  case 'yellow':
                    textColor = Colors.orange.shade700;
                    break;
                  case 'shadow':
                    textColor = Colors.green.shade200;
                    break;
                  default:
                    textColor = Colors.black87;
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: msg['content'].toString().contains("guessed")
                        ? isDark
                              ? Colors.green.shade200
                              : Colors.green.shade100
                        : isDark
                        ? Colors.grey.shade200
                        : Colors.white,
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSystem ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Comic Sans MS',
                        fontSize: 14,
                      ),
                      children: [
                        if (!isSystem)
                          TextSpan(
                            text: '${msg['sender']}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        TextSpan(text: msg['content']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatController,
                    focusNode: chatFocus,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Type your chat here...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => sendChat(ref),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ValueListenableBuilder<int>(
                    valueListenable: charCount,
                    builder: (context, count, child) {
                      return Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDrawer ? Colors.grey : Colors.black87,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
