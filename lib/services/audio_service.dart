// services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static Future<void> playAlert() async {
    try {
      final player = AudioPlayer(); // bikin baru
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource('audio/alert.mp3'));
    } catch (e) {
      if (kDebugMode) {
        print("Error playAlert: $e");
      }
    }
  }

  static Future<void> playLogin() async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource('audio/login.mp3'));
    } catch (e) {
      if (kDebugMode) {
        print("Error playLogin: $e");
      }
    }
  }

  static Future<void> playDing() async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource('audio/ding.mp3'));
    } catch (e) {
      if (kDebugMode) {
        print("Error playDing: $e");
      }
    }
  }
}
