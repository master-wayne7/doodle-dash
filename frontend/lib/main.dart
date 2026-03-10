import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doodle_dash/core/router/app_router.dart';
import 'package:doodle_dash/core/audio/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DoodleDashApp()));
}

class DoodleDashApp extends ConsumerStatefulWidget {
  const DoodleDashApp({super.key});

  @override
  ConsumerState<DoodleDashApp> createState() => _DoodleDashAppState();
}

class _DoodleDashAppState extends ConsumerState<DoodleDashApp> {
  @override
  void initState() {
    super.initState();
    // Preload audio files as soon as the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Doodle Dash',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF5A4AE3),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A4AE3), secondary: const Color(0xFFFF5E5B)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5A4AE3),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
    );
  }
}
