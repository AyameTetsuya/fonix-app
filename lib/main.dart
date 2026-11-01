import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'domain/curriculum.dart';
import 'domain/learning.dart';
import 'platform/device.dart';
import 'ui/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const FonixApp());
}

class FonixApp extends StatefulWidget {
  final Device? device;
  final Curriculum? curriculum;
  const FonixApp({super.key, this.device, this.curriculum});
  @override State<FonixApp> createState() => _FonixAppState();
}

class _FonixAppState extends State<FonixApp> {
  late Future<AppController> loading;
  @override void initState() { super.initState(); loading = load(); }
  Future<AppController> load() async {
    final device = widget.device ?? AndroidDevice();
    final c = widget.curriculum ?? Curriculum.decode(
      await rootBundle.loadString('assets/data/curriculum.json'));
    final state = LearningState.decode(await device.load());
    return AppController(c, device, state);
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'わくわくフォニックス', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFFAF8F1),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF275D50),
        primary: const Color(0xFF275D50), secondary: const Color(0xFFEF9C57),
        surface: const Color(0xFFFFFEF8)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.5),
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 17, height: 1.7),
        bodyMedium: TextStyle(fontSize: 15, height: 1.6)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52), textStyle: const TextStyle(fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16))),
    ),
    home: FutureBuilder<AppController>(future: loading, builder: (context, snapshot) {
      if (snapshot.hasError) return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.folder_off_outlined, size: 56), const SizedBox(height: 16),
          const Text('がくしゅうデータを よみこめませんでした。\nデータを けさずに、もういちど おためしください。', textAlign: TextAlign.center),
          const SizedBox(height: 20), FilledButton(onPressed: () => setState(() { loading = load(); }),
            child: const Text('もういちど よみこむ')),
        ]))));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return AppShell(controller: snapshot.data!);
    }),
  );
}
