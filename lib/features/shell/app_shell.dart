import 'package:flutter/material.dart';

import '../../theme.dart';
import '../grammar/grammar_list_screen.dart';
import '../home/home_screen.dart';
import '../review/review_screen.dart';
import '../vocabulary/vocabulary_list_screen.dart';

/// Persistent 4-tab shell (Tổng quan / Từ vựng / Ôn tập / Ngữ pháp) shown
/// once onboarding is done — matches the bottom nav in every mockup screen.
/// Settings is reached via the icon on Home, not a tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    VocabularyListScreen(),
    ReviewScreen(),
    GrammarListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent700,
        unselectedItemColor: AppColors.neutral600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Từ vựng'),
          BottomNavigationBarItem(icon: Icon(Icons.refresh), label: 'Ôn tập'),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Ngữ pháp'),
        ],
      ),
    );
  }
}
