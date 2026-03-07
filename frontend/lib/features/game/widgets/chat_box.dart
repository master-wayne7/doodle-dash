import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/game/providers/game_provider.dart';

class ChatBox extends ConsumerStatefulWidget {
  final double? width;

  const ChatBox({super.key, this.width});

  @override
  ConsumerState<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends ConsumerState<ChatBox> {
  final TextEditingController chatController = TextEditingController();

  void sendChat(WidgetRef ref) {
    final text = chatController.text.trim();
    if (text.isNotEmpty) {
      ref.read(gameProvider.notifier).sendChat(text);
      chatController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final chatMessages = gameState.chatMessages;
    final isDrawer = gameState.isDrawer;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final msg = chatMessages[chatMessages.length - 1 - index];
                final isSystem = msg['isSystem'] == 'true';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isSystem
                            ? Colors.green.shade700
                            : Colors.black87,
                        fontWeight: isSystem
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: 'Comic Sans MS',
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
                    decoration: const InputDecoration(
                      hintText: 'Type your guess here...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => sendChat(ref),
                    enabled: !isDrawer,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF5A4AE3),
                  onPressed: isDrawer ? null : () => sendChat(ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
