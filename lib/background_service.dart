import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// -----------------------------------------------------------------------------
//  ENTRY POINT
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Read user_id as String (matches login_screen.dart)
      final String? userId = prefs.getString('user_id');

      // -----------------------------------------------------------------------
      //  TASK 1: CHECK MATURITY STATUS (User Specific)
      // -----------------------------------------------------------------------
      if (userId != null && userId.isNotEmpty) {
        final maturityResponse = await http.get(
          Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/check_maturity_status.php?user_id=$userId")
        ).timeout(const Duration(seconds: 15));
        
        if (maturityResponse.statusCode == 200) {
          final cleanBody = maturityResponse.body.trim();
          if (cleanBody.startsWith('{')) {
            final data = jsonDecode(cleanBody);
            if (data['has_alert'] == true) {
              await _showNotification(
                100, // Unique ID for Maturity
                data['title'] ?? 'Maturity Alert', 
                data['body'] ?? 'Your scheme has matured.'
              );
            }
          }
        }
      }

      // -----------------------------------------------------------------------
      //  TASK 2: CHECK GOLD RATE CHANGES (Global)
      // -----------------------------------------------------------------------
      final rateResponse = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/check_gold_rate.php")
      ).timeout(const Duration(seconds: 15));

      if (rateResponse.statusCode == 200) {
        final cleanBody = rateResponse.body.trim();
        if (cleanBody.startsWith('{')) {
          final rateData = jsonDecode(cleanBody);

          if (rateData['status'] == 'success' && rateData['current_rate'] != null) {
            double currentRate = (rateData['current_rate'] as num).toDouble();
            String metalName = rateData['metal_name'] ?? "Gold"; 

            double? lastRate = prefs.getDouble('last_gold_rate');

            if (lastRate != null && currentRate != lastRate) {
              String trend = currentRate > lastRate ? "increased 📈" : "dropped 📉";
              String bodyText = "$metalName rate has $trend to ₹$currentRate. Check it now!";
              
              await _showNotification(
                200, // Unique ID for Gold Rate
                "$metalName Rate Update", 
                bodyText
              );
            }

            await prefs.setDouble('last_gold_rate', currentRate);
          }
        }
      }

    } catch (e) {
      debugPrint("Background Task Error: $e");
    }
    
    return true;
  });
}

// -----------------------------------------------------------------------------
//  HELPER: SHOW NOTIFICATION
// -----------------------------------------------------------------------------
Future<void> _showNotification(int id, String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit, 
    iOS: iosInit,
  );

  // FIXED: Named parameter 'settings:'
  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

  // Guarantee channel creation for background execution
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', 
    'High Importance Notifications',
    description: 'Maturity and Rate Alerts',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',       
    'High Importance Notifications', 
    channelDescription: 'Maturity and Rate Alerts',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon', 
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  // FIXED: Named parameters for show()
  await flutterLocalNotificationsPlugin.show(
    id: id, 
    title: title, 
    body: body, 
    notificationDetails: notificationDetails,
  );
}