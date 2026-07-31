// ignore_for_file: unused_import
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- FIREBASE IMPORTS ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Internal Files - Uses callbackDispatcher from background_service.dart
import 'background_service.dart'; 
import 'core/app_settings.dart'; 
import 'core/localization/language_provider.dart';

// ---> SCREEN IMPORTS <---
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/joinscheme.dart';
import 'screens/welcome.dart';
import 'screens/gold_wallet.dart';
import 'screens/transactions.dart';
import 'screens/profile.dart';
import 'screens/redemption.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- ANDROID CHANNEL CONFIGURATION ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// --- FCM TOPIC SUBSCRIPTION HELPER ---
/// Dynamically updates FCM topic subscriptions based on scheme enrollment status
Future<void> updateUserSchemeTopics(bool hasActiveScheme) async {
  if (kIsWeb) return;
  try {
    final messaging = FirebaseMessaging.instance;

    // 1. Always subscribe to global topic
    await messaging.subscribeToTopic('all_users');
    debugPrint("FCM: Subscribed to 'all_users'");

    // 2. Segment specific subscriptions
    if (hasActiveScheme) {
      await messaging.subscribeToTopic('scheme_users');
      await messaging.unsubscribeFromTopic('non_scheme_users');
      debugPrint("FCM: Subscribed to 'scheme_users', unsubscribed from 'non_scheme_users'");
    } else {
      await messaging.subscribeToTopic('non_scheme_users');
      await messaging.unsubscribeFromTopic('scheme_users');
      debugPrint("FCM: Subscribed to 'non_scheme_users', unsubscribed from 'scheme_users'");
    }
  } catch (e) {
    debugPrint("FCM Topic Update Error: $e");
  }
}

// --- TOP LEVEL FCM BACKGROUND HANDLER ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background FCM message: ${message.messageId}");
}

// --- GLOBAL LOGOUT HELPER ---
Future<void> _performSecureLogout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user_id');
  await prefs.setBool('isLoggedIn', false);
  await prefs.remove('last_active_time');
  debugPrint("SECURITY: Session Cleared");
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    bool isFirebaseReady = false;

    // 1. Firebase Init safely
    try {
      await Firebase.initializeApp();
      isFirebaseReady = true;
    } catch (e) {
      debugPrint("Firebase Init Error: $e");
    }

    // 2. Mobile Logic (Notifications & Workmanager)
    if (!kIsWeb && isFirebaseReady) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Create notification channel in Android OS
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      // Points to callbackDispatcher defined inside background_service.dart
      await Workmanager().initialize(callbackDispatcher);
      
      Workmanager().registerPeriodicTask(
        "105",
        "checkAllAlerts",
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    }

    // 3. SharedPreferences & Cold Boot Security Check
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('last_active_time');
    debugPrint("SECURITY: Cold boot detected. Session Cleared for Instant Lock.");

    // Initialize feature flags
    await appSettings.initializeSettings();

    // 4. Start the App
    runApp(
      ChangeNotifierProvider(
        create: (context) => LanguageProvider(),
        child: const TTJApp(isLoggedIn: false), 
      ),
    );
    
  } catch (e, stackTrace) {
    debugPrint("CRITICAL BOOT ERROR: $e");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("App Error:\n$e\n\n$stackTrace", style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  APP WIDGET
// -----------------------------------------------------------------------------
class TTJApp extends StatefulWidget {
  final bool isLoggedIn;
  const TTJApp({super.key, required this.isLoggedIn});

  @override
  State<TTJApp> createState() => _TTJAppState();
}

class _TTJAppState extends State<TTJApp> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _setupPushNotifications();
    }
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 5-minute idle timeout while app is actively open
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () async {
      debugPrint("SECURITY: 5-minute active idle reached. Forcing Login.");
      await _performSecureLogout();
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  // --- FCM NOTIFICATION SETUP & DYNAMIC TOPIC SUBSCRIPTION ---
  Future<void> _setupPushNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Native Permission Request
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint("FCM: Permission Granted by OS");
      } else {
        debugPrint("FCM: Permission Status -> ${settings.authorizationStatus}");
      }

      // Check saved user scheme status from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      bool hasActiveScheme = prefs.getBool('has_active_scheme') ?? false;

      // Automatically sync topics with current enrollment state
      await updateUserSchemeTopics(hasActiveScheme);

      // FOREGROUND MESSAGES
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Foreground Notification: ${message.notification?.title}");
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          flutterLocalNotificationsPlugin.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      });

      // BACKGROUND CLICK HANDLER
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("Notification Tapped from Background!");
        _handleNotificationClick(message);
      });

      // TERMINATED LAUNCH HANDLER
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("App Launched from Terminated Notification!");
        _handleNotificationClick(initialMessage);
      }

    } catch (e) {
      debugPrint("Notification Setup Error: $e");
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    String type = message.data['type'] ?? 'Promotional';
    debugPrint("Processing Notification click of type: $type");

    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamed('/dashboard');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _saveLastActiveTime();
    }
    
    if (state == AppLifecycleState.resumed) {
      _checkBackgroundTimeout();
    }
  }

  Future<void> _saveLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);
    debugPrint("App sleeping: Time saved.");
  }

  Future<void> _checkBackgroundTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    int? lastActive = prefs.getInt('last_active_time');
    
    if (lastActive != null) {
      final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
      
      if (DateTime.now().difference(lastActiveTime).inMinutes >= 5) {
        debugPrint("SECURITY: App slept for > 5 mins. Forcing Login.");
        await _performSecureLogout();
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        debugPrint("App woke up in under 5 mins. Welcome back.");
        _startInactivityTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Listener(
      onPointerDown: (_) => _startInactivityTimer(),
      child: MaterialApp(
        navigatorKey: navigatorKey, 
        debugShowCheckedModeBanner: false,
        title: 'TTJ Nextgen Jewels',
        locale: languageProvider.appLocale,
        theme: ThemeData(
          primaryColor: const Color(0xFF5D1F88),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5D1F88)),
        ),
        initialRoute: widget.isLoggedIn ? '/dashboard' : '/',
        routes: {
          '/': (context) => const AuthWelcomeScreen(),
          '/dashboard': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/gold_scheme': (context) => const GoldSchemeScreen(schemeData: {}),
          '/gold_wallet': (context) => const GoldWalletScreen(),
          '/transactions': (context) => const TransactionsScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  AUTH WELCOME SCREEN
// -----------------------------------------------------------------------------
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D189D),
                    fontFamily: 'Serif',
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TTJ Wardrobe',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
              const Spacer(),
              Image.asset(
                'assets/ttj_logo.jpeg',
                width: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.stars, size: 100, color: Color(0xFF5D189D));
                },
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: const Text(
                      "Log in",
                      style: TextStyle(
                        color: Color(0xFF5D189D),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D189D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text(
                    'Register',
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}