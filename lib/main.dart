import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:route_guard/supabase_options.dart';
import 'package:route_guard/screens/login_screen.dart';
import 'package:route_guard/screens/signup_screen.dart';
import 'package:route_guard/screens/map_screen.dart';
import 'package:route_guard/web/screens/dashboard_screen.dart';
import 'package:route_guard/services/service_locator.dart';

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
  await ServiceLocator().initialize(); // Initialize services
  runApp(const RouteGuardApp());
}

class RouteGuardApp extends StatelessWidget {
  const RouteGuardApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RouteGuard',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const MapScreen(), // Changed to MapScreen
        '/agency/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('RouteGuard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}