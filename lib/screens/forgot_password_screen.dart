import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import HTTP
import 'dart:convert'; // Import JSON
import 'otp_screen.dart'; 

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controller to get the email
  final TextEditingController _emailController = TextEditingController();
  bool isLoading = false;

  // --- FUNCTION TO SEND OTP ---
  Future<void> sendResetOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your registered email")),
      );
      return;
    }

    setState(() => isLoading = true);

    // Use your REAL server URL
    String apiUrl = "https://ttjnextgen.divasprik.in/ttj_api/send_otp_check.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      var data = jsonDecode(response.body);

      if (data['success'] == true) {
        // 1. Get the OTP from the server
        String serverOtp = data['otp'].toString(); 

        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("OTP sent to your email!"), backgroundColor: Colors.green),
        );

        // 2. Navigate to OTP Screen and PASS the OTP
        Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => OtpScreen(
      correctOtp: serverOtp, 
      email: _emailController.text.trim(), // <-- Add this line (use whatever your controller is named)
    ),
  ),
);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed to send OTP"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Error! Check Internet."), backgroundColor: Colors.red),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Back Arrow
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // 2. Logo
                Image.asset('assets/ttj_logo.jpeg', height: 80),

                const SizedBox(height: 30),

                // 3. Title
                const Text(
                  'Forgot Password',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D189D),
                  ),
                ),

                const SizedBox(height: 15),

                // 4. Subtitle
                const Text(
                  'Please enter your email address to receive a verification code to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // 5. Email Input (Changed from Phone to match your PHP)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Enter Email Address",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),

                const SizedBox(height: 40),

                // 6. Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () {
                      sendResetOtp(); // Call the API
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D189D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: isLoading 
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
}