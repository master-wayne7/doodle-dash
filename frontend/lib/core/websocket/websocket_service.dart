import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _isDisconnectedManually = false;
  int _reconnectAttempts = 0;
  String? _lastUrl;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  void connect(String url) {
    _lastUrl = url;
    _isDisconnectedManually = false;
    _reconnectAttempts = 0;
    _establishConnection();
  }

  void _establishConnection() {
    if (_lastUrl == null || _isDisconnectedManually) return;

    debugPrint('Connecting to $_lastUrl ... (Attempt ${_reconnectAttempts + 1})');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_lastUrl!));

      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0; // Reset on successful message
          try {
            final parts = message.toString().split('\n');
            for (final part in parts) {
              if (part.trim().isEmpty) continue;
              final data = json.decode(part);
              _messageController.add(data);
            }
          } catch (e) {
            debugPrint('Error decoding message: $e\nRaw message: $message');
          }
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _reconnect();
        },
        onDone: () {
          if (!_isDisconnectedManually) {
            debugPrint('WebSocket Disconnected. Reconnecting...');
            _reconnect();
          }
        },
      );
    } catch (e) {
      debugPrint('Connection error: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    if (_isDisconnectedManually) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, up to 30s
    final delay = Duration(seconds: (1 << (_reconnectAttempts > 5 ? 5 : _reconnectAttempts)).clamp(1, 30));

    debugPrint('Reconnecting in ${delay.inSeconds} seconds...');
    Timer(delay, _establishConnection);
  }

  void sendMessage(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(data));
    } else {
      debugPrint('Cannot send message, WebSocket not connected');
    }
  }

  void disconnect() {
    _isDisconnectedManually = true;
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
  }
}
