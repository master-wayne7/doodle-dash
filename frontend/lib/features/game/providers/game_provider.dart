import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/websocket/websocket_service.dart';
import 'package:frontend/features/game/models/game_state.dart';
import 'package:frontend/features/game/models/player.dart';

class GameStateModel {
  final List<Player> players;
  final GameState state;
  final String currentWordLength;
  final List<String> wordChoices;
  final String? systemMessage;
  final List<Map<String, String>> chatMessages;
  final bool isDrawer;
  final String roomId;
  final String nickname;
  final int timeLeft;
  final int round;
  final int maxRounds;
  final String drawerName;
  final String hint;
  final String word;

  GameStateModel({
    this.players = const [],
    this.state = GameState.lobby,
    this.currentWordLength = '',
    this.wordChoices = const [],
    this.systemMessage,
    this.chatMessages = const [],
    this.isDrawer = false,
    this.roomId = '',
    this.nickname = '',
    this.timeLeft = 0,
    this.round = 0,
    this.maxRounds = 3,
    this.drawerName = '',
    this.hint = '',
    this.word = '',
  });

  GameStateModel copyWith({
    List<Player>? players,
    GameState? state,
    String? currentWordLength,
    List<String>? wordChoices,
    String? systemMessage,
    List<Map<String, String>>? chatMessages,
    bool? isDrawer,
    String? roomId,
    String? nickname,
    int? timeLeft,
    int? round,
    int? maxRounds,
    String? drawerName,
    String? hint,
    String? word,
  }) {
    return GameStateModel(
      players: players ?? this.players,
      state: state ?? this.state,
      currentWordLength: currentWordLength ?? this.currentWordLength,
      wordChoices: wordChoices ?? this.wordChoices,
      systemMessage: systemMessage ?? this.systemMessage,
      chatMessages: chatMessages ?? this.chatMessages,
      isDrawer: isDrawer ?? this.isDrawer,
      roomId: roomId ?? this.roomId,
      nickname: nickname ?? this.nickname,
      timeLeft: timeLeft ?? this.timeLeft,
      round: round ?? this.round,
      maxRounds: maxRounds ?? this.maxRounds,
      drawerName: drawerName ?? this.drawerName,
      hint: hint ?? this.hint,
      word: word ?? this.word,
    );
  }
}

class GameNotifier extends Notifier<GameStateModel> {
  StreamSubscription? _sub;

  @override
  GameStateModel build() {
    return GameStateModel();
  }

  void init(String nickname, String roomId) {
    state = state.copyWith(nickname: nickname, roomId: roomId);
    final wsService = ref.read(webSocketServiceProvider);

    _sub = wsService.messageStream.listen(_handleMessage);
    wsService.connect('ws://localhost:8080/ws');

    Future.delayed(const Duration(milliseconds: 500), () {
      wsService.sendMessage({
        'type': 'join_room',
        'nickname': nickname,
        'room_id': roomId,
      });
    });
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'players':
        final pList = data['players'] as List;
        final players = pList.map((p) => Player.fromJson(p)).toList();
        final me = players.firstWhere(
          (p) => p.nickname == state.nickname,
          orElse: () => Player(
            id: '',
            nickname: state.nickname,
            score: 0,
            turnScore: 0,
            isDrawer: false,
            guessedWord: false,
          ),
        );
        state = state.copyWith(players: players, isDrawer: me.isDrawer);
        break;

      case 'game_state':
        final gameState = parseGameState(data['state']);
        state = state.copyWith(
          state: gameState,
          wordChoices: gameState != GameState.choosing ? [] : state.wordChoices,
          round: data['round'],
          maxRounds: data['max_rounds'],
          drawerName: data['drawer'],
          hint: data['hint'] ?? '',
          word: data['word'] ?? '',
        );
        break;

      case 'system':
        final msg = data['content'] as String;
        final newChats = List<Map<String, String>>.from(state.chatMessages)
          ..add({'sender': 'System', 'content': msg, 'isSystem': 'true'});
        state = state.copyWith(systemMessage: msg, chatMessages: newChats);
        break;

      case 'chat':
        final newChats = List<Map<String, String>>.from(state.chatMessages)
          ..add({
            'sender': data['sender'],
            'content': data['content'],
            'isSystem': 'false',
          });
        state = state.copyWith(chatMessages: newChats);
        break;

      case 'word_choices':
        final words = List<String>.from(data['words']);
        state = state.copyWith(wordChoices: words);
        break;

      case 'timer':
        final time = data['time_left'] as int;
        final h = data['hint'] as String?;
        state = state.copyWith(timeLeft: time, hint: h ?? state.hint);
        break;

      case 'joined_room':
        if (state.roomId.isEmpty && data['room_id'] != null) {
          state = state.copyWith(roomId: data['room_id']);
        }
        break;
    }
  }

  void sendChat(String content) {
    ref.read(webSocketServiceProvider).sendMessage({
      'type': 'chat',
      'content': content,
    });
  }

  void chooseWord(String word) {
    ref.read(webSocketServiceProvider).sendMessage({
      'type': 'choose_word',
      'word': word,
    });
    state = state.copyWith(wordChoices: []);
  }

  void sendDrawAction(Map<String, dynamic> action) {
    final payload = Map<String, dynamic>.from(action);
    payload['type'] = 'draw';
    ref.read(webSocketServiceProvider).sendMessage(payload);
  }

  void disposeGame() {
    _sub?.cancel();
    ref.read(webSocketServiceProvider).disconnect();
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameStateModel>(
  GameNotifier.new,
);
