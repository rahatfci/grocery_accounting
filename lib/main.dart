import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Accounting di Quattro Nero',
      color: Colors.white,
      theme: ThemeData(
        fontFamily: 'CenturyGothic',
        colorSchemeSeed: const Color(0xFF244F3D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF244F3D),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Grocery Accounting')),
        body: const Center(child: Text('Flutter Demo Home Page')),
      ),
    );
  }
}
