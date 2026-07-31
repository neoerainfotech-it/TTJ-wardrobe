import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Configuration Import
import '../core/app_settings.dart';// <-- MAKE SURE THIS MATCHES YOUR EXACT APP PACKAGING PATH

// Navigation Imports
import 'welcome.dart';
import 'transactions.dart';
import 'profile.dart';
import 'redemption.dart';
import 'gold_wallet.dart';

class MPINScreen extends StatefulWidget {
  const MPINScreen({super.key});

  @override
  State<MPINScreen> createState() => _MPINScreenState();
}

class _MPINScreenState extends State<MPINScreen> {
  final Color brandPurple = const Color(0xFF5D1F88);
  bool _isLoading = false;

  // 1. Current MPIN
  final List<FocusNode> _currentFocusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _currentControllers = List.generate(4, (_) => TextEditingController());
  bool _isCurrentVisible = false;

  // 2. New MPIN
  final List<FocusNode> _newFocusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _newControllers = List.generate(4, (_) => TextEditingController());
  bool _isNewVisible = false;

  // 3. Confirm New MPIN
  final List<FocusNode> _confirmFocusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _confirmControllers = List.generate(4, (_) => TextEditingController());
  bool _isConfirmVisible = false;

  @override
  void dispose() {
    for (var node in [..._currentFocusNodes, ..._newFocusNodes, ..._confirmFocusNodes]) {
      node.dispose();
    }
    for (var controller in [..._currentControllers, ..._newControllers, ..._confirmControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- FIXED BACKEND INTEGRATION LOGIC ---
  Future<void> _changeMPIN() async {
    String currentPin = _currentControllers.map((e) => e.text).join();
    String newPin = _newControllers.map((e) => e.text).join();
    String confirmPin = _confirmControllers.map((e) => e.text).join();

    if (currentPin.length < 4 || newPin.length < 4 || confirmPin.length < 4) {
      _showSnackBar("Please fill in all 4 digits for each field", Colors.orange);
      return;
    }

    if (newPin != confirmPin) {
      _showSnackBar("New MPIN and Confirm New MPIN do not match", Colors.red);
      return;
    }

    if (currentPin == newPin) {
      _showSnackBar("New MPIN cannot be the same as Current MPIN", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final Object? rawUserId = prefs.get('user_id');
      String userId = rawUserId?.toString() ?? '';

      if (userId.isEmpty) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/change_mpin.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "current_mpin": currentPin,
          "new_mpin": newPin,
        }),
      ).timeout(const Duration(seconds: 15));

      final String cleanBody = response.body.trim();

      if (cleanBody.startsWith('<')) {
        debugPrint("PHP Server Error: $cleanBody");
        _showSnackBar("Server issue. Check the debug console.", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      final result = jsonDecode(cleanBody);

      if (result['status'] == 'success') {
        _showSnackBar("MPIN successfully changed", Colors.green);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()));
          }
        });
      } else {
        _showSnackBar(result['message'] ?? "Failed to change MPIN", Colors.red); 
      }
    } catch (e) {
      debugPrint("The exact error is: $e"); 
      _showSnackBar("Connection Error. Please check your internet.", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildPinInputRow(List<TextEditingController> controllers, List<FocusNode> focusNodes, bool isVisible) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        return Container(
          width: 55, height: 65,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Center(
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              obscureText: !isVisible,
              obscuringCharacter: '●',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none, counterText: ""),
              maxLength: 1,
              onChanged: (value) {
                if (value.isNotEmpty && index < 3) {
                  focusNodes[index + 1].requestFocus();
                } else if (value.isEmpty && index > 0) {
                  focusNodes[index - 1].requestFocus();
                }
                setState(() {});
              },
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Image.asset('assets/ttj_logo.jpeg', height: 75)),
            const SizedBox(height: 25),
            Text("Change MPIN", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: brandPurple)),
            const Text("Update your MPIN for security", style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 35),

            _buildLabel("Current MPIN*", _isCurrentVisible, (val) => setState(() => _isCurrentVisible = val)),
            _buildPinInputRow(_currentControllers, _currentFocusNodes, _isCurrentVisible),
            const SizedBox(height: 20),

            _buildLabel("New MPIN*", _isNewVisible, (val) => setState(() => _isNewVisible = val)),
            _buildPinInputRow(_newControllers, _newFocusNodes, _isNewVisible),
            const SizedBox(height: 20),

            _buildLabel("Confirm New MPIN*", _isConfirmVisible, (val) => setState(() => _isConfirmVisible = val)),
            _buildPinInputRow(_confirmControllers, _confirmFocusNodes, _isConfirmVisible),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 58,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changeMPIN,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("UPDATE MPIN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildLabel(String text, bool isVisible, Function(bool) onToggle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 22),
          onPressed: () => onToggle(!isVisible),
        )
      ],
    );
  }

  // --- REFACTORED DYNAMIC NAVIGATION BAR ---
  Widget _buildBottomNav() {
    return Container(
      height: 56, 
      color: brandPurple,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navIcon(Icons.home_outlined, const WelcomeScreen()),
            _navIcon(Icons.compare_arrows, const TransactionsScreen()),
            
            // Checks global CMS dynamic visibility setting for Gold Wallet
            if (appSettings.showGoldWallet)
              _navIcon(Icons.account_balance_wallet_outlined, const GoldWalletScreen()),
              
            // Checks global CMS dynamic visibility setting for Redemption Screen
            if (appSettings.showRedemption)
              _navIcon(Icons.card_giftcard, const RedemptionPage()),
              
            _navIcon(Icons.person_outline, const ProfileScreen()),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, Widget target) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 28),
      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => target)),
    );
  }
}