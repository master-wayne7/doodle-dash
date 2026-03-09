import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/websocket/websocket_service.dart';
import 'package:frontend/core/audio/audio_service.dart';
import 'package:frontend/features/game/models/game_state.dart';
import 'package:frontend/features/game/models/player.dart';

/// An immutable data class holding the entire state of the game for the frontend UI.
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
  final bool isKicked;

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
    this.isKicked = false,
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
    bool? isKicked,
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
      isKicked: isKicked ?? this.isKicked,
    );
  }
}

/// Manages the game state and handles bidirectional WebSocket communication with the backend.
class GameNotifier extends Notifier<GameStateModel> {
  StreamSubscription? _sub;

  @override
  GameStateModel build() {
    return GameStateModel();
  }

  /// Initializes the game provider, connects to the WebSocket, and joins the room.
  void init(String nickname, String roomId, [Map<String, dynamic>? avatar]) {
    state = state.copyWith(nickname: nickname, roomId: roomId);
    final wsService = ref.read(webSocketServiceProvider);

    _sub = wsService.messageStream.listen(_handleMessage);
    wsService.connect('ws://localhost:8080/ws');

    Future.delayed(const Duration(milliseconds: 500), () {
      wsService.sendMessage({
        'type': 'join_room',
        'nickname': nickname,
        'room_id': roomId,
        'avatar': avatar ?? {'color': 11, 'eyes': 30, 'mouth': 23},
      });
    });
  }

  /// Central handler for parsing and applying all incoming WebSocket messages.
  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'players':
        final pList = data['players'] as List;
        final players = pList.map((p) => Player.fromJson(p)).toList();

        if (players.length > state.players.length) {
          ref.read(audioServiceProvider).playJoin();
        } else if (players.length < state.players.length) {
          ref.read(audioServiceProvider).playLeave();
        }

        final me = players.firstWhere(
          (p) => p.nickname == state.nickname,
          orElse: () => Player(
            id: '',
            nickname: state.nickname,
            score: 0,
            turnScore: 0,
            isDrawer: false,
            guessedWord: false,
            voted: false,
            avatar: AvatarData(color: 11, eyes: 30, mouth: 23),
          ),
        );
        state = state.copyWith(players: players, isDrawer: me.isDrawer);
        break;

      case 'game_state':
        final gameState = parseGameState(data['state']);
        final oldState = state.state;

        if (oldState == GameState.choosing && gameState == GameState.drawing) {
          ref.read(audioServiceProvider).playRoundStart();
        } else if (oldState == GameState.drawing && gameState == GameState.turnEnd) {
          ref.read(audioServiceProvider).stopTick();

          final me = state.players.firstWhere(
            (p) => p.nickname == state.nickname,
            orElse: () => Player(
              id: '',
              nickname: '',
              score: 0,
              turnScore: 0,
              isDrawer: false,
              guessedWord: false,
              voted: false,
              avatar: AvatarData(color: 0, eyes: 0, mouth: 0),
            ),
          );

          bool anyoneGuessed = state.players.any((p) => !p.isDrawer && p.guessedWord);

          if (me.isDrawer) {
            if (anyoneGuessed) {
              ref.read(audioServiceProvider).playRoundEndSuccess();
            } else {
              ref.read(audioServiceProvider).playRoundEndFailure();
            }
          } else {
            if (me.guessedWord) {
              ref.read(audioServiceProvider).playRoundEndSuccess();
            } else {
              ref.read(audioServiceProvider).playRoundEndFailure();
            }
          }
        }

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
        if (msg.endsWith('guessed the word!')) {
          ref.read(audioServiceProvider).playPlayerGuessed();
        }

        String color = 'green';
        if (msg.endsWith('has joined the room')) {
          color = 'blue';
        } else if (msg.endsWith('has left the room')) {
          color = 'red';
        } else if (msg.contains('voted to kick')) {
          color = 'yellow';
        }

        final newChats = List<Map<String, String>>.from(state.chatMessages)
          ..add({
            'sender': 'System',
            'content': msg,
            'isSystem': 'true',
            'color': color,
            'colorIndex': '${state.chatMessages.length % 2}',
          });
        state = state.copyWith(systemMessage: msg, chatMessages: newChats);
        break;

      case 'kicked':
        state = state.copyWith(isKicked: true);
        break;

      case 'chat':
        String color = 'black';
        if (data['isShadow'] == 'true') {
          color = 'shadow';
        }
        if (data['content'] != null && (data['content'] as String).endsWith('is close!')) {
          color = 'yellow';
        }

        final newChats = List<Map<String, String>>.from(state.chatMessages)
          ..add({
            'sender': data['sender'],
            'content': data['content'],
            'isSystem': data['isSystem'] ?? 'false',
            'isShadow': data['isShadow'] ?? 'false',
            'color': color,
            'colorIndex': '${state.chatMessages.length % 2}',
          });
        state = state.copyWith(chatMessages: newChats);
        break;

      case 'vote_update':
        final newChats = List<Map<String, String>>.from(state.chatMessages)
          ..add({'sender': data['sender'], 'voteType': data['vote'], 'isVote': 'true', 'isSystem': 'false'});
        state = state.copyWith(chatMessages: newChats);
        break;

      case 'word_choices':
        final words = List<String>.from(data['words']);
        state = state.copyWith(wordChoices: words);
        break;

      case 'timer':
        final time = data['time_left'] as int;
        if (state.state == GameState.drawing) {
          if (time <= 10 && time > 0) {
            ref.read(audioServiceProvider).startTick();
          } else if (time <= 0) {
            ref.read(audioServiceProvider).stopTick();
          }
        } else {
          ref.read(audioServiceProvider).stopTick();
        }
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

  /// Sends a chat message or guess to the backend.
  void sendChat(String content) {
    ref.read(webSocketServiceProvider).sendMessage({'type': 'chat', 'content': content});
  }

  /// Casts a vote (like/dislike) on the current drawing.
  void vote(String voteType) {
    ref.read(webSocketServiceProvider).sendMessage({'type': 'vote', 'vote': voteType});
  }

  /// Submits the drawer's chosen word to the backend.
  void chooseWord(String word) {
    ref.read(webSocketServiceProvider).sendMessage({'type': 'choose_word', 'word': word});
    state = state.copyWith(wordChoices: []);
  }

  /// Sends an individual drawing action (stroke, clear, fill) to the backend.
  void sendDrawAction(Map<String, dynamic> action) {
    final payload = Map<String, dynamic>.from(action);
    payload['type'] = 'draw';
    ref.read(webSocketServiceProvider).sendMessage(payload);
  }

  /// Casts a vote to kick a specific player from the room.
  void sendKickVote(String targetId) {
    ref.read(webSocketServiceProvider).sendMessage({'type': 'vote_kick', 'target': targetId});
  }

  /// Cleans up resources, cancels subscriptions, and disconnects the WebSocket.
  void disposeGame() {
    _sub?.cancel();
    ref.read(audioServiceProvider).stopTick();
    ref.read(webSocketServiceProvider).disconnect();
  }
}

/// The primary Riverpod provider for accessing and modifying the game state.
final gameProvider = NotifierProvider<GameNotifier, GameStateModel>(GameNotifier.new);
