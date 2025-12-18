// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keep_screen_on/keep_screen_on.dart'; // Import package keep_screen_on
import 'package:permission_handler/permission_handler.dart';
import 'screens/device_selection_screen.dart';
import 'config/app_theme.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Enable keep screen on
  KeepScreenOn.turnOn();

  // Initialize background service (non-blocking - runs in parallel)
  // This just configures the service, doesn't start it yet
  BackgroundService.initialize().catchError((e) {
    debugPrint('⚠️ Background service init warning: $e');
  });

  // Request notification permission for Android 13+
  await _requestNotificationPermission();

  runApp(BarajaKitchenApp());
}

/// Request notification permission for Android 13+
Future<void> _requestNotificationPermission() async {
  try {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  } catch (e) {
    debugPrint('⚠️ Error requesting notification permission: $e');
  }
}

class BarajaKitchenApp extends StatelessWidget {
  const BarajaKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baraja Workstation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const DeviceSelectionScreen(),
    );
  }
}