import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:route_guard/supabase_options.dart';
import 'package:route_guard/web/theme.dart';
import 'package:route_guard/web/screens/request_access_screen.dart';
import 'package:route_guard/web/screens/dashboard_screen.dart';
import 'package:route_guard/web/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBUYmKObCQ39cb_yqA8CC9YAeKK3ujb_kI",
      appId: "1:30604162158:web:8003c029c473e1032d627f",
      messagingSenderId: "30604162158",
      projectId: "routeguard-cfb79",
    ),
  );

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Ignore missing env file in environments where configuration is supplied another way.
  }

  await SupabaseOptions.initialize(); // Initialize Supabase
  runApp(const AgencyWebApp());
}

class AgencyWebApp extends StatelessWidget {
  const AgencyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteGuard Agency Dashboard',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const RequestAccessScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}