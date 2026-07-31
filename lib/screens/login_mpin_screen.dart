import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome.dart'; // Dashboard
import 'login_screen.dart';
import 'forgot_password_screen.dart';

class LoginMpinScreen extends StatefulWidget {
  const LoginMpinScreen({super.key});

  @override
  State<LoginMpinScreen> createState() => _LoginMpinScreenState();
}

class _LoginMpinScreenState extends State<LoginMpinScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  bool _isMpinVisible = false;

  // REUSABLE: Save full user session (same as in LoginScreen)
  Future<void> _saveUserSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);

    try {
      var response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_user_by_email.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      var data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        await prefs.setInt('user_id', data['user_id']);
        await prefs.setString('user_name', data['name'] ?? "Customer");
        await prefs.setString('user_mobile', data['mobile'] ?? "Not available");
        await prefs.setString('user_email', data['email']);
      }
    } catch (e) {
      print("Error saving user session: $e");
      // Silent fallback - at least email is saved
    }
  }

  Future<void> verifyMpin(String mpin) async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');

    if (email == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    String apiUrl = "https://ttjnextgen.divasprik.in/ttj_api/verify_mpin.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "mpin": mpin}),
      );

      var data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        // CRITICAL FIX: Save full session before going to dashboard
        await _saveUserSession(email);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Successful!"), backgroundColor: Colors.green),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      } else if (data['status'] == 'expired') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("MPIN Expired! Please Login again."), backgroundColor: Colors.orange),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid MPIN"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Error")),
      );
    }
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
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Image.asset('assets/ttj_logo.jpeg', height: 80),
                const SizedBox(height: 30),
                const Text('Login MPIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D189D))),
                const SizedBox(height: 50),
                const Align(alignment: Alignment.centerLeft, child: Text("Enter MPIN*", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ...List.generate(4, (index) => _buildMpinBox(context, index)),
                    IconButton(
                      icon: Icon(
                        _isMpinVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF5D189D),
                      ),
                      onPressed: () => setState(() => _isMpinVisible = !_isMpinVisible),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                    child: const Text("Forgot MPIN?", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 60),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      String mpin = _controllers.map((e) => e.text).join();
                      if (mpin.length == 4) {
                        verifyMpin(mpin);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter 4 digits")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D189D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Login MPIN', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMpinBox(BuildContext context, int index) {
    return Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF5F6FA),
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          obscureText: !_isMpinVisible,
          onChanged: (value) {
            if (value.length == 1 && index < 3) FocusScope.of(context).nextFocus();
            if (value.isEmpty && index > 0) FocusScope.of(context).previousFocus();
          },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          keyboardType: TextInputType.number,
          maxLength: 1,
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
    );
  }
}