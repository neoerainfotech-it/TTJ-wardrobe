import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({super.key});

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  // Brand Colors
  final Color brandPurple = const Color(0xFF5D1F88);
  final Color cardPink = const Color(0xFFF8BBD0);

  late Razorpay _razorpay;
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Razorpay
    _razorpay = Razorpay();
    
    // 2. Attach Event Listeners
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    // 3. Clear Razorpay instance to prevent memory leaks
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  // --- RAZORPAY EVENT HANDLERS ---

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Payment succeeded! Now tell your PHP backend to update the user's wallet.
    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      // TODO: Replace with your actual API endpoint for updating the wallet
      final updateResponse = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/update_wallet.php"),
        body: {
          'user_id': userId.toString(),
          'amount': _amountController.text,
          'payment_id': response.paymentId,
          'signature': response.signature ?? '',
        },
      );

      if (updateResponse.statusCode == 200) {
        _showSnackBar("Payment Successful! Money added to wallet.", Colors.green);
        // Go back to the wallet screen and refresh
        if (mounted) Navigator.pop(context); 
      } else {
        _showSnackBar("Payment received, but failed to update wallet.", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("Server error while updating wallet.", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Payment failed or user cancelled
    setState(() => _isProcessing = false);
    _showSnackBar("Payment Failed: ${response.message}", Colors.red);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // User selected an external wallet (like Paytm)
    setState(() => _isProcessing = false);
    _showSnackBar("External Wallet Selected: ${response.walletName}", Colors.blue);
  }

  // --- OPEN RAZORPAY CHECKOUT ---

  void _openCheckout() {
    final String amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar("Please enter an amount", Colors.red);
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar("Please enter a valid amount", Colors.red);
      return;
    }

    setState(() => _isProcessing = true);

    // Razorpay accepts amount in PAISE (Multiply by 100)
    int amountInPaise = (amount * 100).toInt();

    var options = {
      // TODO: Replace with your LIVE / TEST Razorpay Key
      'key': 'rzp_live_sQWAO2cxYeejCd', 
      'amount': amountInPaise,
      'name': 'TTJ Next Gen Jewels',
      'description': 'Add Money to Gold Wallet',
      'prefill': {
        // You can fetch these from SharedPreferences if you have them
        'contact': '', 
        'email': ''
      },
      'theme': {
        'color': '#5D1F88' // Matches your brandPurple
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint('Error opening Razorpay: $e');
      _showSnackBar("Could not open payment gateway.", Colors.red);
    }
  }

  // --- HELPER METHODS ---

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Money", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter Amount to Add",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
                hintText: "0.00",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: brandPurple, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _isProcessing ? null : _openCheckout,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "PROCEED TO PAY",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}