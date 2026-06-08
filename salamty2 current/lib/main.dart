import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Imported for Gmail/Google logout management
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/health_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';

// Global key used by sub-screens (like SettingsScreen) to trigger a clean app reset
final GlobalKey<_RootControllerState> rootControllerKey =
    GlobalKey<_RootControllerState>();

void main() async {
  // Ensure Flutter engine bindings are ready before executing async native initializations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Google Sign-In instance exactly once globally
  try {
    await GoogleSignIn.instance.initialize(
        // Optional: Add scopes or clientIds here if needed by your backend setup
        // scopes: ['email', 'profile'],
        );
  } catch (e) {
    debugPrint('Google Sign-In initialization failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SalamtyApp());
}

class SalamtyApp extends StatelessWidget {
  const SalamtyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salamty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Attached the global key to access the state from inner navigation contexts
      home: RootController(key: rootControllerKey),
    );
  }
}

// ─── Root controller: splash → check token → auth or main ────────────────────
class RootController extends StatefulWidget {
  const RootController({super.key});

  @override
  State<RootController> createState() => _RootControllerState();
}

class _RootControllerState extends State<RootController> {
  String _screen = 'splash'; // 'splash' | 'auth' | 'main'

  // Public method called by inner screens to clear the session and force navigation
  void logOutAndRedirect() {
    setState(() {
      _screen = 'auth';
    });
  }

  // Called when the splash animation finishes.
  // Checks for a saved access token — goes straight to main if found.
  Future<void> _onSplashDone() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() => _screen = loggedIn ? 'main' : 'auth');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (_screen) {
        'splash' => SplashScreen(
            key: const ValueKey('splash'),
            onDone: _onSplashDone,
          ),
        'auth' => AuthScreen(
            key: const ValueKey('auth'),
            onLogin: () => setState(() => _screen = 'main'),
          ),
        _ => const MainShell(key: ValueKey('main')),
      },
    );
  }
}

// ─── Main shell with bottom nav ───────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    _NavTab(icon: Icons.grid_view_rounded, label: 'Home'),
    _NavTab(icon: Icons.people_outline, label: 'Contacts'),
    _NavTab(icon: Icons.local_hospital_outlined, label: 'Health'),
    _NavTab(icon: Icons.person_outline, label: 'Vehicles'),
    _NavTab(icon: Icons.notifications_outlined, label: 'Alerts'),
    _NavTab(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  Widget _buildScreen() => switch (_index) {
        0 => const HomeScreen(),
        1 => const ContactsScreen(),
        2 => const HealthScreen(),
        3 => const ProfileScreen(),
        4 => const AlertsScreen(),
        5 => const SettingsScreen(),
        _ => const HomeScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _buildScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomNav(
          index: _index,
          tabs: _tabs,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab({required this.icon, required this.label});
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int index;
  final List<_NavTab> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav(
      {required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(
              tabs.length,
              (i) => Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].icon,
                        size: 22,
                        color: i == index
                            ? AppColors.blueLight
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: i == index
                              ? AppColors.blueLight
                              : AppColors.textMuted,
                          fontFamily: 'Outfit',
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
