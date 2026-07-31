// lib/core/app_settings.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppSettings {
  // 1. Create a Singleton so the whole app shares this brain
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // 2. Your Feature Flags (Default to false for safety)
  bool showGoldWallet = false;
  bool showRedemption = false;

  // 3. Fetch from API and save locally
  Future<void> initializeSettings() async {
    try {
      // CACHE BUSTER: We add a unique millisecond timestamp to the end of the URL.
      // This tricks Chrome into thinking it's a brand new file every single time,
      // so it never loads the old hidden version from cache!
      final String uniqueUrl = 'https://ttjnextgen.divasprik.in/ttj_api/get_app_settings.php?v=${DateTime.now().millisecondsSinceEpoch}';
      
      // Fetching without strict headers prevents the red CORS block error
      final response = await http.get(Uri.parse(uniqueUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          showGoldWallet = json['data']['show_gold_wallet'];
          showRedemption = json['data']['show_redemption'];

          // Save securely to phone memory
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('show_gold_wallet', showGoldWallet);
          await prefs.setBool('show_redemption', showRedemption);
          return;
        }
      }
    } catch (e) {
      debugPrint("API failed, loading from local storage: $e");
    }
    
    // 4. Fallback: If they have no internet, load the last known settings from the phone
    final prefs = await SharedPreferences.getInstance();
    showGoldWallet = prefs.getBool('show_gold_wallet') ?? false;
    showRedemption = prefs.getBool('show_redemption') ?? false;
  }
}

// Global variable so any file can access it easily!
final appSettings = AppSettings();