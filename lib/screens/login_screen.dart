import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'otp_screen.dart';
import 'login_mpin_screen.dart';
import 'register_screen.dart';
import '../version_check.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool isChecked = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionCheckService.checkVersion(context);
      _checkAndPromptNotificationPermission();
    });
  }

  // --- NOTIFICATION PERMISSION CHECK & CUSTOM POP-UP PROMPT ---
  Future<void> _checkAndPromptNotificationPermission() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();

      // If already authorized, subscribe to global topic directly
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint("✅ User already allowed notifications! Subscribing to 'all_users'...");
        await messaging.subscribeToTopic('all_users');
      } else {
        // Show explanation pop-up to prompt the user
        if (!mounted) return;
        _showNotificationPromptDialog(messaging);
      }
    } catch (e) {
      debugPrint("Notification Permission Error: $e");
    }
  }

  void _showNotificationPromptDialog(FirebaseMessaging messaging) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.notifications_active_rounded, color: Color(0xFF5D189D), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Enable Notifications",
                  style: TextStyle(
                    color: Color(0xFF5D189D),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Stay updated with live Gold Rate changes, Scheme Maturity alerts, and exclusive offers by enabling notifications.",
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Maybe Later",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D189D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog

                // Trigger Native System Permission Prompt
                NotificationSettings newSettings = await messaging.requestPermission(
                  alert: true,
                  badge: true,
                  sound: true,
                );

                if (newSettings.authorizationStatus == AuthorizationStatus.authorized ||
                    newSettings.authorizationStatus == AuthorizationStatus.provisional) {
                  debugPrint("✅ Granted! Subscribing to 'all_users'...");
                  await messaging.subscribeToTopic('all_users');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Notifications enabled successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  debugPrint("🚫 Permission denied by user.");
                }
              },
              child: const Text(
                "Turn On",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- FCM TOPIC SYNC HELPER ---
  Future<void> syncUserFcmTopics(bool isRegisteredInScheme) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Keep everyone on the global channel
      await messaging.subscribeToTopic('all_users');

      if (isRegisteredInScheme) {
        // User HAS scheme -> Subscribe to scheme_users & REMOVE from non_scheme_users
        await messaging.subscribeToTopic('scheme_users');
        await messaging.unsubscribeFromTopic('non_scheme_users');
        debugPrint("FCM SYNC: Subscribed to 'scheme_users' & Unsubscribed from 'non_scheme_users'");
      } else {
        // User DOES NOT have scheme -> Subscribe to non_scheme_users & REMOVE from scheme_users
        await messaging.subscribeToTopic('non_scheme_users');
        await messaging.unsubscribeFromTopic('scheme_users');
        debugPrint("FCM SYNC: Subscribed to 'non_scheme_users' & Unsubscribed from 'scheme_users'");
      }
    } catch (e) {
      debugPrint("FCM Sync Error: $e");
    }
  }

  // --- 1. FETCH & SHOW FULL TERMS FROM DB ---
  Future<void> _fetchAndShowTerms() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D189D)),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_terms.php"),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loader

      final cleanBody = response.body.trim();
      if (cleanBody.startsWith('{')) {
        final data = jsonDecode(cleanBody);
        if (data['status'] == 'success') {
          _showTermsDialog(data['content']);
        } else {
          _showErrorSnackBar(data['message'] ?? "Error loading terms");
        }
      } else {
        _showErrorSnackBar("Server Error: Received invalid response format.");
        debugPrint("Server Raw Response: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar("Connection error: $e");
    }
  }

  void _showTermsDialog(String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(color: Color(0xFF5D189D), fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- HELPER TO SYNC FCM TOKEN TO BACKEND ---
  Future<void> _syncFcmToken(String userId, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/update_token.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "fcm_token": token,
        }),
      ).timeout(const Duration(seconds: 10));
      debugPrint("FCM token successfully synced for user_id: $userId");
    } catch (e) {
      debugPrint("FCM token sync error: $e");
    }
  }

  // --- 2. SMART LOGIN FUNCTION ---
  Future<void> checkLoginStatus() async {
    if (!isChecked) {
      _showErrorSnackBar("Please agree to the Terms & Conditions to proceed");
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter email");
      return;
    }

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    String checkUrl = "https://ttjnextgen.divasprik.in/ttj_api/check_status.php";

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("FCM Token grabbed during login: $fcmToken");
    } catch (e) {
      debugPrint("Failed to get FCM token during login: $e");
    }

    try {
      var response = await http.post(
        Uri.parse(checkUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "fcm_token": fcmToken ?? "" 
        }),
      ).timeout(const Duration(seconds: 15));

      final cleanBody = response.body.trim();

      // ANTI-CRASH JSON GUARD
      if (cleanBody.startsWith('{')) {
        var data = jsonDecode(cleanBody);

        if (data['status'] == 'valid') {
          if (data['user_details'] != null) {
            var user = data['user_details'];
            String userId = user['id'].toString();

            // Flexible type handling for has_active_scheme (bool/int/String)
            bool hasActiveScheme = (user['has_active_scheme'] == true ||
                user['has_active_scheme'] == 1 ||
                user['has_active_scheme'] == '1' ||
                user['has_active_scheme'] == 'true');

            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('user_id', userId);
            await prefs.setString('first_name', user['name'] ?? "");
            await prefs.setString('last_name', user['last_name'] ?? "");
            await prefs.setString('phone', user['mobile'] ?? "");
            await prefs.setString('gender', user['gender'] ?? "");
            await prefs.setString('dob', user['dob'] ?? "");
            await prefs.setBool('has_active_scheme', hasActiveScheme);

            // 🚀 SYNC FCM TOPICS (scheme_users vs non_scheme_users)
            await syncUserFcmTopics(hasActiveScheme);

            // Sync FCM Token explicitly to database
            await _syncFcmToken(userId, fcmToken);
          }

          await prefs.setString('user_email', _emailController.text.trim());

          if (!mounted) return;
          setState(() => isLoading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Welcome Back! Enter MPIN."),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginMpinScreen()),
          );
        } else if (data['status'] == 'expired' || data['status'] == 'new_user') {
          await prefs.setString('user_email', _emailController.text.trim());
          await sendOtpAndProceed();
        } else if (data['status'] == 'deactivated') {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showErrorSnackBar(data['message'] ?? "Your account is deactivated.");
        } else {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showErrorSnackBar("Email not registered. Please Register first.");
        }
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
        debugPrint("Raw Non-JSON Server Response: $cleanBody");
        _showErrorSnackBar("Server temporarily busy. Please try again in a moment.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar("Connection Error: Please check your internet.");
      debugPrint("Login Error: $e");
    }
  }

  // --- 3. SEND OTP FUNCTION ---
  Future<void> sendOtpAndProceed() async {
    String otpUrl = "https://ttjnextgen.divasprik.in/ttj_api/send_otp_check.php";
    try {
      var response = await http.post(
        Uri.parse(otpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim()}),
      ).timeout(const Duration(seconds: 15));

      final cleanBody = response.body.trim();

      // ANTI-CRASH JSON GUARD
      if (cleanBody.startsWith('{')) {
        var data = jsonDecode(cleanBody);
        if (!mounted) return;
        setState(() => isLoading = false);

        if (data['success'] == true || data['status'] == 'success') {
          String serverOtp = data['otp'].toString();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OTP Sent!"),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                correctOtp: serverOtp, 
                email: _emailController.text.trim(),
              ),
            ),
          );
        } else {
          _showErrorSnackBar(data['message'] ?? "Failed to send OTP");
        }
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
        debugPrint("Raw Non-JSON OTP Response: $cleanBody");
        _showErrorSnackBar("Unable to dispatch OTP. Please try again.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar("Network error. Could not send OTP.");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                Center(child: Image.asset('assets/ttj_logo.jpeg', height: 100)),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D189D),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Enter Registered Email",
                  style: TextStyle(
                    color: Color(0xFF7B61FF),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    hintText: "Email Address",
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: const Color(0xFF5D189D),
                      onChanged: (bool? value) => setState(() => isChecked = value!),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: GestureDetector(
                          onTap: _fetchAndShowTerms,
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: "I agree to the Terms & Conditions, specifically acknowledging that all gold purchases are for 9K Purity. ",
                                ),
                                TextSpan(
                                  text: "Terms & Conditions",
                                  style: TextStyle(
                                    color: Color(0xFF5D189D),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : checkLoginStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D189D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    ),
                    child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(
                        color: Color(0xFF5D189D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}