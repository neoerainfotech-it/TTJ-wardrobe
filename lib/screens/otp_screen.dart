import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mpin_screen.dart'; // Next Screen

class OtpScreen extends StatefulWidget {
  final String correctOtp; 
  final String email;

  const OtpScreen({
    super.key, 
    required this.correctOtp, 
    required this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  
  late String _currentOtp;
  Timer? _timer;
  int _start = 30;
  bool _canResend = false;
  bool _isLoading = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.correctOtp;
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void startTimer() {
    setState(() {
      _start = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_start == 0) {
        if (mounted) {
          setState(() {
            timer.cancel();
            _canResend = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
        }
      }
    });
  }

  // --- CONTINUE / VERIFY OTP ACTION ---
  Future<void> _verifyOtp() async {
    String enteredOtp = _controllers.map((e) => e.text).join();

    if (enteredOtp.length < 4) {
      _showSnackBar("Please enter the complete 4-digit OTP", Colors.orange);
      return;
    }

    // Direct Local Match Optimization (Instant response)
    if (enteredOtp == _currentOtp) {
      _showSnackBar("Verified Successfully!", Colors.green);
      _navigateToMpinScreen();
      return;
    }

    // Server-side Backup Verification
    setState(() => _isVerifying = true);

    try {
      const String verifyUrl = "https://ttjnextgen.divasprik.in/ttj_api/verify_otp.php";
      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "otp": enteredOtp}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final cleanBody = response.body.trim();

      // Guarded JSON Parsing (Prevents Red Crash Screen)
      if (cleanBody.startsWith('{')) {
        final data = jsonDecode(cleanBody);
        if (data['success'] == true || data['status'] == 'success') {
          _showSnackBar("Verified Successfully!", Colors.green);
          _navigateToMpinScreen();
        } else {
          _showSnackBar(data['message'] ?? "Wrong OTP! Please try again.", Colors.red);
        }
      } else {
        _showSnackBar("Wrong OTP! Please try again.", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Connection issue. Checking local verification...", Colors.orange);
        if (enteredOtp == _currentOtp) {
          _navigateToMpinScreen();
        } else {
          _showSnackBar("Invalid OTP code entered", Colors.red);
        }
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // --- RESEND OTP ACTION ---
  Future<void> resendOtp() async {
    setState(() => _isLoading = true);

    try {
      const String otpUrl = "https://ttjnextgen.divasprik.in/ttj_api/send_otp_check.php";
      
      final response = await http.post(
        Uri.parse(otpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final cleanBody = response.body.trim();
      
      if (cleanBody.startsWith('{')) {
        final data = jsonDecode(cleanBody);
        
        if (data['success'] == true || data['status'] == 'success') {
          setState(() {
            if (data['otp'] != null) {
              _currentOtp = data['otp'].toString();
            }
            for (var controller in _controllers) {
              controller.clear();
            }
          });

          _showSnackBar("New OTP sent successfully to your email!", Colors.orange);
          startTimer();
        } else {
          _showSnackBar(data['message'] ?? "Failed to resend OTP", Colors.red);
        }
      } else {
        _showSnackBar("Server busy. Please try again shortly.", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Network error: $e", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToMpinScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MpinScreen()),
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5D189D)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter the OTP code sent to\n${widget.email}', 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) => _buildOtpBox(context, index)),
                ),

                const SizedBox(height: 40),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D189D), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue', 
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),

                const SizedBox(height: 30),

                // Resend OTP Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive the OTP? ",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    _isLoading 
                      ? const SizedBox(
                          width: 15, 
                          height: 15, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5D189D)),
                        )
                      : GestureDetector(
                          onTap: _canResend ? resendOtp : null,
                          child: Text(
                            _canResend ? "Resend OTP" : "Resend in 00:${_start.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              color: _canResend ? const Color(0xFF5D189D) : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(BuildContext context, int index) {
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
          if (value.length == 1 && index < 3) FocusScope.of(context).nextFocus();
          if (value.isEmpty && index > 0) FocusScope.of(context).previousFocus();
        },
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}