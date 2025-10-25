// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // Tambahkan import ini
import 'screens/bar_selection_screen.dart';

import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Aktifkan wakelock agar device tidak sleep
  WakelockPlus.enable();

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