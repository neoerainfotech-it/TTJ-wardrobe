import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  // Replace with your actual PHP API URL
  static const String _versionApiUrl = "https://ttjnextgen.divasprik.in/ttj_api/get_app_version.php";

  /// Main function to initiate the version check
  static Future<void> checkVersion(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_versionApiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Get the current version of the app installed on the device
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        
        String currentVersion = packageInfo.version; 
        String latestVersion = data['latest_version'];
        bool isForceUpdate = data['force_update'] ?? false;

        // Compare the versions correctly using math
        if (_isUpdateRequired(currentVersion, latestVersion) && isForceUpdate) {
          if (context.mounted) {
            _showUpdateDialog(context, data['update_url']);
          }
        }
      }
    } catch (e) {
      debugPrint("Version check failed: $e");
    }
  }

  /// Proper Version Math Comparator (Checks 1.0.16 vs 1.0.19 correctly)
  static bool _isUpdateRequired(String current, String required) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> requiredParts = required.split('.').map(int.parse).toList();

      for (int i = 0; i < requiredParts.length; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int r = requiredParts[i];
        if (c < r) return true; // App is older, NEEDS UPDATE
        if (c > r) return false; // App is newer, no update needed
      }
      return false; // Versions are exactly the same
    } catch (e) {
      // Fallback in case strings are formatted weirdly
      return current != required; 
    }
  }

  /// Displays a non-dismissible dialog to force the user to update
  static void _showUpdateDialog(BuildContext context, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (context) {
        return PopScope(
          canPop: false, // Disables the physical back button on Android
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Row(
              children: [
                Icon(Icons.system_update, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Text("Update Required", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "A critical update is available. This update fixes payment issues and improves performance. Please update to continue using TTJ Wardrobe.",
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse(updateUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text("UPDATE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}