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
        final extra = state.extra as Map<String, dynamic>?;
        final nickname = extra?['nickname'] as String? ?? 'Player';
        final roomId = extra?['roomId'] as String? ?? '';
        final avatar = extra?['avatar'] as Map<String, dynamic>?;
        return GameScreen(nickname: nickname, roomId: roomId, avatar: avatar);
      },
    ),
  ],
);
