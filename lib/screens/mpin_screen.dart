import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class MpinScreen extends StatefulWidget {
  const MpinScreen({super.key});

  @override
  State<MpinScreen> createState() => _MpinScreenState();
}

class _MpinScreenState extends State<MpinScreen> {
  final List<TextEditingController> _mpinControllers = List.generate(4, (index) => TextEditingController());
  final List<TextEditingController> _confirmControllers = List.generate(4, (index) => TextEditingController());
  bool isLoading = false;

  // Add this function
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
      print("Session save error: $e");
    }
  }

  Future<void> setMpin() async {
    String mpin = _mpinControllers.map((e) => e.text).join();
    String confirmMpin = _confirmControllers.map((e) => e.text).join();

    if (mpin.length < 4 || confirmMpin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all boxes")));
      return;
    }

    if (mpin != confirmMpin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MPINs do not match!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('user_email');

    if (email == null) {
      setState(() => isLoading = false);
      return;
    }

    String apiUrl = "https://ttjnextgen.divasprik.in/ttj_api/update_mpin.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "mpin": mpin}),
      );

      var data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (data['status'] == 'success') {
        // Save full session after MPIN is created
        await _saveUserSession(email);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MPIN Set Successfully!"), backgroundColor: Colors.green));
        
        // Optionally go to dashboard instead of back to login
        // Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
        
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Failed to set MPIN")));
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Align(alignment: Alignment.topLeft, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
              const SizedBox(height: 10),
              Image.asset('assets/ttj_logo.jpeg', height: 100),
              const SizedBox(height: 20),
              const Text('Create MPIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF5D189D))),
              const Text('Set your MPIN for easy Login', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 40),

              const Align(alignment: Alignment.centerLeft, child: Text("Your MPIN*", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(4, (index) => _buildPinBox(_mpinControllers[index], index, true))),

              const SizedBox(height: 30),
              const Align(alignment: Alignment.centerLeft, child: Text("Confirm MPIN*", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(4, (index) => _buildPinBox(_confirmControllers[index], index, false))),

              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : setMpin,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D189D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SET MPIN', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(TextEditingController controller, int index, bool isFirstRow) {
    return Container(
      height: 60, width: 60,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(15), color: const Color(0xFFF5F6FA)),
      child: TextField(
        controller: controller,
        obscureText: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: (value) {
          if (value.length == 1 && index < 3) FocusScope.of(context).nextFocus();
          if (value.isEmpty && index > 0) FocusScope.of(context).previousFocus();
        },
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }
}