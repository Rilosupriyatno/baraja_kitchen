// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keep_screen_on/keep_screen_on.dart'; // Import package keep_screen_on
import 'package:permission_handler/permission_handler.dart';
import 'screens/device_selection_screen.dart';
import 'config/app_theme.dart';
import 'services/background_service.dart';

void main() async {
  // Ensure binding is initialized synchronously
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load dotenv BEFORE runApp to prevent NotInitializedError
  // when DeviceService tries to access BASE_URL
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Dotenv loaded in main()');
  } catch (e) {
    debugPrint('⚠️ Dotenv load error in main(): $e');
  }
  
  // Now run the app - dotenv is guaranteed to be loaded
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
    // Short delay just to let the first frame render
    // dotenv is already loaded in main() so no waiting needed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  Future<void> _initializeApp() async {
    debugPrint('🚀 Starting App Initialization...');
    
    try {
      // dotenv already loaded in main() before runApp()
      
      // 1. Keep screen on
      try {
        KeepScreenOn.turnOn();
        debugPrint('✅ KeepScreenOn enabled');
      } catch (e) {
        debugPrint('⚠️ KeepScreenOn error: $e');
      }

      // 2. Request permissions
      await _requestNotificationPermission();
      debugPrint('✅ Permissions requested');

      // 3. Init background service
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
