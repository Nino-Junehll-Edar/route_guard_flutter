import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:route_guard/supabase_options.dart';
import 'package:route_guard/web/screens/request_access_screen.dart';
import 'package:route_guard/web/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load environment variables
  await SupabaseOptions.initialize(); // Initialize Supabase
  runApp(const AgencyWebApp());
}

class AgencyWebApp extends StatelessWidget {
  const AgencyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteGuard Agency Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const RequestAccessScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}