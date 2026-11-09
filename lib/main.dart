import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/monitor_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SalaMonitorApp());
}

class SalaMonitorApp extends StatefulWidget {
  const SalaMonitorApp({super.key});

  @override
  State<SalaMonitorApp> createState() => _SalaMonitorAppState();
}

class _SalaMonitorAppState extends State<SalaMonitorApp> {
  final MonitorController _controller = MonitorController();
  late final Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sala Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F8A5B),
          brightness: Brightness.dark,
          surface: const Color(0xFF121820),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E141B),
        fontFamily: 'Segoe UI',
      ),
      home: FutureBuilder<void>(
        future: _boot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeScreen(controller: _controller);
        },
      ),
    );
  }
}
