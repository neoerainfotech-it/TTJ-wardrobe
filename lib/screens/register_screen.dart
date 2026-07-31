import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'register_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool isChecked = false;
  String? _selectedGender;
  final Color bgGrey = const Color(0xFFF5F6FA);
  final Color primaryPurple = const Color(0xFF5D189D);

  void _showTermsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_tc.php"),
      );
      if (!mounted) return;
      Navigator.pop(context);

      String tcText = "Failed to load terms. Please try again later.";
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        tcText = data['content'] ?? "Terms & Conditions details...";
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Terms & Conditions",
            style: TextStyle(
              color: primaryPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              tcText,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading terms: $e")));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: primaryPurple)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  void _validateAndRegister() {
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();

    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        _selectedGender == null ||
        _dobController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
    } else if (phone.length != 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Phone must be 10 digits")));
    } else if (!email.toLowerCase().endsWith("@gmail.com")) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Use @gmail.com only")));
    } else if (!isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please read and accept Terms & Conditions"),
        ),
      );
    } else {
      sendOtpAndNavigate();
    }
  }

  Future<void> sendOtpAndNavigate() async {
    String emailUrl = "https://ttjnextgen.divasprik.in/ttj_api/send_otp.php";

    try {
      String fullName =
          "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
      String otp = (1000 + Random().nextInt(9000)).toString();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sending OTP to Email...")));

      // 1. Send OTP to user's email WITHOUT inserting into DB yet
      var response = await http.post(
        Uri.parse(emailUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim(), "otp": otp}),
      );

      // 2. Navigate to RegisterOtpScreen and pass form details
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterOtpScreen(
            correctOtp: otp,
            userName: fullName,
            userPhone: _phoneController.text.trim(),
            userEmail: _emailController.text.trim(),
            userGender: _selectedGender ?? "",
            userDob: _dobController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
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
                const SizedBox(height: 20),
                Text(
                  'Register Now',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField(
                  hint: "First Name",
                  controller: _firstNameController,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  hint: "Last Name",
                  controller: _lastNameController,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "Phone Number",
                    filled: true,
                    fillColor: bgGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  hint: "Email ID",
                  inputType: TextInputType.emailAddress,
                  controller: _emailController,
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bgGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      hint: const Text("Select Gender"),
                      items: ["Male", "Female", "Others"]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedGender = val),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: InputDecoration(
                    hintText: "Date of Birth",
                    filled: true,
                    fillColor: bgGrey,
                    suffixIcon: Icon(
                      Icons.calendar_month,
                      color: primaryPurple,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: primaryPurple,
                      onChanged: (v) => setState(() => isChecked = v!),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: "I agree to ",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: _showTermsDialog,
                                child: Text(
                                  "Terms & Conditions",
                                  style: TextStyle(
                                    color: primaryPurple,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                    onPressed: _validateAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
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

  Widget _buildTextField({
    required String hint,
    TextInputType inputType = TextInputType.text,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}