import 'package:flutter/material.dart';

void main() {
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
        colorSchemeSeed: Color(int.parse('FF244F3D', radix: 16)),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(int.parse('FF244F3D', radix: 16)),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Grocery Accounting')),
        body: Center(child: const Text('Flutter Demo Home Page')),
      ),
    );
  }
}
