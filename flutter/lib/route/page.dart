import 'package:get/get.dart';

// Shell (bottom nav with center +)
import '../bottomnav/bottomnav.dart';

// Core screens
import '../screens/login.dart';
import '../screens/register.dart';
import '../screens/focus_timer_screen.dart';
import '../screens/pet_chat_screen.dart';

// Optional: direct tab pages (if you want to deep-link to tabs)
import '../screens/dashboard.dart';
import '../screens/splashscreen.dart';
import '../screens/task_today.dart';
import '../screens/all_task.dart';
import '../screens/setting.dart';

// Splash (token check)

class AppPages {
  // For now you want initial = login
  static const String initial = '/login';
  // Later, change to '/splash' when you’re ready
  // static const String initial = '/splash';

  static final List<GetPage> routes = <GetPage>[
    // Splash — checks token, then redirects to /home or /login
    GetPage(
      name: '/splash',
      page: () => const SplashScreen(),
    ),

    // Auth
    GetPage(
      name: '/login',
      page: () =>  LoginPage(),
    ),
    GetPage(
      name: '/register',
      page: () =>  RegisterPage(),
    ),

    // HOME = Bottom Nav Shell (Dashboard/Today/+ /All/Settings)
    // Bind “home” to the bottom nav so navigating to /home shows your 5 tabs.
    GetPage(
      name: '/home',
      page: () =>  NavShell(),
    ),

    // Focus timer (taskId passed via arguments)
    GetPage(
      name: '/focus',
      page: () =>  FocusTimerScreen(),
    ),

    // Optional: direct routes to tabs (useful for deep-links)
    GetPage(
      name: '/dashboard', 
      page: () =>  Dashboard()
      ),
    GetPage(
      name: '/today', 
      page: () =>  TaskToday()
      ),
    GetPage(
      name: '/all', 
      page: () =>  AllTasks()
      ),
    GetPage(name: '/settings', 
    page: () =>  Settings()
    ),

    // Pet chat (kept as a separate page)
    GetPage(name: '/pet', 
    page: () => const PetChatScreen()
    ),
  ];
}
