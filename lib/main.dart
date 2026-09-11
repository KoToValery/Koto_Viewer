import 'dart:io';
import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/services/intent_service.dart';
import 'src/core/services/local_server_service.dart';
import 'src/core/services/coordinate_system_service.dart';
import 'src/core/services/file_opener_service.dart';
import 'src/features/home/home_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CoordinateSystemService.init();
  String? initialFile;
  if (args.isNotEmpty && File(args.first).existsSync()) {
    initialFile = args.first;
  }
  runApp(KotoViewApp(initialFilePath: initialFile));
}

class KotoViewApp extends StatefulWidget {
  final String? initialFilePath;
  const KotoViewApp({super.key, this.initialFilePath});

  @override
  State<KotoViewApp> createState() => _KotoViewAppState();
}

class _KotoViewAppState extends State<KotoViewApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final IntentService _intentService = IntentService();
  bool _isDarkMode = false;
  String? _pendingFilePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
      _pendingFilePath = widget.initialFilePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPendingFile();
      });
    }

    _intentService.listenForFileIntents((filePath) {
      if (filePath.isNotEmpty) {
        _pendingFilePath = filePath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processPendingFile();
        });
      }
    });
  }

  void _processPendingFile() {
    final path = _pendingFilePath;
    if (path != null && path.isNotEmpty) {
      _pendingFilePath = null;
      _openFileScreen(path);
    }
  }

  Future<void> _openFileScreen(String filePath) async {
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) {
      _pendingFilePath = filePath;
      return;
    }

    await FileOpenerService.openFile(
      context: context,
      filePath: filePath,
      navigator: navigator,
      messenger: _messengerKey.currentState,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        LocalServerService.stopServer();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.resumed:
        _processPendingFile();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalServerService.stopServer();
    _intentService.dispose();
    super.dispose();
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'KoToViewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeData(),
      darkTheme: AppTheme.darkThemeData(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}
