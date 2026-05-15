import 'package:flutter/material.dart';
import '../category_browser_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/ingestion_workflow_screen.dart';
import '../screens/settings_screen.dart';
import '../services/rag_service.dart';
import '../main.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final RagService _ragService = RagService(objectBox.store);

  late final List<Widget> _screens = [
    CategoryBrowserScreen(ragService: _ragService),
    const IngestionWorkflowScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/bg.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _selectedIndex != 1
            ? FloatingActionButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                backgroundColor: const Color(0xFFB388FF),
                foregroundColor: Colors.white,
                elevation: 6,
                shape: const CircleBorder(),
                child: const Icon(Icons.upload_file_rounded, size: 26),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              _buildNavigationRail(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _screens[_selectedIndex],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelType: NavigationRailLabelType.none,
        useIndicator: false,
        destinations: [
          _buildRailDestination(Icons.library_books, 'Library', 0),
          _buildRailDestination(Icons.auto_awesome, 'Workflow', 1),
          _buildRailDestination(Icons.analytics_outlined, 'Analytics', 2),
          _buildRailDestination(Icons.settings_outlined, 'Settings', 3),
        ],
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return NavigationRailDestination(
      icon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB388FF) : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          boxShadow: isSelected ? [const BoxShadow(color: Color(0x66B388FF), blurRadius: 10)] : null,
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 24),
      ),
      label: Text(label),
    );
  }
}
