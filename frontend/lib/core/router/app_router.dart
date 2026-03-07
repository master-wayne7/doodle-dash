import 'package:go_router/go_router.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/game/screens/game_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/game',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final nickname = extra?['nickname'] ?? 'Player';
        final roomId = extra?['roomId'] ?? '';
        return GameScreen(nickname: nickname, roomId: roomId);
      },
    ),
  ],
);
