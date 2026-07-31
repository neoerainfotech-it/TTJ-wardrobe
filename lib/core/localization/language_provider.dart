import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _appLocale = const Locale('en');
  Map<String, String> _localizedStrings = {};
  bool _isLoading = true;

  Locale get appLocale => _appLocale;
  bool get isLoading => _isLoading;

  LanguageProvider() {
    _initialize();
  }

  // Initial setup: fetches saved preference from local storage
  Future<void> _initialize() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String languageCode = prefs.getString('language_code') ?? 'en';
    _appLocale = Locale(languageCode);
    await loadLanguage();
  }

  // Loads the JSON file based on the current language
  Future<void> loadLanguage() async {
    try {
      _isLoading = true;
      // Note: Do not call notifyListeners() here if you call it at the end 
      // of this function, to avoid double rebuilds.

      String jsonString = await rootBundle.loadString('assets/lang/${_appLocale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      
      _isLoading = false;
      notifyListeners(); // CRITICAL: This triggers the global UI refresh
    } catch (e) {
      debugPrint("Error loading language: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  // The method used by your UI to switch languages
  Future<void> changeLanguage(String languageCode) async {
    // If the language is already selected, do nothing
    if (_appLocale.languageCode == languageCode) return;

    _appLocale = Locale(languageCode);
    
    // Persist choice so it remains after app restart
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    
    // This will reload the new JSON and call notifyListeners()
    await loadLanguage();
  }

  String translate(String key) {
    // Returns the translated string, or the key itself if missing
    return _localizedStrings[key] ?? key;
  }
}