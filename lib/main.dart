import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/favourites_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/profile_screen.dart';

/// Entry point of the Recipe Flutter app.
/// Loads environment variables before starting the app.
Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MainApp());
}

/// The main application widget that provides navigation between different screens.
/// 
/// This widget manages the bottom navigation bar and displays different screens
/// based on the selected tab.
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

/// State class for [MainApp] that manages navigation and shared state.
class _MainAppState extends State<MainApp> {
  /// Current index of the selected bottom navigation tab.
  int _currentIndex = 0;
  
  /// List of ingredients shared across screens.
  final List<String> _ingredients = [];

  /// List of screens corresponding to each navigation tab.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(ingredients: _ingredients),
      const FavouritesScreen(),
      const ExploreScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favourites',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
