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
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  void connect(String url) {
    debugPrint('Connecting to $url ...');
    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (message) {
        try {
          // The backend might batch multiple messages together separated by a newline
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
      },
      onDone: () {
        debugPrint('WebSocket Disconnected');
      },
    );
  }

  void sendMessage(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(data));
    } else {
      debugPrint('Cannot send message, WebSocket not connected');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
  }
}
