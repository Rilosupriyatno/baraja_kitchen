// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keep_screen_on/keep_screen_on.dart'; // Import package keep_screen_on
import 'screens/bar_selection_screen.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Enable keep screen on
  KeepScreenOn.turnOn();

  runApp(BarajaKitchenApp());
}

class BarajaKitchenApp extends StatelessWidget {
  const BarajaKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baraja Workstation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const BarSelectionScreen(),
    );
  }
}