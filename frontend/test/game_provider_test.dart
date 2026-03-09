import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/websocket/websocket_service.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/game_state.dart';

// Mock WebSocketService to intercept connect/sendMessage
class MockWebSocketService extends WebSocketService {
  final StreamController<Map<String, dynamic>> _mockController = StreamController.broadcast();
  List<Map<String, dynamic>> sentMessages = [];
  bool isConnected = false;

  @override
  Stream<Map<String, dynamic>> get messageStream => _mockController.stream;

  @override
  void connect(String url) {
    isConnected = true;
  }

  @override
  void sendMessage(Map<String, dynamic> data) {
    sentMessages.add(data);
  }

  @override
  void disconnect() {
    isConnected = false;
    _mockController.close();
  }

  // Helper to simulate server sending a message
  void simulateServerMessage(Map<String, dynamic> data) {
    _mockController.add(data);
  }
}

void main() {
  test('GameNotifier initialization sends join_room event', () async {
    final mockWs = MockWebSocketService();
    final container = ProviderContainer(overrides: [webSocketServiceProvider.overrideWithValue(mockWs)]);

    // Initialize provider with test data
    container.read(gameProvider.notifier).init('Tester', 'Room123');

    // State should be updated
    final state = container.read(gameProvider);
    expect(state.nickname, 'Tester');
    expect(state.roomId, 'Room123');
    expect(mockWs.isConnected, true);

    // Give the delayed future time to execute (500ms in init function)
    await Future.delayed(const Duration(milliseconds: 600));

    expect(mockWs.sentMessages.length, 1);
    expect(mockWs.sentMessages[0]['type'], 'join_room');
    expect(mockWs.sentMessages[0]['nickname'], 'Tester');
  });

  test('GameNotifier handles chat events', () async {
    final mockWs = MockWebSocketService();
    final container = ProviderContainer(overrides: [webSocketServiceProvider.overrideWithValue(mockWs)]);

    final notifier = container.read(gameProvider.notifier);

    // Simulate incoming chat message
    mockWs.simulateServerMessage({'type': 'chat', 'sender': 'Player2', 'content': 'Hello world'});

    // We yield to let stream process
    await Future.delayed(Duration.zero);

    final state = container.read(gameProvider);
    expect(state.chatMessages.length, 1);
    expect(state.chatMessages[0]['content'], 'Hello world');
    expect(state.chatMessages[0]['sender'], 'Player2');
    expect(state.chatMessages[0]['isSystem'], 'false');
  });

  test('GameNotifier changes game state appropriately', () async {
    final mockWs = MockWebSocketService();
    final container = ProviderContainer(overrides: [webSocketServiceProvider.overrideWithValue(mockWs)]);

    mockWs.simulateServerMessage({'type': 'game_state', 'state': 'drawing'});

    await Future.delayed(Duration.zero);
    final state = container.read(gameProvider);
    expect(state.state, GameState.drawing);
  });
}
