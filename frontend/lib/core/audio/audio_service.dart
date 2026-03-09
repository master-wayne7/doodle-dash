import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class AudioService {
  final List<AudioPlayer> _pool = [];

  AudioPlayer _getPlayer() {
    final player = AudioPlayer(
      playerId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _pool.add(player);
    return player;
  }

  Future<void> _play(String path) async {
    final player = _getPlayer();

    await player.play(AssetSource(path));

    player.onPlayerComplete.listen((_) {
      player.dispose();
      _pool.remove(player);
    });
  }

  void playJoin() => _play('audio/join.ogg');
  void playLeave() => _play('audio/leave.ogg');
  void playPlayerGuessed() => _play('audio/playerGuessed.ogg');
  void playRoundEndFailure() => _play('audio/roundEndFailure.ogg');
  void playRoundEndSuccess() => _play('audio/roundEndSuccess.ogg');
  void playRoundStart() => _play('audio/roundStart.ogg');

  AudioPlayer? _tickPlayer;

  Future<void> startTick() async {
    if (_tickPlayer != null) return;

    _tickPlayer = AudioPlayer(
      playerId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await _tickPlayer!.setReleaseMode(ReleaseMode.loop);
    await _tickPlayer!.play(AssetSource('audio/tick.ogg'));
  }

  Future<void> stopTick() async {
    await _tickPlayer?.stop();
    await _tickPlayer?.dispose();
    _tickPlayer = null;
  }

  void dispose() {
    stopTick();
  }
}
