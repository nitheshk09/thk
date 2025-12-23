import 'package:flutter/material.dart';
import '../widgets/translated_text.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: currentIndex,
          onTap: onItemSelected,
          selectedItemColor: const Color(0xFF2E7DFF),
          unselectedItemColor: const Color(0xFF6B7280).withValues(alpha: 0.6),
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Topics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_outline_rounded),
              label: 'Features',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined),
              label: 'Contact',
            ),
          ],
        ),
      ),
    );
  }
}


