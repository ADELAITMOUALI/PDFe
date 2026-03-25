import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'models/pdf_file.dart';
import 'screens/home_screen.dart';
import 'screens/pdf_viewer_screen.dart';
import 'services/file_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF141414),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PDFeApp());
}

class PDFeApp extends StatefulWidget {
  const PDFeApp({super.key});

  @override
  State<PDFeApp> createState() => _PDFeAppState();
}

class _PDFeAppState extends State<PDFeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initIntentHandling();
  }

  void _initIntentHandling() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Handle initial intent (app opened via a PDF file)
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path.isNotEmpty && path.toLowerCase().endsWith('.pdf')) {
          _openFileFromPath(path);
        }
      }
    });

    // Handle subsequent intents (app already running)
    ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path.isNotEmpty && path.toLowerCase().endsWith('.pdf')) {
          _openFileFromPath(path);
        }
      }
    });
  }

  Future<void> _openFileFromPath(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final stat = await file.stat();
      final name = path.split('/').last;
      final pdfFile = PdfFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        path: path,
        openedAt: DateTime.now(),
        sizeBytes: stat.size,
      );
      await FileService.addRecentFile(pdfFile);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => PdfViewerScreen(file: pdfFile),
        ));
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDFe',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF2F2F2),
          onPrimary: Color(0xFF141414),
          secondary: Color(0xFF333333),
          onSecondary: Color(0xFFF2F2F2),
          surface: Color(0xFF1E1E1E),
          onSurface: Color(0xFFF2F2F2),
          surfaceContainerHighest: Color(0xFF1E1E1E),
          error: Color(0xFFEF4444),
          onError: Color(0xFFF2F2F2),
          outline: Color(0xFF333333),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: Color(0xFF333333)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          foregroundColor: Color(0xFFF2F2F2),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF333333),
          thickness: 1,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const HomeScreen(),
    );
  }
}
