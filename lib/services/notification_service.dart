// services/notification_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:collection';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Tambahkan dua audio player untuk dua jenis notifikasi
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Queue<String> _notificationQueue = Queue<String>();
  bool _isPlaying = false;

  // Track order IDs yang sudah pernah dinotifikasi
  final Set<String> _notifiedOrders = <String>{};

  /// Memainkan notifikasi untuk order baru
  /// Returns true jika notifikasi ditambahkan ke queue
  Future<bool> playNewOrderNotification(String orderId, {String? soundPath}) async {
    // Cek apakah order ini sudah pernah dinotifikasi
    if (_notifiedOrders.contains(orderId)) {
      if (kDebugMode) {
        print('🔇 Order $orderId sudah pernah dinotifikasi, skip');
      }
      return false;
    }

    // Tandai order sebagai sudah dinotifikasi
    _notifiedOrders.add(orderId);

    // Gunakan sound path custom atau default
    final path = soundPath ?? 'sounds/alert.mp3';

    if (kDebugMode) {
      print('🔔 Menambahkan notifikasi ke queue untuk order: $orderId');
    }

    // Tambahkan ke queue
    _notificationQueue.add(path);

    // Mulai pemutaran jika belum ada yang playing
    if (!_isPlaying) {
      _processQueue();
    }

    return true;
  }

  /// Memproses queue notifikasi satu per satu
  Future<void> _processQueue() async {
    if (_notificationQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    final soundPath = _notificationQueue.removeFirst();

    try {
      if (kDebugMode) {
        print('🔊 Memutar notifikasi: $soundPath');
      }

      // Set audio player mode
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      // Putar audio
      await _audioPlayer.play(AssetSource(soundPath));

      // Tunggu sampai selesai
      await _audioPlayer.onPlayerComplete.first;

      if (kDebugMode) {
        print('✅ Notifikasi selesai diputar');
      }

      // Delay kecil sebelum notifikasi berikutnya
      await Future.delayed(const Duration(milliseconds: 500));

      // Proses notifikasi berikutnya
      _processQueue();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error memutar notifikasi: $e');
      }
      // Tetap lanjutkan ke notifikasi berikutnya
      _processQueue();
    }
  }

  /// Menghapus order dari daftar notifikasi (opsional, untuk reset)
  void removeNotifiedOrder(String orderId) {
    _notifiedOrders.remove(orderId);
  }

  /// Clear semua notifikasi yang sudah pernah diputar (untuk reset)
  void clearNotificationHistory() {
    _notifiedOrders.clear();
    if (kDebugMode) {
      print('🗑️ History notifikasi dibersihkan');
    }
  }

  /// Stop audio yang sedang diputar
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
  }

  /// Clear queue dan stop
  Future<void> clearQueue() async {
    _notificationQueue.clear();
    await stop();
  }

  /// Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }

  // Getter untuk debugging
  int get queueLength => _notificationQueue.length;
  bool get isPlaying => _isPlaying;
  int get notifiedCount => _notifiedOrders.length;
}