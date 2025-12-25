// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keep_screen_on/keep_screen_on.dart'; // Import package keep_screen_on
import 'package:permission_handler/permission_handler.dart';
import 'screens/device_selection_screen.dart';
import 'config/app_theme.dart';
import 'services/background_service.dart';

void main() {
  // Ensure binding is initialized synchronously
  WidgetsFlutterBinding.ensureInitialized();
  
  // Don't wait for anything else in main()
  // Just run the app immediately to clear the native splash screen
  runApp(const BarajaKitchenApp());
}

class BarajaKitchenApp extends StatefulWidget {
  const BarajaKitchenApp({super.key});

  @override
  State<BarajaKitchenApp> createState() => _BarajaKitchenAppState();
}

class _BarajaKitchenAppState extends State<BarajaKitchenApp> {
  // State to track if initialization is complete
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Use a slight delay to allow the rendering engine to settle
    // before running potentially heavy initialization
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    debugPrint('🚀 Starting App Initialization...');
    
    try {
      // 1. Load env vars
      await dotenv.load(fileName: ".env");
      debugPrint('✅ Dotenv loaded');

      // 2. Keep screen on
      try {
        KeepScreenOn.turnOn();
        debugPrint('✅ KeepScreenOn enabled');
      } catch (e) {
        debugPrint('⚠️ KeepScreenOn error: $e');
      }

      // 3. Request permissions
      await _requestNotificationPermission();
      debugPrint('✅ Permissions requested');

      // 4. Init background service
      BackgroundService.initialize().then((_) {
        debugPrint('✅ Background service initialized');
      }).catchError((e) {
        debugPrint('⚠️ Background service init error: $e');
      });

    } catch (e) {
      debugPrint('❌ Fatal initialization error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baraja Workstation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Pass initialization state if needed, though DeviceSelectionScreen loads its own data
      home: const DeviceSelectionScreen(),
    );
  }
}
