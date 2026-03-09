import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/home/widgets/avatar_selector.dart';
import 'package:frontend/features/shared/widgets/avatar_display.dart';
import 'package:frontend/features/home/widgets/about_card.dart';
import 'package:frontend/features/home/widgets/how_to_play_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _roomIdController = TextEditingController();

  int _colorIndex = 11;
  int _eyesIndex = 30;
  int _mouthIndex = 23;

  void _joinRoom() {
    final nickname = _nicknameController.text.trim();
    final roomId = _roomIdController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a nickname')));
      return;
    }

    // Navigate to Game Screen using go_router
    context.push(
      '/game',
      extra: {
        'nickname': nickname,
        'roomId': roomId,
        'avatar': {
          'color': _colorIndex,
          'eyes': _eyesIndex,
          'mouth': _mouthIndex,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32.0,
              ).copyWith(bottom: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.webp',
                    width: 336, // Half of 672 for logical sizing
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  // Sample avatars below logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(10, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: AvatarDisplay(
                          colorIndex: index,
                          eyesIndex: index + 10,
                          mouthIndex: index + 20,
                          scale: 1.0, // 48x48
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 30),
                  // Main Interaction Card
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 450,
                      decoration: BoxDecoration(
                        color: const Color(0xBF0C2C96),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 26,
                            color: Colors.white,
                            child: TextField(
                              controller: _nicknameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter your name',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          AvatarSelector(
                            onAvatarChanged: (color, eyes, mouth) {
                              _colorIndex = color;
                              _eyesIndex = eyes;
                              _mouthIndex = mouth;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _joinRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF5DF22F,
                                ), // skribbl green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: const Text(
                                'Play!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2,
                                      color: Colors.black45,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // const SizedBox(height: 8),
                          // SizedBox(
                          //   width: double.infinity,
                          //   child: ElevatedButton(
                          //     onPressed: () {
                          //       // To be implemented later for private rooms
                          //       _joinRoom();
                          //     },
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: const Color(0xFF3388E6), // skribbl light blue
                          //       foregroundColor: Colors.white,
                          //       padding: const EdgeInsets.symmetric(vertical: 16),
                          //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          //     ),
                          //     child: const Text(
                          //       'Create Private Room',
                          //       style: TextStyle(
                          //         fontSize: 20,
                          //         fontWeight: FontWeight.bold,
                          //         shadows: [Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(1, 1))],
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Container(
                    width: double.infinity,
                    color: const Color(
                      0xBF0C2C96,
                    ), // Subtle dark overlay for the bottom section
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 40,
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 30,
                      runSpacing: 30,
                      children: [AboutCard(), HowToPlayCard()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
