import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/translated_text.dart';
import 'all_courses_screen.dart';
import 'chatbot_screen.dart';
import 'dashboard_screen.dart';
import 'features_screen.dart';
import 'contact_us_screen.dart';
import 'account_screen.dart';
import 'wishlist_screen.dart';

/// Wrapper widget that listens to tab change notifications
class AllCoursesScreenWrapper extends StatefulWidget {
  const AllCoursesScreenWrapper({super.key, required this.tabNotifier});

  final ValueNotifier<int> tabNotifier;

  @override
  State<AllCoursesScreenWrapper> createState() => _AllCoursesScreenWrapperState();
}

class _AllCoursesScreenWrapperState extends State<AllCoursesScreenWrapper> {
  final AllCoursesController _coursesController = AllCoursesController();

  @override
  void initState() {
    super.initState();
    widget.tabNotifier.addListener(_onTabChangeRequested);
  }

  @override
  void dispose() {
    widget.tabNotifier.removeListener(_onTabChangeRequested);
    super.dispose();
  }

  void _onTabChangeRequested() {
    final targetTab = widget.tabNotifier.value;
    // Small delay to ensure the widget is fully built
    Future.delayed(const Duration(milliseconds: 50), () {
      _coursesController.switchToTab(targetTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AllCoursesScreen(controller: _coursesController);
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final ValueNotifier<int> _coursesTabNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Navigation: Home, My Topics, Features, Contact Us
    _pages = [
      Dashboard(
        onSeeAllCourses: () => _setIndex(1), 
        onSeeAllPaidCourses: () => _navigateToPaidTab(),
      ), // Home tab (index 0)
      AllCoursesScreenWrapper(tabNotifier: _coursesTabNotifier),  // My Topics tab (index 1)
      const FeaturesScreen(),                                      // Features tab (index 2)
      const ContactUsScreen(),                                     // Contact Us tab (index 3)
    ];
  }

  @override
  void dispose() {
    _coursesTabNotifier.dispose();
    super.dispose();
  }

  void _setIndex(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToPaidTab() {
    _coursesTabNotifier.value = 1; // Set to paid tab (index 1)
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onItemSelected: _setIndex,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbot,
        backgroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'Asset/chatbot.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
  }


}
