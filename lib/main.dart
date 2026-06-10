import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'views/login_screen.dart';
import 'views/map_screen.dart';
import 'views/inventory_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'JaWa-GO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: session != null ? const MapScreen() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/map': (context) => const MapScreen(),
        '/inventory': (context) => const InventoryScreen(),
      },
    );
  }
}
