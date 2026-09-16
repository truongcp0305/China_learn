import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

class ChineseLearnApp extends StatelessWidget {
  const ChineseLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chinese Learn',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
