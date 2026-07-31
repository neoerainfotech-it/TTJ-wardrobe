import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mpin_screen.dart';

class RegisterOtpScreen extends StatefulWidget {
  final String correctOtp, userName, userPhone, userEmail, userGender, userDob;

  const RegisterOtpScreen({
    super.key,
    required this.correctOtp,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    required this.userGender,
    required this.userDob,
  });

  @override
  State<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<RegisterOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  bool _isLoading = false;

  Future<void> _verifyAndFinalize() async {
    String enteredOtp = _controllers.map((e) => e.text).join();

    if (enteredOtp != widget.correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wrong OTP! Please try again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // REGISTER THE USER IN DB ONLY AFTER OTP IS VERIFIED
      var response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/register.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": widget.userName,
          "phone": widget.userPhone,
          "email": widget.userEmail,
          "gender": widget.userGender,
          "dob": widget.userDob,
        }),
      );

      var data = jsonDecode(response.body);

      if (data['status'] == 'success' || data['success'] == true) {
        // Save user details to local storage
        final prefs = await SharedPreferences.getInstance();

        if (data['user_id'] != null) {
          await prefs.setInt(
            'user_id',
            int.tryParse(data['user_id'].toString()) ?? 1,
          );
        }
        await prefs.setString('user_name', widget.userName);
        await prefs.setString('user_email', widget.userEmail);
        await prefs.setString('user_mobile', widget.userPhone);
        await prefs.setString('gender', widget.userGender);
        await prefs.setString('dob', widget.userDob);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account Created Successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to MPIN creation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MpinScreen()),
        );
      } else {
        throw data['message'] ?? "Registration failed";
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 20.0,
            ),
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
                const Text(
                  'Enter OTP',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D189D),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter the OTP code sent to your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => _buildOtpBox(index)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyAndFinalize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D189D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
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

  Widget _buildOtpBox(int index) {
    return Container(
      height: 55,
      width: 60,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF5D189D), width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: TextField(
        controller: _controllers[index],
        autofocus: index == 0,
        onChanged: (value) {
          if (value.length == 1 && index < 3) {
            FocusScope.of(context).nextFocus();
          }
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}