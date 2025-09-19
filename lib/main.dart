// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/kitchen_dashboard.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  runApp(BarajaKitchenApp());
}

class BarajaKitchenApp extends StatelessWidget {
  const BarajaKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baraja Kitchen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: KitchenDashboard(),
    );
  }
}