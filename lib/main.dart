import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/favourites_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/ingredients_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/favourites_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/logout_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dart:developer' as dev;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnon = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl == null || supabaseAnon == null) {
    dev.log('Supabase env vars missing (SUPABASE_URL / SUPABASE_ANON_KEY). Auth will fail.', name: 'bootstrap');
  } else {
    await sb.Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnon,
    );
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavouritesProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => IngredientsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _lastUserId; // track last authenticated user
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const FavouritesScreen(),
      const ExploreScreen(),
      const ProfileScreen(),
    ];

    // Load favourites after first frame so platform plugins are registered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FavouritesProvider>(context, listen: false).load();
      Provider.of<ProfileProvider>(context, listen: false).load();
      Provider.of<SettingsProvider>(context, listen: false).load();
      Provider.of<IngredientsProvider>(context, listen: false).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = context.watch<SettingsProvider>().darkMode;
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();

    // Switch profile when user changes
    final currentUserId = auth.user?.id;
    if (_lastUserId != currentUserId) {
      _lastUserId = currentUserId;
      if (profile.userId != currentUserId) {
        profile.switchUser(currentUserId);
      }
    }

    // If NOT logged in, show login screen as the entire app (auth gate)
    if (!auth.isLoggedIn) {
      return MaterialApp(
        navigatorKey: _navKey,
        theme: buildAppTheme(dark: false),
        darkTheme: buildAppTheme(dark: true),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        routes: {
          '/login': (_) => const LoginScreen(),
          '/profile_setup': (_) => const ProfileSetupScreen(),
        },
        home: const LoginScreen(),
      );
    }

    // While switching/loading show placeholder
    if (profile.userId != currentUserId || !profile.isLoaded) {
      return MaterialApp(
        navigatorKey: _navKey,
        theme: buildAppTheme(dark: false),
        darkTheme: buildAppTheme(dark: true),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // If profile not completed yet, show setup directly as home (no push)
    if (!profile.isCompleted) {
      return MaterialApp(
        navigatorKey: _navKey,
        theme: buildAppTheme(dark: false),
        darkTheme: buildAppTheme(dark: true),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const ProfileSetupScreen(),
        routes: {
          '/settings': (_) => const SettingsScreen(),
          '/logout': (_) => const LogoutScreen(),
        },
      );
    }

    return MaterialApp(
      navigatorKey: _navKey,
      theme: buildAppTheme(dark: false),
      darkTheme: buildAppTheme(dark: true),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/login': (_) => const LoginScreen(),
        '/logout': (_) => const LogoutScreen(),
      },
      home: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) { setState(() { _currentIndex = index; }); },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favourites'),
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
