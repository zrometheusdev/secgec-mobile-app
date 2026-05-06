import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:secgec/screens/feed_screen.dart';
import 'package:secgec/screens/discover_screen.dart';
import 'package:secgec/screens/create_poll_screen.dart';
import 'package:secgec/screens/profile_screen.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const FeedScreen(),
    const DiscoverScreen(),
    const CreatePollScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(), // Premium bouncing effect
        children: _screens,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, CupertinoIcons.house_fill, CupertinoIcons.house_fill, isDark),
                _buildNavItem(2, CupertinoIcons.plus_app, CupertinoIcons.plus_app_fill, isDark),
                _buildNavItem(1, CupertinoIcons.search, CupertinoIcons.search, isDark),
                _buildNavItem(3, CupertinoIcons.person_crop_circle_fill, CupertinoIcons.person_crop_circle_fill, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white54 : Colors.black45);

    // Using BadgedIcon for notifications/messages wouldn't typically go on generic nav items unless specified.
    // If the user meant "bildirim logosu" inside messages or notifications, that's up in the FeedScreen app bar.

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              width: isSelected ? 16 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: color,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

